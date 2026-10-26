# iOS 15 移植版：SDK 16.5 + 最低部署目标 15.0，仅构建 arm64（iPhone 6s 为 arm64）
# 若需同时支持 arm64e 机型，把下面一行改回 `ARCHS = arm64 arm64e`。
ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCAster

CCAster_FILES = Tweak.xm os_check.m
CCAster_FRAMEWORKS = UIKit CoreFoundation CFNetwork QuartzCore CoreImage
CCAster_PRIVATE_FRAMEWORKS = ControlCenterServices SpringBoardUIServices
CCAster_CFLAGS = -fobjc-arc

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
