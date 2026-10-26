#import <Foundation/Foundation.h>
#include <stdint.h>

// L1ghtmann clang-11 工具链未附带 libclang_rt，而 Tweak.xm 中使用的 @available(...)
// 会在链接期依赖运行时符号 ___isOSVersionAtLeast。这里自行提供等价实现
// （逻辑与 compiler-rt 的 os_version_check 一致），不依赖工具链内部库。
int ___isOSVersionAtLeast(int32_t major, int32_t minor, int32_t subminor) {
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (v.majorVersion != major) return (v.majorVersion > major) ? 1 : 0;
    if (v.minorVersion != minor) return (v.minorVersion > minor) ? 1 : 0;
    return (v.patchVersion >= subminor) ? 1 : 0;
}
