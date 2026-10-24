# Yuki-Blog App 项目记忆

## 1. 标识与发版
- 仓库/工程名 **Yuki-Blog App**，显示名 **Yuki Blog**（全英），Dart 包 `yuki_blog_app`；仓库 `cixiy1/Yuki-Blog-App`（**公开**，班级个人材料 `/材料/` 已 gitignore，新增同类材料先确认被忽略，别 `git add -A` 误推）。
- 应用 ID：Android `com.yiyu14.yuki_blog_app`；**Apple 两端（iOS 与 macOS）都是 `com.yiyu14.yukiblogapp`** —— Bundle ID 是 UTI，只允许字母/数字/连字符/点，带下划线会报 `invalid character in Bundle Identifier`（macOS 构建警告）或 `attribute 'name' is invalid: 'XC com yiyu14 yuki_blog_app'`（iOS 签名）。改标识要四处同步：android namespace/applicationId/源码目录/Manifest、iOS `PRODUCT_BUNDLE_IDENTIFIER`+`PRODUCT_NAME`（连带 pbxproj `TEST_HOST`、xcscheme `BuildableName`）、macOS `AppInfo.xcconfig`（含 pbxproj 里 RunnerTests 的后缀）、web `manifest.json`/`index.html`。**别把 iOS/macOS 的顺手"统一"回下划线版**。
- 发版：改 `pubspec.yaml` version → Conventional Commits 推送 → `git tag vX.Y.Z && git push origin vX.Y.Z` → Actions 自动测试+构建+发 Release，App 内更新弹窗读该 Release。
- 命名铁律：不要中英文夹杂。

## 2. 发布铁律（最高优先级）
**未经用户明确允许：不升版本号、不构建、不 `git push`、不打 tag、不触发上线（CI 发版 / 博客 push 上 Cloudflare）。** 默认只做「改代码 → `flutter analyze` + `flutter test` → 本地 commit」，改完说「等你允许再升版本/构建/推送」。
- 踩过的坑：曾把「改代码 + 升 1.4.5→1.4.6 + `flutter build apk` + 拷 `~/Downloads`」一次做完被制止。**「本地 commit 不受限」≠「构建不受限」**：升版本是发版信号、构建产生可分发产物，两者都要授权。回退：改回 version → `git add pubspec.yaml && git commit --amend --no-edit`（未推送才可）→ 删掉产出包。
- 判断推送是否真失败：`git push | tail` 退出码取的是 `tail`，会误判。改看 `git status -sb | head -1` 有无 `[ahead N]`。

## 3. 签名
**Android（固定 keystore，铁律）**：release 一律用 `android/key.properties` 指定的 keystore，**签名参数全部由用户填写，我不得代拟任何口令/别名/证书信息**。模板 `android/key.properties.example`，生成密钥库 `tool/gen_release_keystore.sh`，导出 Secrets/备份 `tool/make_signing_secrets.sh`。未配置时回退 AGP debug 签名（每台机器/每个 runner 现生成，互相无法覆盖安装 → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`，App 内更新失效）。keystore+口令丢＝永远发不了可覆盖升级的版本，必须有仓库外备份。
- 已定参数（2026-10-15 Yukiho 确认，勿改）：`keyAlias=yuki-blog`、`dname=CN=Yukiho, O=Yukiho, C=CN`、36500 天、`storeFile=release.jks`。口令用户自持，**不记入任何文档**。
- 证书 SHA-256 `91:40:6D:E2:74:3B:11:6E:92:86:5A:26:80:B5:D4:66:1D:FA:DB:ED:49:BF:6E:31:00:5F:D6:35:B5:6B:5B:E2`，核对用 `apksigner verify --print-certs`（或 `cd android && ./gradlew :app:signingReport`）。备份在仓库外 `~/Documents/Yuki/signing-2615/`。换签名＝所有用户卸载重装，非必要不做。临时测试密钥不得留在 `android/` 下。

**iOS 真机**：Team `R4A23FHD6Y`（Apple ID 8615767147471，证书有效到 2027-10-24），已写入 pbxproj Runner 三个 config（`CODE_SIGN_STYLE=Automatic` + `DEVELOPMENT_TEAM`）。装法＝`flutter build ios --release` → `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` → `devicectl device process launch --device <udid> com.yiyu14.yukiblogapp`。
- **iOS 14+ 的 debug 版只能从 Flutter/Xcode 启动**，桌面点开必报「debug mode Flutter apps can only be launched from Flutter tooling」→ 要给桌面能开必须装 release/profile 版。
- `flutter run` 在真机常卡在「local network」（mDNS 5353 被拦），**App 其实已装好并启动**，别当失败。
- 设备 UDID：iPhone 12 `00008101-001459AA0E46001E`；iPhone 11 Pro Max `00008030-00180C622208802E`（iOS 16+ 必须先在设备上开「开发者模式」，Mac 侧无命令开关）。
- 描述文件 `ProvisionedDevices` 只列已登记的机型，**换机型必须重新 build 让 Xcode 用 `-allowProvisioningUpdates` 登记+重签，不能直接 install 旧产物**。免费个人团队 profile 7 天过期（到期重装一次）。
- **iOS 工程已全 SPM 化，不装 CocoaPods**：`open_filex` 5.0.0 起带 `Package.swift`；已删 `ios/Podfile` 与两个 `ios/Flutter/*.xcconfig` 的 Pods include。别把 Podfile 加回来（会触发 `Skipping pod install` → 启动失败）。

## 4. 沉浸标题栏（公共组件）
`lib/widgets/immersive_app_bar.dart`（`ImmersiveGlassLayer` 材质层 / `ImmersiveAppBar implements PreferredSizeWidget` / `immersiveProgressOf` / `immersiveBlurBands` / `kImmersive*` 常量与 Key）+ `lib/widgets/immersive_scaffold.dart`（`ImmersiveScaffold` 骨架：抽屉 / 滚动监听 / 路由切换复位）。
配方照网页版 Firefly semifull：贴顶全透明 → 滚动过 **50px** → `card-bg 45%` + 整条 `blur(20px)` + **仅顶端**一条高光阴影线（不是 border；**底发丝线 2026-10-19 已按要求永久删除**，`kImmersiveHairlineKey` 已删），过渡 **360ms `Cubic(0.22,1,0.36,1)`**，进度**二值化**（不跟手）。
- ① 别用 `Scaffold.appBar` + `AppBar.flexibleSpace` 承载铺满型内容：flexibleSpace 挂在 `OverflowBox(maxHeight: infinity)` 下，`StackFit.expand`/`Positioned.fill` 会拿到无界高度，`BackdropFilter` 被撑到全屏。自己实现 `PreferredSizeWidget` + `SizedBox(height: kToolbarHeight + 状态栏高)` 钉死。
- ② **Web 端不需要关模糊（2026-10-17 推翻旧结论）**：当年以为「Web 引擎不裁剪 BackdropFilter」，加了 `blurSupported = !kIsWeb`；实测 CanvasKit 裁剪正常、像素曲线与原生逐行重合，整页糊的真凶是 ①。**教训：别把「修完 A 之后症状也消失」当成「B 也确认是 bug」**。现在四端无平台分支。Web 断言用 `flutter test --platform chrome <用例>`（无需 dev server）。
- ③ 玻璃要看得见，内容必须从标题栏底下穿过：`ImmersiveScaffold` 默认 `extendBodyBehindAppBar: true`，但挂 appBar 会把 body 的 `MediaQuery.padding.top` 清成 0 → 组件自己补回；`ListView`/`GridView` 只在 `padding == null` 时自动套（写死 padding 的页面要自己加 `MediaQuery.paddingOf(context).top`），根部 `SafeArea` 必须 `top: false`。
- ④ **模糊是整条统一的**（2026-10-24 起）：一层 `BackdropFilter`、σ=20，配一层 45% 主题 `surface` 底色，与网页版 `backdrop-filter: blur(20px)` + `card-bg 45%` 一一对应。`ImmersiveGlassLayer` 已改 **Stateless**，不再需要 `BackdropGroup`/`BackdropKey`（只有一层，引擎本来只取样一次）。
  - **废弃：渐进模糊**。曾把标题栏横切成 20 条带、σ 自上而下从 20 递减到 0，让内容「淡出来」。但 `ImageFilter.blur` 的 σ 是常量，只能靠分带逼近，条与条之间必然有接缝：**过渡宽度 ≈ 2.56·σ**，Δσ=1 差约 2.5px（看不出），Δσ=6 差 15px（一眼横线）。用户两次反馈「割裂太严重」，最终要求整条统一。**以后别再自作聪明加回来**。
  - 若真要重做：所有横带共用一个 `BackdropKey`；`ShaderMask`/`Opacity` 包 `BackdropFilter` 会引入 saveLayer → backdrop 取不到样、模糊消失，这条路走不通。
  - 目检/回归：`test/immersive_glass_blur_test.dart`（原生 + Chrome 双跑）用竖直黑白硬边量 10%→90% 过渡宽度（**阈值穿越点亚像素插值**），断言：标题栏内每行都满糊 / 上下差 ≤10px / 条外一刀切。结构断言在 `test/immersive_app_bar_test.dart`。
- 左侧按钮取用顺序：`leading` > `onMenu` > Scaffold 抽屉 > 返回键；开抽屉用 `GlobalKey<ScaffoldState>`，**别在创建 Scaffold 的 context 上调 `Scaffold.of`**。

## 5. 课表双端同步（改一处必须改两处）
App 与博客 yiyu14.top 各一套实现，必须对齐：
1. 关键词词表：`lib/features/schedule/widgets/keyword_highlight.dart` 的 `kwMap` ↔ 博客 `src/components/widget/ClassSchedule.astro` 的 `TT_KW_MAP`。
2. 标注解析与档位：`parseAnnotations + sentenceTierOf + buildKeywordSpans` ↔ `ttParseMarks + ttSentTierOf + hlLog`。
3. 面板布局顺序：课表网格 → **本周调整** → 通知 → 图例 → 课程详情 → 数据更新历。2026-10-24 按用户要求把「本周调整」从页尾提到**通知之上**、紧跟网格，对齐网页版 `#tt-grid` → `#tt-changes` 的位置（网页版图例在调整之后、通知之前，App 图例仍在通知后，属既有布局未动）。
4. 数据文件 `assets/data/schedule-2615.json` ↔ 博客 `public/assets/data/schedule-2615.json`（**必须两份 `cp` 同步**，sha256 应相同）。
5. 同格取格优先级（一格只显示一条）：App `ResolvedEntry.cellPriority` + `resolve()` 的 `cells` 索引 ↔ 博客 `render()` 的 `cellRank`；规则＝**本周实际发生（有课/停课/新增）> 晚自习 > 非本周占位**，同级后者胜。
- App 课表数据**网络优先（yiyu14.top）+ 打包资源兜底**，纯数据更新不必发新 APK；但打包那份仍需按 4 同步（否则断网用户看旧课表），且同步后测试里写死的数据量断言（课数/overrides/通知条数/第 N 周列集合）要一起改。定位格子按 `entry.key`，别用 `find.byType(CourseCell).first`。
- 对齐手段：抽 astro 函数到 node 跑用例 + Dart/JS 分档对拍。

## 6. 文字高亮（铁律）
- **重点不写死、也不靠算法猜**：每次新信息入库（新通知/更新历）必须**先读内容再逐条标注**；固定词表只负责词类配色，锚点算法只做未审阅内容的兜底。
- 标注语法（写在正文里、渲染前整段剥离）：`{{…}}` 必看、`[[…]]` 关注、`((…))` 一般（显式压档）。**整段出现过任何标注即视为已人工审阅，全以标注为准**（没标的句子＝一般）；一个标注都没有才回退算法。括号不成对按原文保留。正文别出现裸 `{{` / `[[` / `((`（JSON 结构符号不进解析器）。
- 范围：`meta.changelog` 的 `content` + `notices` 的 `text`。**例外「本周调整」面板**（resolver 运行时拼「课程名」+note，无法内联标注）**整层关掉定档**：不铺底纹、不加竖条、不按档加粗，只留词表着色（App `buildKeywordSpans(..., tiered: false)`；博客 `hlLog(c.txt, true)`）。
- 长内容铁律：凡是「一段话」级信息型正文（通知/更新历/本周调整/课程详情说明，以及以后任何长文展示面）一律接这套高亮，不留纯文本角落。纯 UI 状态提示（离线提醒/无课横幅/图例）不接。
- 密度：底色只留「必看」、加粗只留「人工标注」；关键词只「着色 + 同色划线」，不套色块/描边/统一加粗。标注每条至多 1 处 `{{}}` + 1 处 `[[]]`；讲工具本身与历史条目一律 `(( ))` 压档。

## 7. 本机环境与踩坑
- 构建权限：`flutter build apk` 会 rename/unlink `~/it/flutter/flutter/bin/cache/engine.stamp.tmp.*`，沙箱以 `file-unlink` 拒绝 → **必须前台 + 脱离沙箱执行（后台模式弹不出授权）**。Flutter `/Users/yuki/it/flutter/flutter/bin/flutter`；Android SDK `/Users/yuki/it/andriodstudio/sdk`（`build-tools/36.0.0/apksigner`）。`flutter test` 需 `env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u HTTPS_proxy`（否则 flutter_tester 的本地 WebSocket 被代理劫持）。
- 代理选择性抽风：`github.com/<repo>.git/info/refs?service=git-receive-pack` 间歇 000，但同一时刻其它站点 200。**别一看到 000/502 就判断网**，先 `curl -o /dev/null -w "%{http_code}"` 探，再循环重试 push（1～10 次内成）。
- `open_file_plus` 不可用（2026-10-24 实测）：3.4.1+1（2024-03 停更）Android 端还在用 `PluginRegistry.Registrar`，Flutter 3.47 已删该类 → 编译失败。**别再换回 open_file_plus**；`open_filex` 正常（本项目已用 5.0.0）。
- 别手动删 Flutter SDK 的 `flutter_tools/gradle/build/kotlin/compileKotlin/classpath-snapshot` 再跑 `android/gradlew`：会用 PATH 上 JDK 27 重编 `:gradle`，报 `Unsupported class file major version 71`。验证 Android 编译一律走 `flutter build apk`。
- `.widget_preview/`（Flutter Widget Preview 脚手架）写死绝对路径：项目搬到 `~/Documents/gdmec/projects/2615/myclass` 后，`pubspec.yaml`（`dependency_overrides` 的 path）、`pubspec.lock`、`preview_manifest.json`、`lib/src/dtd/dtd_connection_info.dart` 四处仍是旧路径 → IDE 报 `could not find package myclass ...`（exit 66）。改这四处 + 删 `.dart_tool`/`build` + 重跑 `flutter pub get --no-example`。**`dependency_overrides` 的键必须是包名 `yuki_blog_app`，不能是目录名 `myclass`**。该目录被 gitignore。

## 8. 性能与滚动基准
- **课表页滚动卡顿（2026-10-24 已修）**：三个成因叠加 —— ① `ListView` 默认 `cacheExtent` 只有 250，滑两屏就把课表网格回收，滑回来重建整张网格 + 后面所有面板，单帧 build 30~110ms；② `buildKeywordSpans` 每次重建都从头跑「剥标注 → 词表正则 → 分句 → 逐句打分」，二十多条更新历叠起来很可观；③ 更新历每行套 `IntrinsicHeight`，每行 layout 两遍。修法：`scrollCacheExtent: ScrollCacheExtent.pixels(800)`、高亮结果按 `(content, isDark, tiered, baseStyle)` 缓存（`InlineSpan` 不可变可复用，上限 256 条 FIFO）、色条改 `Stack` + `Positioned(top/bottom)` 拉伸（`StackFit.passthrough` 保宽度）。
- API 变更（Flutter 3.47）：`ListView.cacheExtent` 已弃用 → `scrollCacheExtent`，类型是 `ScrollCacheExtent.pixels(n)`，**`material.dart` 不导出**，要 `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`。
- 基准跑法（只有 profile 数据有意义；`flutter test integration_test/...` 不支持 `--profile`，必须走 drive）：
  `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/scroll_perf_test.dart -d macos --profile`
  结果写 `build/integration_response_data.json`（微秒）。判断线：build/rasterizer 平均 >16.7ms 必掉帧。
- 基线（macOS profile，滚动 6 个来回）：修前 build 均 1.63 / 最差 109.7ms（6 帧超预算）、raster 均 3.10 / 最差 44.1ms；修后 build 均 0.24 / 最差 2.5ms（0 帧超预算）、raster 均 1.36 / 最差 8.8ms。**回归时先看「build 超预算帧数」是否为 0**。
