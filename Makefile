# iOS 15 移植版：SDK 16.5 + 最低部署目标 15.0，仅构建 arm64（iPhone 6s 为 arm64）
# 若需同时支持 arm64e 机型，把下面一行改回 `ARCHS = arm64 arm64e`。
ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCAster

CCAster_FILES = Tweak.xm
CCAster_FRAMEWORKS = UIKit CoreFoundation CFNetwork QuartzCore CoreImage
CCAster_PRIVATE_FRAMEWORKS = ControlCenterServices SpringBoardUIServices
CCAster_CFLAGS = -fobjc-arc

# L1ghtmann clang-11 工具链不会自动链接 clang 运行时，需显式链入 libclang_rt*.a
# 该库提供 ___isOSVersionAtLeast（Tweak.xm 中 @available(...) 语法依赖的运行时符号）
_CLANG_RT := $(shell find $(THEOS)/toolchain -name "libclang_rt*.a" 2>/dev/null | head -1)
ifeq ($(_CLANG_RT),)
CCAster_LDFLAGS =
else
CCAster_LDFLAGS = -L$(dir $(_CLANG_RT)) -l$(patsubst lib%,%,$(basename $(notdir $(_CLANG_RT))))
endif

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
