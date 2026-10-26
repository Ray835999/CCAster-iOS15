# CCAster → iOS 15.8.8 (iPhone 6s) 移植说明

上游：`https://futur3sn0w.github.io/repo/` 的 `com.futur3sn0w.ccaster` 0.2.2
源码：`https://github.com/MoarTweaks/CCAster`（main 分支，`Tweak.xm` 13667 行）
目标：iPhone 6s（iPhone8,1 / arm64 / 375×667 / 无刘海、有 Home 键），iOS 15.8.8 (19H422)

---

## 1. 结论先说

**CCAster 不是"改一下依赖就能装"的插件，但也不是完全重写。** 用真机固件做逐条 API 比对后的结论是：

- 源码里 **34 个 hook 方法**中，只有 **3 个**在 iOS 15.8.8 上不存在（均为 iOS 16 新增）。
- 所有被 hook 的私有类（`CCUI*` / `MRU*` / `SB*` / `MTMaterialView` / `MPUMarqueeView`）在 iOS 15.8.8 上**全部存在**，包括原以为只有 iOS 16 才有的 `MRUControlCenterViewController` / `MRUControlCenterView`。
- 两个关键的 iOS 16 结构差异（`moduleContainerViewByIdentifier` 属性、`CCUISensorAttributionPrivacyHeaderView` 类）会导致**功能降级但不会崩溃**，已分别做了回退处理。
- 真正的硬伤是**布局**：上游几何常量是按 iOS 16 的高刘海屏调的，iPhone 6s 只有 667pt 高，8 行网格会溢出屏幕 → 已改为按屏幕尺寸自适应。

因此本移植的思路是：**能对齐的对齐，对齐不了的按运行时能力开关（fail-safe），绝不因为缺 API 而让 SpringBoard 崩。**

---

## 2. 分析方法（不是靠猜）

为了保证结论可验证，我把官方固件当成事实来源，而不是凭记忆下判断：

1. 下载官方 `iPhone_4.7_15.8.8_19H422_Restore.ipsw`（5.27 GB，签名有效）。
2. 自己解析 UDIF(DMG) → 发现 iOS 15 的块压缩是 **LZFSE**（magic `bvxn`/`bvx2`，chunk type `0x80000007`），编译 `liblzfse` 后逐块解压得到 7.49 GB 的 APFS 原始镜像。
3. 在镜像里定位 **6 个 dyld_shared_cache 分片**（`dyld_shared_cache_arm64` … `.05`，共 2.32 GB，与 `sharedRegionSize` 吻合）并切出。
4. 自己写了 dyld cache / Mach-O / Objective-C 元数据解析器：
   - `dyld_cache_header` → 映射表（addr→fileOffset，步长 32 字节）、`imagesText` 表（2401 个镜像）
   - 类表 `__objc_classlist` → `class_ro_t` → 类名 / 父类 / 方法表
   - **iOS 15 的指针高位带 tag**（类表是 `+0x20000000000`，方法表是 `+0x10000000000`），需要掩码到 40 位
   - 方法表是 **small/relative 格式**：`entsize = entsizeAndFlags & 0xfffc`（不是 `& 0xFFFF`），选择器名**不是相对偏移，而是共享选择器表的绝对偏移**，表基址实测为 `0x19a404349`
5. 最终得到 **128103 个类 + 方法清单（含父类链）**，据此逐条判定 CCAster 用到的每个选择器。

---

## 3. iOS 15.8.8 实测对照表

### 3.1 全部可用的（保持原样）

| 类 | 关键方法 | 结果 |
|---|---|---|
| `CCUIModuleCollectionViewController` | `layoutView:layoutRectForSubview:`、`contentModuleContainerViewController:willCloseExpandedModule:`、`_activePositionProvider`、`_currentLayoutOptions`、`moduleViewForIdentifier:`、`layoutSizeForModuleIdentifier:forOrientation:` | ✅ |
| `CCUIModuleCollectionView` | `initWithFrame:layoutOptions:`、`hitTest:withEvent:`（父类 `CCUILayoutView` 提供 `frameForLayoutRect:` / `layoutSubviews`，`UIView` 提供 `pointInside:withEvent:`） | ✅ |
| `CCUIControlCenterPositionProvider` | `regenerateRectsWithOrderedIdentifiers:orderedSizes:` | ✅ |
| `CCUIContentModuleContainerViewController` | `clickPresentationInteractionShouldBegin:`、`clickPresentationInteraction:previewForHighlightingAtLocation:`、`clickPresentationInteractionEnded:wasCancelled:` | ✅ |
| `CCUIContentModuleDetailPresentationController` | `_preferredExpandedContentWidthForViewController:` | ✅ |
| `CCUIModularControlCenterOverlayViewController` | `moduleCollectionViewController:willOpenExpandedModule:`；`didCloseExpandedModule:` 由父类 `CCUIModularControlCenterViewController` 提供 | ✅ |
| `CCUIBaseSliderView` | `setValue:`、`setGlyphVisible:`、`_setActiveGlyphView:`、`_applyGlyphState:...` | ✅ |
| `CCUIButtonModuleView` | `setSelected:` | ✅ |
| `CCUIConnectivityModuleViewController` | `preferredExpandedContentHeight` | ✅ |
| `MRUControlCenterViewController` / `MRUControlCenterView` / `MRUNowPlaying*` / `MRUTransportButton` | 全部存在（**此前判断有误，实际 iOS 15 就有**） | ✅ |
| `MPUMarqueeView` | 存在于 `MPUFoundation.framework` | ✅ |
| `MTMaterialView` / `SBControlCenterController`（4 个方法）/ `SBUIPowerDownViewController` + `+[SBUIPowerDownViewControllerFactory newPowerDownViewController]` | | ✅ |
| `CCUIModuleInstanceManager` | `+sharedInstance`、`moduleInstances`、`enabledModuleIdentifiers` | ✅ |
| `CCSModuleSettingsProvider` | `+sharedProvider`、`orderedUserEnabledModuleIdentifiers`、`setAndSaveOrderedUserEnabledModuleIdentifiers:` | ✅ |
| `CCUIContentModuleContext` | `moduleIdentifier`、`initWithModuleIdentifier:`、`moduleLayoutSizeForOrientation:` | ✅ |

### 3.2 iOS 16 独有、iOS 15 没有的（已处理）

| 缺失项 | 处理方式 |
|---|---|
| `-[CCUIModuleCollectionViewController moduleLayoutSizeForContentModuleContext:forOrientation:]` | iOS 15 该职责在 **`CCUIModuleInstanceManager`** 上（已确认存在）。原 hook 移入 `%group CCAModuleSizeIOS16`，新增 `%group CCAModuleSizeIOS15` hook `CCUIModuleInstanceManager` 的同名方法；两者都只在 `class_getInstanceMethod` 命中时才 `%init` |
| `-[CCUIContentModuleContainerViewController presentedViewControllerForContentModuleDetailClickPresentationInteractionController:]` | 移入 `%group CCAContentModuleIOS16`，仅当两个 iOS16 方法同时存在才 `%init`。不装 hook 时 `respondsToSelector:` 为 NO，调用点本来就有保护 → 安全降级 |
| `-[CCUIContentModuleContainerViewController preferredExpandedContentHeight]` | 同上。**注意**：这个 hook 在没有 connectivity 子模块时会走 `%orig`，若被 Substrate/ElleKit 强行"补"出来，`%orig` 为 NULL 会直接崩，所以必须靠分组挡掉 |
| `CCUISensorAttributionPrivacyHeaderView` | iOS 15 对应物是 `CCUISensorStatusView`。仅用于隐藏一块全屏毛玻璃，**故意不改**：误判可能把控制中心背景整个隐藏，风险大于收益 |
| `moduleContainerViewByIdentifier`（KVC 属性） | iOS 15 没有。新增 `CCAIdentifierForLayoutSubviewFallback()`：先试原 KVC，失败则遍历 `CCUIModuleInstanceManager.enabledModuleIdentifiers` 并用 `moduleViewForIdentifier:` 反查。查不到就当原生布局处理，不崩 |

> **为什么非要分组而不是直接 hook？**
> Substrate/ElleKit 对"类里没有的方法"会把方法**添加**进去并把原始实现记为 NULL。一旦 `respondsToSelector:` 变成 YES，插件内部那些"有就调用"的分支就会调到 `%orig == NULL` → 直接崩 SpringBoard。所以 iOS 16 专有的方法必须按运行时能力开关。

### 3.3 布局（iPhone 6s 的重点）

- 网格步长 `kCCAGridCellSize` / `kCCAGridGap` 会**自动从 `CCUILayoutOptions` 的 `_itemEdgeSize` / `_itemSpacing` 读取**（这两个 ivar 在 iOS 15 的 `ControlCenterUI` 里确认存在），再按 67/69、12/15 缩放 → 6s 上会自动变小，无需手改。
- 但 `kCCAMinimumGridRows = 8` 是写死的。375×667 屏上 `8 × (cell+gap)` 会超过可用高度，模块被顶出屏幕。已改为函数 `CCAMinimumGridRows()`：短边 ≤480pt → 5 行；≤700pt → 6 行；≤820pt → 7 行；否则 8 行。同时把 `kCCAPageSpan` 宏改成 `CCAPageSpan()` 函数，所有引用点同步替换。
- 顶部渐变高度 `MAX(112.0, safeAreaInsets.top + 76.0)`：iPhone 6s 的 `safeAreaInsets.top = 20`，结果仍是 112 → 无需改。
- 底部手势区判断用的是 `MAX(92.0, safeAreaInsets.bottom + 68.0)`：6s 的 `safeAreaInsets.bottom = 0` → 取 92 → 无需改。

---

## 4. 改动清单

| 文件 | 改动 |
|---|---|
| `control` | `Depends` 改为 `firmware (>= 15.0), firmware (<< 17.0)`；版本 0.2.3；描述更新 |
| `Makefile` | 注释说明；`ARCHS` 收窄为 `arm64`（iPhone 6s 是 arm64；要同时支持 arm64e 机型改回 `arm64 arm64e`）。保留 `THEOS_PACKAGE_SCHEME = rootless`（palera1n rootless → `/var/jb`） |
| `Tweak.xm` | ① `CCAMinimumGridRows()` / `CCAPageSpan()` 屏幕自适应；② 新增 `CCAIdentifierForLayoutSubviewFallback()` 并在 `layoutView:layoutRectForSubview:` 里调用；③ 新增 `%group CCAModuleSizeIOS16` / `CCAModuleSizeIOS15` / `CCAContentModuleIOS16`；④ `%ctor` 里用 `class_getInstanceMethod` 决定初始化哪些分组 |
| `.github/workflows/build.yml` | 新增：macOS runner + Theos + iPhoneOS16.5 SDK，`make package FINALPACKAGE=1`，产出 deb 作为 artifact |
| `PORT-NOTES.md` | 本文档 |

---

## 5. 怎么拿到 deb

沙箱里是 Linux，**没有 Xcode/Apple 链接器，无法交叉编译 iOS 二进制**，所以我没有直接产出 deb。两条路：

**A. GitHub Actions（推荐，你已经有 FakeDynamicIsland 的同类流程）**
```bash
cd CCAster-iOS15
git init && git add . && git commit -m "CCAster iOS 15 port"
git remote add origin git@github.com:<你的账号>/CCAster-iOS15.git
git push -u origin main
```
推送后 Actions 会自动构建，从 Artifact 下载 `com.futur3sn0w.ccaster_0.2.3_iphoneos-arm64.deb`。

**B. 有 Mac 就本地构建**
```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/sdks && curl -L -o /tmp/sdk.tar.xz \
  https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz
tar -xf /tmp/sdk.tar.xz -C $THEOS/sdks
make clean package FINALPACKAGE=1
```

---

## 6. 安装与验证

iPhone 6s / iOS 15.8.8 目前只能是 **palera1n（checkm8）rootless**，本包正是按 rootless（`/var/jb`）打包的，匹配。

```bash
# 手机上（以 root）
dpkg -i /var/mobile/.../com.futur3sn0w.ccaster_0.2.3_iphoneos-arm64.deb
# 或直接用 Sileo 本地安装
sbreload
```

按你的习惯，**别只信"装上了没报错"**，建议这样验：

1. **冷启动看日志**：`log stream --predicate 'process == "SpringBoard"' | grep -i ccaster`，重点看有没有 `-[... unrecognized selector]` 或 `EXC_BAD_ACCESS`。
2. **确认 hook 真的生效**：进设置 → CCAster 开关一次触发 respring，然后
   ```
   cycript -p SpringBoard   # 或 ellekit 自带的注入检查
   ```
   看 `CCUIModuleInstanceManager`、`CCUIModuleCollectionViewController` 的方法是否被替换（IMP 地址不在 `ControlCenterUI` 的 `__TEXT` 段内即被 hook）。
3. **功能清单逐项过**：编辑模式拖动 / 缩放 / 加控件 / 分页滑动 / 展开模块 / 连接模块二级菜单 / 媒体模块。
4. 出问题进安全模式后，用 `dpkg -r com.futur3sn0w.ccaster` 卸载即可恢复。

---

## 7. 已知降级与待调项

| 项 | 状态 |
|---|---|
| 网格行数 | 已按屏幕尺寸自适应，但 **6 行是推算值**，6s 上大概率还需微调（改 `CCAMinimumGridRows()` 里的阈值/返回值即可） |
| 模块自定义尺寸 | 靠新增的 `CCUIModuleInstanceManager` hook + 反查回退，**未上真机验证** |
| 传感器隐私栏全屏毛玻璃 | iOS 15 上不隐藏（可能看到一层背景），未改，见 3.2 |
| 连接模块二级菜单 | iOS 15 缺少 iOS16 的容器方法，走独立安装路径，需实测 |
| 媒体模块 `nowPlayingViewController` | iOS 15 上该属性不存在，相关代码已有 `@try` + 判空保护 → 部分媒体布局效果失效 |
| arm64e 机型 | 当前只编 arm64；要支持请改回 `ARCHS = arm64 arm64e` |

---

## 8. 复现分析的工具

分析脚本留在沙箱 `/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d57-c04a36ab5000/`：

- `dedmg.py` — LZFSE 块解压（DMG → 原始 APFS 镜像）
- `dsc2.py` — dyld_shared_cache / Mach-O / ObjC 元数据解析（含指针 tag 掩码与共享选择器表）
- `fullindex.py` → `ios15_index.json` — 128103 个类的「父类 + 实例方法 + 类方法」索引
- `check.py` — 继承链感知的 API 可用性判定

固件：`iPhone_4.7_15.8.8_19H422_Restore.ipsw`（SHA256 可按需校验）
