ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.4
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HappVPNPushRoute HappAPNsDNS HappAPNsScope

HappVPNPushRoute_FILES = HappVPNPushRoute.xm
HappVPNPushRoute_LIBRARIES = objc
HappVPNPushRoute_FRAMEWORKS = NetworkExtension
HappVPNPushRoute_CFLAGS = -O2 -DNDEBUG -fobjc-arc -fvisibility=hidden
HappVPNPushRoute_LDFLAGS = -Wl,-headerpad,0x1000

HappAPNsDNS_FILES = HappAPNsDNS.xm
HappAPNsDNS_LIBRARIES = objc
HappAPNsDNS_FRAMEWORKS = NetworkExtension
HappAPNsDNS_CFLAGS = -O2 -DNDEBUG -fobjc-arc -fvisibility=hidden
HappAPNsDNS_LDFLAGS = -Wl,-headerpad,0x1000

HappAPNsScope_FILES = HappAPNsScope.x
HappAPNsScope_CFLAGS = -O2 -DNDEBUG -fno-builtin -fvisibility=hidden -Wall -Wextra -Werror
HappAPNsScope_FRAMEWORKS = Network SystemConfiguration
HappAPNsScope_LDFLAGS = -Wl,-headerpad,0x1000

include $(THEOS_MAKE_PATH)/tweak.mk
