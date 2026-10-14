#include "../Classes/Services/VKPCMBuffer.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned passed;
static void check(int condition) { assert(condition); }
static void ok(const char *name) { printf("PASS %s\n", name); ++passed; }
static void approx(float a, float b) { check(fabsf(a-b) < 0.0001f); }
int main(void) {
    VKPCMBuffer buffer; VKPCMInit(&buffer);
    unsigned generation = VKPCMReset(&buffer);
    float out[8];
    check(VKPCMRead(&buffer,out,8,1)==0); for(int i=0;i<8;++i) approx(out[i],0);
    ok("empty capture is silence, not uninitialized samples");
    VKPCMFormat f32={4,32,8,1,0,0};
    float stereo[]={0.4f,0.2f, -0.8f,0.4f, 0.6f,0.6f};
    VKPCMSamples samples[]={ {stereo,sizeof(stereo),2} };
    VKPCMPush(&buffer,generation,f32,samples,1,3,44100,1);
    check(VKPCMRead(&buffer,out,8,1.1)==3);
    for(int i=0;i<5;++i) approx(out[i],0);
    approx(out[5],0.3f);approx(out[6],-0.2f);approx(out[7],0.6f);
    ok("interleaved stereo float32 is downmixed and left-padded");
    generation=VKPCMReset(&buffer);
    float left[]={-0.4f,0.8f},right[]={0.2f,0.6f};
    VKPCMSamples planar[]={{left,sizeof(left),1},{right,sizeof(right),1}};
    VKPCMFormat planar32={4,32,4,1,0,0};
    VKPCMPush(&buffer,generation,planar32,planar,2,2,48000,2);
    check(VKPCMRead(&buffer,out,2,2.1)==2);approx(out[0],-0.1f);approx(out[1],0.7f);
    ok("noninterleaved stereo uses both channels");
    int16_t signed16[]={-32768,16384,32767};
    VKPCMFormat i16={2,16,2,0,0,0};
    generation=VKPCMReset(&buffer);samples[0]=(VKPCMSamples){signed16,sizeof(signed16),1};
    VKPCMPush(&buffer,generation,i16,samples,1,3,44100,3);
    check(VKPCMRead(&buffer,out,3,3.1)==3);approx(out[0],-1);approx(out[1],0.5);approx(out[2],32767.0f/32768);
    ok("signed int16");
    unsigned char be24[]={0x80,0,0, 0x40,0,0};
    VKPCMFormat i24={3,24,3,0,1,0};
    approx(VKPCMDecode(be24,i24),-1);approx(VKPCMDecode(be24+3,i24),0.5);
    ok("big-endian signed packed int24");
    int32_t aligned24[]={INT32_MIN,1073741824};
    VKPCMFormat padded24={4,24,4,0,0,1};
    approx(VKPCMDecode((unsigned char *)&aligned24[0],padded24),-1);
    approx(VKPCMDecode((unsigned char *)&aligned24[1],padded24),0.5);
    ok("high-aligned int24 in int32 storage");
    double d=0.375; VKPCMFormat f64={8,64,8,1,0,0};
    approx(VKPCMDecode((unsigned char *)&d,f64),0.375);
    ok("float64");
    float invalid=NAN;approx(VKPCMDecode((unsigned char *)&invalid,planar32),0);
    invalid=INFINITY;approx(VKPCMDecode((unsigned char *)&invalid,planar32),0);
    invalid=2.0f;approx(VKPCMDecode((unsigned char *)&invalid,planar32),1);
    ok("nonfinite samples sanitized and amplitudes bounded");
    generation=VKPCMReset(&buffer);
    float *large=malloc(6000*sizeof(float));check(large!=NULL);
    for(size_t i=0;i<6000;++i) large[i]=(float)i/6000;
    samples[0]=(VKPCMSamples){large,6000*sizeof(float),1};
    VKPCMPush(&buffer,generation,planar32,samples,1,6000,44100,4);
    check(VKPCMRead(&buffer,out,8,4.1)==8);
    for(int i=0;i<8;++i) approx(out[i],large[5992+i]);
    free(large);ok("large render quantum retains the newest samples, not first 512");
    check(VKPCMRead(&buffer,out,8,4.6)==0);for(int i=0;i<8;++i) approx(out[i],0);
    ok("stale PCM expires after 500ms");
    unsigned old=generation;generation=VKPCMReset(&buffer);
    samples[0]=(VKPCMSamples){left,sizeof(left),1};
    VKPCMPush(&buffer,old,planar32,samples,1,2,44100,5);
    check(VKPCMRead(&buffer,out,8,5.1)==0);
    ok("previous track cannot refill a new generation");
    pthread_mutex_lock(&buffer.lock);
    VKPCMPush(&buffer,generation,planar32,samples,1,2,44100,6);
    pthread_mutex_unlock(&buffer.lock);
    check(buffer.validCount==0);ok("audio callback drops a quantum instead of waiting on UI");
    samples[0].byteCount=sizeof(float);
    VKPCMPush(&buffer,generation,planar32,samples,1,100,44100,7);
    check(VKPCMRead(&buffer,out,8,7.1)==1);ok("short buffer bounds respected");
    generation=VKPCMReset(&buffer);
    float sine[1024]; for(int i=0;i<1024;++i) sine[i]=sinf(2.0f*3.14159265358979323846f*16*i/1024);
    samples[0]=(VKPCMSamples){sine,sizeof(sine),1};
    VKPCMPush(&buffer,generation,planar32,samples,1,1024,44100,8);
    float window[1024];check(VKPCMRead(&buffer,window,1024,8.1)==1024);
    double energy=0;for(int i=0;i<1024;++i) energy+=window[i]*window[i];
    check(fabs(sqrt(energy/1024)-sqrt(0.5))<0.0001);
    ok("real sine PCM reaches the renderer window with expected RMS");
    pthread_mutex_destroy(&buffer.lock);
    printf("%u PCM regression cases passed\n",passed);
    return 0;
}
