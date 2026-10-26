ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = CCAsterPrefs

CCAsterPrefs_FILES = CCARootListController.m
CCAsterPrefs_FRAMEWORKS = UIKit
CCAsterPrefs_PRIVATE_FRAMEWORKS = Preferences
CCAsterPrefs_INSTALL_PATH = /Library/PreferenceBundles
CCAsterPrefs_CFLAGS = -fobjc-arc
CCAsterPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk

after-CCAsterPrefs-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp "Resources/CCAsterPrefs.plist" "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/CCAsterPrefs.plist"$(ECHO_END)
