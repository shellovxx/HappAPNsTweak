ARCHS = arm64
TARGET = iphone:clang:latest:16.4
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HappVPNPushRoute HappAPNsDNS

HappVPNPushRoute_FILES = HappVPNPushRoute.c
HappVPNPushRoute_LIBRARIES = objc
HappVPNPushRoute_FRAMEWORKS = NetworkExtension
HappVPNPushRoute_CFLAGS = -O2 -fno-builtin
HappVPNPushRoute_LDFLAGS = -Wl,-headerpad,0x1000

HappAPNsDNS_FILES = HappAPNsDNS.c
HappAPNsDNS_LIBRARIES = objc
HappAPNsDNS_FRAMEWORKS = NetworkExtension
HappAPNsDNS_CFLAGS = -O2 -fno-builtin
HappAPNsDNS_LDFLAGS = -Wl,-headerpad,0x1000

include $(THEOS_MAKE_PATH)/tweak.mk
