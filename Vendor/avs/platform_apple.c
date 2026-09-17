#include "platform.h"

#ifndef WFMO
#define WFMO 1
#endif
#include "3rdparty/pevents.h"

#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <mach/mach_time.h>
#include <sys/mman.h>
#include <sys/stat.h>

/* timers & time */

uint64_t timer_ms() {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t t = mach_absolute_time();
    uint64_t nanos = t * timebase.numer / timebase.denom;
    return nanos / 1000000ULL;
}

uint64_t timer_us() {
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t t = mach_absolute_time();
    uint64_t nanos = t * timebase.numer / timebase.denom;
    return nanos / 1000ULL;
}

double timer_us_precision() {
    return 1.0;
}

const char* current_date_str() {
    static char date_str[11];
    time_t t = time(NULL);
    struct tm date = *localtime(&t);
    snprintf(date_str,
             11,
             "%04d-%02d-%02d",
             date.tm_year + 1900,
             date.tm_mon + 1,
             date.tm_mday);
    return date_str;
}

/* locking */

#define PTHREAD_LOCK(lock) ((pthread_mutex_t*)(lock))
lock_t* lock_init() {
    pthread_mutex_t* lock_obj = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init((pthread_mutex_t*)lock_obj, &attr);
    pthread_mutexattr_destroy(&attr);
    return (lock_t*)lock_obj;
}
void lock_lock(lock_t* lock_obj) { pthread_mutex_lock(PTHREAD_LOCK(lock_obj)); }
bool lock_try(lock_t* lock_obj) {
    return 0 == pthread_mutex_trylock(PTHREAD_LOCK(lock_obj));
}
void lock_unlock(lock_t* lock_obj) { pthread_mutex_unlock(PTHREAD_LOCK(lock_obj)); }
void lock_destroy(lock_t* lock_obj) {
    pthread_mutex_destroy(PTHREAD_LOCK(lock_obj));
    free(lock_obj);
}

/* signals */

signal_t* signal_create_single() {
    neosmart_event_t event = NspeCreateEvent(false, false);
    return (signal_t*)event;
}
signal_t* signal_create_broadcast() {
    neosmart_event_t event = NspeCreateEvent(true, false);
    return (signal_t*)event;
}
void signal_set(signal_t* signal) { NspeSetEvent((neosmart_event_t)signal); }
void signal_unset(signal_t* signal) { NspeResetEvent((neosmart_event_t)signal); }

signal_t* signal_wait(signal_t* signal, int32_t wait_ms) {
    uint64_t timeout = wait_ms < 0 ? -1 : (uint64_t)wait_ms;
    int result = NspeWaitForEvent((neosmart_event_t)signal, timeout);
    return result == 0 ? signal : NULL;
}

signal_t* signal_wait_any(signal_t** signals, uint32_t num_signals, int32_t wait_ms) {
    uint64_t timeout = wait_ms < 0 ? -1 : (uint64_t)wait_ms;
    int index = -1;
    int result = NspeWaitForMultipleEventsWithIndex((neosmart_event_t*)signals, num_signals, false, timeout, &index);
    if (result == 0 && index >= 0 && (uint32_t)index < num_signals) {
        return signals[index];
    }
    return NULL;
}

signal_t* signal_wait_all(signal_t** signals, uint32_t num_signals, int32_t wait_ms) {
    uint64_t timeout = wait_ms < 0 ? -1 : (uint64_t)wait_ms;
    int result = NspeWaitForMultipleEvents((neosmart_event_t*)signals, num_signals, true, timeout);
    return result == 0 ? signals[0] : NULL;
}

void signal_destroy(signal_t* signal) {
    NspeDestroyEvent((neosmart_event_t)signal);
}

/* threads */

typedef struct {
    uint32_t (*func)(void*);
    void* data;
} apple_thread_info_t;

static void* _apple_thread_entry(void* arg) {
    apple_thread_info_t* info = (apple_thread_info_t*)arg;
    uint32_t (*func)(void*) = info->func;
    void* data = info->data;
    free(info);
    uint32_t ret = func(data);
    return (void*)(uintptr_t)ret;
}

thread_t* thread_create(uint32_t (*func)(void* data), void* data) {
    pthread_t* thread = (pthread_t*)malloc(sizeof(pthread_t));
    apple_thread_info_t* info = (apple_thread_info_t*)malloc(sizeof(apple_thread_info_t));
    info->func = func;
    info->data = data;
    if (pthread_create(thread, NULL, _apple_thread_entry, info) != 0) {
        free(info);
        free(thread);
        return NULL;
    }
    return (thread_t*)thread;
}

thread_t* thread_current() {
    pthread_t* thread = (pthread_t*)malloc(sizeof(pthread_t));
    *thread = pthread_self();
    return (thread_t*)thread;
}

bool thread_join(thread_t* thread, int32_t wait_ms) {
    (void)wait_ms;
    if (!thread) return false;
    pthread_t* pthread = (pthread_t*)thread;
    return pthread_join(*pthread, NULL) == 0;
}

bool thread_join_all(thread_t** threads, uint32_t num_threads, int32_t wait_ms) {
    bool result = true;
    for (uint32_t i = 0; i < num_threads; i++) {
        result &= thread_join(threads[i], wait_ms);
    }
    return result;
}

bool thread_decrease_priority(thread_t* thread) {
    (void)thread;
    return true;
}

void thread_destroy(thread_t* thread) {
    free(thread);
}

/* dynamic library loading */

dlib_t* library_load(const char* path) {
    return (dlib_t*)dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
}
func_t library_get(dlib_t* library, const char* func_name) {
    dlerror();
    if (library == NULL) {
        return NULL;
    }
    void* function = dlsym(library, func_name);
    if (dlerror() != NULL) {
        return NULL;
    }
    return (func_t)function;
}
void library_unload(dlib_t* library) {
    if (library != NULL) {
        dlclose(library);
    }
}
const char* library_error() { return dlerror(); }

/* mkdir */

int create_directory(const char* path) { return mkdir(path, 0777) != 0; }

/* memory read-write-exec */

void mem_mark_rwx(void* block, size_t length) {
#if !defined(EEL_TARGET_PORTABLE)
    static int pagesize = 0;
    if (!pagesize) {
        pagesize = (int)sysconf(_SC_PAGESIZE);
        if (!pagesize) {
            pagesize = 4096;
        }
    }
    uintptr_t b = (uintptr_t)block;
    uintptr_t block_aligned = b & ~(uintptr_t)(pagesize - 1);
    size_t length_aligned =
        ((b + length + (uintptr_t)pagesize - 1) & ~(uintptr_t)(pagesize - 1)) - block_aligned;
    mprotect((void*)block_aligned, length_aligned, PROT_WRITE | PROT_READ | PROT_EXEC);
#else
    (void)block;
    (void)length;
#endif
}

void print_last_system_error() {
    fprintf(stderr, "System error: %s\n", strerror(errno));
}
