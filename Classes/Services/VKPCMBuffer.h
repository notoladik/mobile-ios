#ifndef VK_PCM_BUFFER_H
#define VK_PCM_BUFFER_H
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <pthread.h>

/* Shared by the actual audio tap and the portable regression tests.
 * Audio producer never waits, allocates, logs or calls UIKit. */
#define VK_PCM_CAPACITY 4096
#define VK_PCM_MAX_BUFFERS 8

typedef struct {
    unsigned sampleBytes, validBits, frameBytes;
    int floatingPoint, bigEndian, alignedHigh;
} VKPCMFormat;

typedef struct {
    const void *data;
    size_t byteCount;
    unsigned channels;
} VKPCMSamples;

typedef struct {
    pthread_mutex_t lock;
    float samples[VK_PCM_CAPACITY];
    size_t writeIndex, validCount;
    unsigned generation;
    uint64_t framesCaptured;
    double lastTime, sampleRate;
} VKPCMBuffer;

static inline void VKPCMInit(VKPCMBuffer *b) {
    memset(b, 0, sizeof(*b));
    pthread_mutex_init(&b->lock, NULL);
}

static inline unsigned VKPCMReset(VKPCMBuffer *b) {
    pthread_mutex_lock(&b->lock);
    b->writeIndex = b->validCount = 0;
    b->framesCaptured = 0;
    b->lastTime = b->sampleRate = 0;
    unsigned generation = ++b->generation;
    pthread_mutex_unlock(&b->lock);
    return generation;
}

static inline int VKPCMFormatSupported(VKPCMFormat f) {
    if (!f.sampleBytes || !f.frameBytes) return 0;
    if (f.floatingPoint) return (f.sampleBytes == 4 && f.validBits == 32) || (f.sampleBytes == 8 && f.validBits == 64);
    return f.sampleBytes <= 4 && f.validBits > 0 && f.validBits <= f.sampleBytes * 8;
}

static inline float VKPCMDecode(const unsigned char *p, VKPCMFormat f) {
    uint64_t bits = 0;
    for (unsigned i = 0; i < f.sampleBytes; ++i) {
        unsigned shift = (f.bigEndian ? f.sampleBytes - 1 - i : i) * 8;
        bits |= (uint64_t)p[i] << shift;
    }
    double value;
    if (f.floatingPoint && f.sampleBytes == 4) {
        uint32_t word = (uint32_t)bits;
        float sample;
        memcpy(&sample, &word, sizeof(sample));
        value = sample;
    } else if (f.floatingPoint) {
        memcpy(&value, &bits, sizeof(value));
    } else {
        if (f.alignedHigh) bits >>= f.sampleBytes * 8 - f.validBits;
        uint64_t mask = ((uint64_t)1 << f.validBits) - 1;
        bits &= mask;
        int64_t signedValue = (bits & ((uint64_t)1 << (f.validBits - 1))) ? (int64_t)bits - ((int64_t)1 << f.validBits) : (int64_t)bits;
        value = (double)signedValue / (double)((uint64_t)1 << (f.validBits - 1));
    }
    if (!isfinite(value)) return 0.0f;
    return (float)fmax(-1.0, fmin(1.0, value));
}

static inline void VKPCMPush(VKPCMBuffer *b, unsigned generation, VKPCMFormat f,
                             const VKPCMSamples *buffers, size_t bufferCount,
                             size_t frames, double sampleRate, double now) {
    if (!VKPCMFormatSupported(f) || !buffers || !bufferCount || !frames) return;
    if (pthread_mutex_trylock(&b->lock) != 0) return;
    if (generation != b->generation) { pthread_mutex_unlock(&b->lock); return; }
    /* Only the newest window is needed, but never repeatedly copy the start
       of a large render quantum (the old implementation did that). */
    size_t start = frames > VK_PCM_CAPACITY ? frames - VK_PCM_CAPACITY : 0;
    size_t captured = 0;
    for (size_t frame = start; frame < frames; ++frame) {
        double sum = 0;
        unsigned channelsRead = 0;
        for (size_t k = 0; k < bufferCount; ++k) {
            const VKPCMSamples *s = &buffers[k];
            if (!s->data || !s->channels || s->channels > f.frameBytes / f.sampleBytes) continue;
            if (frame >= s->byteCount / f.frameBytes) continue;
            for (unsigned c = 0; c < s->channels; ++c) {
                const unsigned char *p = (const unsigned char *)s->data + frame * f.frameBytes + c * f.sampleBytes;
                sum += VKPCMDecode(p, f);
                ++channelsRead;
            }
        }
        if (!channelsRead) continue;
        b->samples[b->writeIndex] = (float)(sum / channelsRead);
        b->writeIndex = (b->writeIndex + 1) % VK_PCM_CAPACITY;
        if (b->validCount < VK_PCM_CAPACITY) ++b->validCount;
        ++captured;
    }
    if (captured) {
        b->framesCaptured += captured;
        b->lastTime = now;
        b->sampleRate = sampleRate;
    }
    pthread_mutex_unlock(&b->lock);
}

static inline size_t VKPCMRead(VKPCMBuffer *b, float *out, size_t count, double now) {
    if (!out || !count) return 0;
    memset(out, 0, count * sizeof(*out));
    pthread_mutex_lock(&b->lock);
    size_t available = 0;
    if (b->validCount && now - b->lastTime <= 0.5 && now >= b->lastTime) {
        available = count < b->validCount ? count : b->validCount;
        size_t start = (b->writeIndex + VK_PCM_CAPACITY - available) % VK_PCM_CAPACITY;
        for (size_t i = 0; i < available; ++i) out[count - available + i] = b->samples[(start + i) % VK_PCM_CAPACITY];
    }
    pthread_mutex_unlock(&b->lock);
    return available;
}
#endif
