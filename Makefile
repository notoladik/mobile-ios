TARGET := iphone:clang:latest:6.0
ARCHS := armv7 armv7s arm64

_THEOS_NO_STRICT_PERMISSIONS = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = OpenVK

ENABLE_VISUALIZER ?= 1

ifeq ($(ENABLE_VISUALIZER),1)
VISUALIZER_CFLAGS := -DENABLE_MILKDROP_VISUALIZER=1 \
                    -DENABLE_AVS_VISUALIZER=1 \
                    -DUSE_GLES=1 -DUSE_GLES2=1 -DSTBI_NO_THREAD_LOCALS=1 \
                    -DNO_MMX=1 -DNO_FFMPEG=1 -DEEL_TARGET_PORTABLE=1 -D_USE_MATH_DEFINES=1 -DWFMO=1 \
                    -include stdlib.h

PROJECTM_INCLUDES = -IVendor/projectm/src/api/include \
                    -IVendor/projectm/src/libprojectM \
                    -IVendor/projectm/src/libprojectM/MilkdropPreset \
                    -IVendor/projectm/src/libprojectM/MilkdropPreset/Waveforms \
                    -IVendor/projectm/src/libprojectM/UserSprites \
                    -IVendor/projectm/src/libprojectM/Renderer \
                    -IVendor/projectm/src/libprojectM/Renderer/Platform \
                    -IVendor/projectm/src/libprojectM/Audio \
                    -IVendor/projectm/vendor \
                    -IVendor/projectm/vendor/projectm-eval \
                    -IVendor/projectm/vendor/projectm-eval/projectm-eval \
                    -IVendor/projectm/vendor/projectm-eval/projectm-eval/api \
                    -IVendor/projectm/vendor/hlslparser/src \
                    -IVendor/projectm/vendor/glad/include \
                    -IVendor/projectm/vendor/stb_image

AVS_INCLUDES = -IVendor/avs \
               -IVendor/avs/arm_simd \
               -IVendor/avs/vis_avs \
               -IVendor/avs/3rdparty \
               -IVendor/avs/3rdparty/WDL-EEL2 \
               -IVendor/avs/3rdparty/WDL-EEL2/eel2 \
               -IClasses/AVS

PROJECTM_FILES = $(wildcard Vendor/projectm/src/libprojectM/*.cpp) \
                 $(wildcard Vendor/projectm/src/libprojectM/Audio/*.cpp) \
                 $(wildcard Vendor/projectm/src/libprojectM/MilkdropPreset/*.cpp) \
                 $(wildcard Vendor/projectm/src/libprojectM/MilkdropPreset/Waveforms/*.cpp) \
                 $(wildcard Vendor/projectm/src/libprojectM/UserSprites/*.cpp) \
                 $(wildcard Vendor/projectm/src/libprojectM/Renderer/*.cpp) \
                 Vendor/projectm/src/libprojectM/Renderer/Platform/DynamicLibrary.cpp \
                 Vendor/projectm/src/libprojectM/Renderer/Platform/DynamicLibrary_posix.cpp \
                 Vendor/projectm/src/libprojectM/Renderer/Platform/GLProbe.cpp \
                 Vendor/projectm/src/libprojectM/Renderer/Platform/GLResolver.cpp \
                 Vendor/projectm/src/libprojectM/Renderer/Platform/GladLoader.cpp \
                 $(wildcard Vendor/projectm/vendor/projectm-eval/projectm-eval/*.c) \
                 Vendor/projectm/vendor/projectm-eval/projectm-eval/api/projectm-eval.c \
                 $(wildcard Vendor/projectm/vendor/hlslparser/src/*.cpp) \
                 Vendor/projectm/vendor/stb_image/stb_image.c \
                 Vendor/projectm/vendor/stb_image/image_DXT.c \
                 Vendor/projectm/vendor/stb_image/wfETC.c \
                 Vendor/projectm/vendor/glad/src/gles2.c

AVS_FILES = $(wildcard Vendor/avs/vis_avs/*.cpp) \
            Vendor/avs/platform.c \
            Vendor/avs/platform_apple.c \
            Vendor/avs/uuid.cpp \
            Vendor/avs/3rdparty/pevents.cpp \
            Vendor/avs/3rdparty/md_fft.cpp \
            $(wildcard Vendor/avs/3rdparty/WDL-EEL2/eel2/nseel-*.c)

VISUALIZER_SRC = $(wildcard Classes/Milkdrop/*.cpp) $(wildcard Classes/Milkdrop/*.mm) \
                 $(wildcard Classes/AVS/*.cpp) $(wildcard Classes/AVS/*.mm) \
                 $(PROJECTM_FILES) $(AVS_FILES)
else
VISUALIZER_CFLAGS := -DENABLE_MILKDROP_VISUALIZER=0 -DENABLE_AVS_VISUALIZER=0
PROJECTM_INCLUDES =
AVS_INCLUDES =
VISUALIZER_SRC =
endif

OpenVK_FILES = $(wildcard Classes/*.m) $(wildcard Classes/Controllers/*.m) $(wildcard Classes/Models/*.m) $(wildcard Classes/Services/*.m) $(VISUALIZER_SRC)
OpenVK_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore Security SystemConfiguration MediaPlayer AVFoundation OpenGLES CoreImage MediaToolbox AudioToolbox ImageIO
OpenVK_CFLAGS = -fobjc-arc -IClasses -IClasses/Controllers -IClasses/Models -IClasses/Services -IClasses/Milkdrop -IClasses/AVS $(PROJECTM_INCLUDES) $(AVS_INCLUDES) $(VISUALIZER_CFLAGS) -Wno-deprecated-declarations -Wno-enum-conversion -Wno-unused-variable -Wno-unused-function -Wno-unused-private-field -Wno-error
OpenVK_CXXFLAGS = -std=c++17 -stdlib=libc++ -faligned-allocation -IClasses -IClasses/Milkdrop -IClasses/AVS $(PROJECTM_INCLUDES) $(AVS_INCLUDES) $(VISUALIZER_CFLAGS) -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-unused-private-field -Wno-error
OpenVK_CCFLAGS = $(OpenVK_CXXFLAGS)
OpenVK_LDFLAGS = -lc++
OpenVK_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	@cp -f Info.plist $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Info.plist 2>/dev/null || true
	@if [ -d Resources ]; then cp -rf Resources/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/ 2>/dev/null || true; fi
	@if [ -d Resources/Presets ]; then mkdir -p $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Presets && cp -rf Resources/Presets/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Presets/ 2>/dev/null || true; fi
	@if [ -d Resources/AVSPresets ]; then mkdir -p $(THEOS_STAGING_DIR)/Applications/OpenVK.app/AVSPresets && cp -rf Resources/AVSPresets/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/AVSPresets/ 2>/dev/null || true; fi
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name ".DS_Store" -delete$(ECHO_END)

before-package::
	@cp -f Info.plist $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Info.plist 2>/dev/null || true
	@if [ -d Resources ]; then cp -rf Resources/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/ 2>/dev/null || true; fi
	@if [ -d Resources/Presets ]; then mkdir -p $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Presets && cp -rf Resources/Presets/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/Presets/ 2>/dev/null || true; fi
	@if [ -d Resources/AVSPresets ]; then mkdir -p $(THEOS_STAGING_DIR)/Applications/OpenVK.app/AVSPresets && cp -rf Resources/AVSPresets/* $(THEOS_STAGING_DIR)/Applications/OpenVK.app/AVSPresets/ 2>/dev/null || true; fi
	@chmod -R 0755 $(THEOS_STAGING_DIR)
	@chmod 0644 $(THEOS_STAGING_DIR)/DEBIAN/control 2>/dev/null || true

ipa:: all stage
	@rm -rf Payload OpenVK-Legacy.ipa
	@mkdir -p Payload
	@cp -rf $(THEOS_STAGING_DIR)/Applications/OpenVK.app Payload/
	@zip -r9 OpenVK-Legacy.ipa Payload
	@rm -rf Payload
	@echo "=========================================="
	@echo " [SUCCESS] IPA готов: OpenVK-Legacy.ipa"
	@echo "=========================================="
