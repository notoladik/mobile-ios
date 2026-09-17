#include "audio_in.h"

#if defined(__APPLE__)
#include <libkern/OSCacheControl.h>

extern "C" void __clear_cache(void* beg, void* end) {
    if (beg && end && (uintptr_t)end > (uintptr_t)beg) {
        sys_icache_invalidate(beg, (uintptr_t)end - (uintptr_t)beg);
    }
}
#endif

AVS_Audio_Input* audio_in_start(avs_audio_input_handler callback, void* data) {
    (void)callback;
    (void)data;
    return (AVS_Audio_Input*)1;
}

void audio_in_stop(AVS_Audio_Input* audio_in) {
    (void)audio_in;
}

std::vector<std::string> audio_in_devices() {
    return {"iOS Audio Player Direct"};
}

bool audio_in_select_device(uint32_t device_index) {
    (void)device_index;
    return true;
}
