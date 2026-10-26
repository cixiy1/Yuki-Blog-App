# Yuki-Blog App 项目记忆

## 1. 标识与发版
- 工程名 **Yuki-Blog App**，显示名 **Yuki Blog**（全英），Dart 包 `yuki_blog_app`；仓库 `cixiy1/Yuki-Blog-App`（**公开**，班级个人材料 `/材料/` 已 gitignore，别 `git add -A` 误推）。
- 应用 ID：Android `com.yiyu14.yuki_blog_app`；iOS `com.yiyu14.yukiblogapp`；**macOS `com.yiyu14.yukiblogapp.mac`**。Bundle ID 是 UTI，只允许字母/数字/连字符/点，下划线非法（macOS 报 `invalid character in Bundle Identifier`，iOS 报 `attribute 'name' is invalid`）。改标识要同步：android namespace/applicationId/源码目录/Manifest、iOS `PRODUCT_BUNDLE_IDENTIFIER`+`PRODUCT_NAME`（连带 pbxproj `TEST_HOST`、xcscheme `BuildableName`）、macOS `AppInfo.xcconfig`+pbxproj RunnerTests、web `manifest.json`/`index.html`。**别把 iOS/macOS 顺手"统一"回下划线版**。
  - **macOS 与 iOS 绝不能同 id**：iOS 真机产物被 LaunchServices 注册成 `platform = iOS`，同 id 两份解析，`open` 命中 iOS 那条返回 1 → `Failed to foreground app; open returned 1` → **窗口拉不起来/纯黑**。确认：`lsregister -dump | grep -A2 <id>` 见 `platform: iOS` 即中招；`open` 退出码 1→0 即修好。
- 发版：改 `pubspec.yaml` version → Conventional Commits 推送 → `git tag vX.Y.Z && git push origin vX.Y.Z` → Actions 自动测试+构建+发 Release（App 内更新弹窗读该 Release）。
- 命名铁律：不要中英文夹杂。

## 2. 发布铁律（最高优先级）
**未经用户明确允许：不升版本号、不构建、不 `git push`、不打 tag、不触发上线（CI 发版 / 博客 push 上 Cloudflare）。** 默认只做「改代码 → `flutter analyze` + `flutter test` → 本地 commit」，改完说「等你允许再升版本/构建/推送」。
- **「本地 commit 不受限」≠「构建不受限」**：升版本是发版信号、构建产出可分发产物，两者都要授权（曾一次做完被制止）。回退：改回 version → `git commit --amend --no-edit`（未推送才可）→ 删产出包。
- 判断推送是否真失败：`git push | tail` 退出码取的是 `tail`，会误判。看 `git status -sb | head -1` 有无 `[ahead N]`。

## 3. 签名
**Android（固定 keystore，铁律）**：release 一律用 `android/key.properties` 指定的 keystore，**签名参数全部由用户填写，我不得代拟任何口令/别名/证书信息**。模板 `key.properties.example`，生成 `tool/gen_release_keystore.sh`，导出 Secrets/备份 `tool/make_signing_secrets.sh`。未配置时回退 AGP debug 签名（每台机器现生成，互相无法覆盖安装 → `INSTALL_FAILED_UPDATE_INCOMPATIBLE`，App 内更新失效）。keystore+口令丢＝永远发不了可覆盖升级的版本，必须有仓库外备份。
- 已定参数（勿改）：`keyAlias=yuki-blog`、`dname=CN=Yukiho, O=Yukiho, C=CN`、36500 天、`storeFile=release.jks`。口令用户自持，**不记入任何文档**。
- 证书 SHA-256 `91:40:6D:E2:74:3B:11:6E:92:86:5A:26:80:B5:D4:66:1D:FA:DB:ED:49:BF:6E:31:00:5F:D6:35:B5:6B:5B:E2`，核对 `apksigner verify --print-certs`。备份在仓库外 `~/Documents/Yuki/signing-2615/`。换签名＝所有用户卸载重装。

**iOS 真机**：Team `R4A23FHD6Y`（证书有效到 2027-10-24），已写入 pbxproj Runner 三个 config（`CODE_SIGN_STYLE=Automatic` + `DEVELOPMENT_TEAM`）。装法＝`flutter build ios --release` → `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` → `devicectl device process launch --device <udid> com.yiyu14.yukiblogapp`。
- **iOS 14+ debug 版只能从 Flutter/Xcode 启动**（桌面点开报 `debug mode Flutter apps can only be launched from Flutter tooling`）→ 桌面能开必须装 release/profile 版。
- `flutter run` 在真机常卡在「local network」（mDNS 5353 被拦），**App 其实已装好并启动**，别当失败。
- UDID：iPhone 12 `00008101-001459AA0E46001E`；iPhone 11 Pro Max `00008030-00180C622208802E`（iOS 16+ 须先在设备上开「开发者模式」，Mac 侧无命令开关）。
- 描述文件 `ProvisionedDevices` 只列已登记机型，**换机型必须重新 build 让 Xcode 用 `-allowProvisioningUpdates` 登记+重签**。免费个人团队 profile 7 天过期。
- **iOS 工程全 SPM 化，不装 CocoaPods**：`open_filex` 5.0.0 起带 `Package.swift`；已删 `ios/Podfile` 与两个 `ios/Flutter/*.xcconfig` 的 Pods include。别把 Podfile 加回来（`Skipping pod install` → 启动失败）。

## 4. 沉浸标题栏（公共组件）
`lib/widgets/immersive_app_bar.dart`（`ImmersiveGlassLayer` / `ImmersiveAppBar implements PreferredSizeWidget` / `immersiveProgressOf` / `kImmersive*` 常量与 Key）+ `lib/widgets/immersive_scaffold.dart`（抽屉 / 滚动监听 / 路由切换复位）。
配方照网页版 Firefly semifull：贴顶全透明 → 滚过 **50px** → `card-bg 45%` + 整条 `blur(20px)` + **仅顶端**一条高光阴影线（底发丝线 2026-10-19 已按要求永久删除），过渡 **360ms `Cubic(0.22,1,0.36,1)`**，进度**二值化**（不跟手）。
- ① 别用 `Scaffold.appBar` + `AppBar.flexibleSpace` 承载铺满型内容：flexibleSpace 挂在 `OverflowBox(maxHeight: infinity)` 下，`StackFit.expand`/`Positioned.fill` 拿到无界高度 → `BackdropFilter` 被撑到全屏。自己实现 `PreferredSizeWidget` + `SizedBox(height: kToolbarHeight + 状态栏高)`。
- ② **Web 不需要关模糊**（旧结论「Web 不裁剪 BackdropFilter」已推翻，CanvasKit 裁剪正常）；整页糊的真凶是 ①。**别把「修完 A 后症状也消失」当成「B 也确认是 bug」**。Web 断言 `flutter test --platform chrome <用例>`。
- ③ 玻璃要看得见，内容必须从标题栏底下穿过：`extendBodyBehindAppBar: true`，但挂 appBar 会把 body 的 `MediaQuery.padding.top` 清 0 → 组件自己补回；写死 padding 的页面要自己加 `MediaQuery.paddingOf(context).top`，根部 `SafeArea` 必须 `top: false`。
- ④ **模糊整条统一**（2026-10-24 起，用户明确推翻渐进）：一层 `BackdropFilter` σ=20 + 一层 45% `surface` 底色。`ImmersiveGlassLayer` 是 **Stateless**，不需要 `BackdropGroup`/`BackdropKey`（只一层，引擎本就只取样一次）。
  - **渐进模糊已废弃，别再自作聪明加回来**：σ 恒定，纵向渐变只能横切条带逼近，接缝必然可见（过渡宽度 ≈ 2.56·σ，Δσ=6 约 15px 横线）。`ShaderMask`/`Opacity` 包 `BackdropFilter` 会引入 saveLayer → backdrop 取不到样。
  - 回归：`test/immersive_glass_blur_test.dart`（原生 + Chrome）量 10%→90% 过渡宽度（阈值穿越点亚像素插值）；结构断言在 `test/immersive_app_bar_test.dart`。
- 左侧按钮取用顺序：`leading` > `onMenu` > Scaffold 抽屉 > 返回键；开抽屉用 `GlobalKey<ScaffoldState>`，**别在创建 Scaffold 的 context 上调 `Scaffold.of`**。

## 5. 课表（双端同步 + 网格布局）
App 与博客 yiyu14.top 各一套实现，改一处必须改两处：
1. 关键词词表：`keyword_highlight.dart` 的 `kwMap` ↔ 博客 `ClassSchedule.astro` 的 `TT_KW_MAP`。
2. 标注解析与档位：`parseAnnotations + sentenceTierOf + buildKeywordSpans` ↔ `ttParseMarks + ttSentTierOf + hlLog`。
3. 面板布局顺序（2026-10-26 用户定稿）：课表网格 → **课程详情**（选中才出现）→ 通知 → **本周调整** → 图例 → 数据更新历 → 页脚。详情紧贴网格是「点哪格就在它下面看」；通知在调整之上。**App 与网页版此处已不一致**，别按网页版 `#tt-grid → #tt-changes` 再去"对齐"回来（来回折腾过一轮）。
4. 数据文件 `assets/data/schedule-2615.json` ↔ 博客 `public/assets/data/schedule-2615.json`（**必须两份 `cp` 同步**，sha256 相同）。
5. 同格优先级（一格只显示一条）：App `ResolvedEntry.cellPriority` + `resolve()` 的 `cells` ↔ 博客 `render()` 的 `cellRank`；规则＝**本周实际发生（有课/停课/新增）> 晚自习 > 非本周占位**，同级后者胜。
- **作息行标内联进横向滚动视图（2026-10-26 定稿）**：`TimetableGrid` = `SingleChildScrollView(horizontal, child: Column[_DayHeaderRow(首尾留 labelWidth 占位), const SizedBox(_headerGap), ..._GridRow])`，每个 `_GridRow` = `[SlotLabelCell(行首), ...各天格子, if(放不下) SlotLabelCell(行尾, alignEnd)]`。**行标和课程格子在同一个横向滚动视图里、滚动时一起走**——不再有固定在外层的行标列（用户明确「要成为滚动的一部分，而不是置于外层」）。`fitsWithoutScroll`（`maxWidth >= labelWidth + 天数×cellMinWidth`）决定行尾是否补行标：放得下只留行首一列；放不下行尾再补一列、列宽按 2 列扣。`_headerHeight(28)` 固定表头行高。**行标无底色、无边框**，纯文本压在页面背景上、靠留白和课程格子区分。节次 11/w600，时间 9/maxLines 2。测试 `test/timetable_grid_test.dart`（窄 400：行标=行数×2、右列在左列右侧、横向拖动行标随内容左移；宽 900：行标=行数、不滚）。
  - 坑：`Row` 的非 flex 子拿到 `0..infinity` 松约束，行标 Column 直接 `crossAxisAlignment: stretch` 会把无限宽度传给子节点 → `BoxConstraints forces an infinite width`。外面包 `SizedBox(width: labelWidth)`。
- App 课表数据**网络优先（yiyu14.top）+ 打包资源兜底**，纯数据更新不必发新 APK；但打包那份仍需按 4 同步，且同步后测试里写死的数据量断言（课数/overrides/通知条数/第 N 周列集合）要一起改。定位格子按 `entry.key`，别用 `find.byType(CourseCell).first`。
- 对齐手段：抽 astro 函数到 node 跑用例 + Dart/JS 分档对拍。

## 6. 文字高亮（铁律）
- **重点不写死、也不靠算法猜**：每次新信息入库（新通知/更新历）必须**先读内容再逐条标注**；固定词表只负责词类配色，锚点算法只兜底未审阅内容。
- 语法（写在正文里、渲染前整段剥离）：`{{…}}` 必看、`[[…]]` 关注、`((…))` 一般。**整段出现过任何标注即视为已人工审阅，全以标注为准**（没标的句子＝一般）；一个标注都没有才回退算法。括号不成对按原文保留。正文别出现裸 `{{`/`[[`/`((`。
- 范围：`meta.changelog.content` + `notices.text`。**例外「本周调整」面板**（运行时拼「课程名」+note，无法内联标注）**整层关掉定档**：不铺底纹、不加竖条、不按档加粗，只留词表着色（App `buildKeywordSpans(..., tiered: false)`；博客 `hlLog(c.txt, true)`）。
- 长内容铁律：凡「一段话」级信息型正文（通知/更新历/本周调整/课程详情说明，以及以后任何长文展示面）一律接这套高亮。纯 UI 状态提示（离线提醒/无课横幅/图例）不接。
- 密度：底色只留「必看」、加粗只留「人工标注」；关键词只「着色 + 同色划线」。每条至多 1 处 `{{}}` + 1 处 `[[]]`；讲工具本身与历史条目一律 `(( ))`。

## 7. 本机环境与踩坑
- 构建权限：`flutter build apk` 会 rename/unlink `~/it/flutter/flutter/bin/cache/engine.stamp.tmp.*`，沙箱以 `file-unlink` 拒绝 → **必须前台 + 脱离沙箱（后台模式弹不出授权）**。Flutter `/Users/yuki/it/flutter/flutter/bin/flutter`；Android SDK `/Users/yuki/it/andriodstudio/sdk`（`build-tools/36.0.0/apksigner`）。`flutter test` 需 `env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u HTTPS_proxy`（否则 flutter_tester 的本地 WebSocket 被代理劫持）。
- 代理选择性抽风：github 的 `info/refs?service=git-receive-pack` 间歇 000，同时刻其它站点 200。**别一看到 000/502 就判断网**，先 `curl -o /dev/null -w "%{http_code}"` 探，再循环重试 push（1～10 次内成）。
- `open_file_plus` 不可用：3.4.1+1 仍在用 v1 `PluginRegistry.Registrar`，Flutter 3.47 已删该类 → 编译失败。**别换回 open_file_plus**；`open_filex` 5.0.0 正常。
- 别手动删 Flutter SDK 的 `compileKotlin/classpath-snapshot` 再跑 `android/gradlew`：会用 PATH 上 JDK 27 重编 `:gradle`，报 `Unsupported class file major version 71`。验证 Android 编译一律走 `flutter build apk`。
- `.widget_preview/` 写死绝对路径（项目搬过家）：`pubspec.yaml` 的 `dependency_overrides` path、`pubspec.lock`、`preview_manifest.json`、`lib/src/dtd/dtd_connection_info.dart` 四处，改完删 `.dart_tool`/`build` 重跑 `flutter pub get --no-example`。**`dependency_overrides` 键必须是包名 `yuki_blog_app`**。该目录被 gitignore。
- 截图回归：`RepaintBoundary.toImage` 在 `testWidgets` 的 fake async 里**永久挂起**，必须包 `tester.runAsync`。macOS 无 `timeout` 命令；zsh 下 `rm -f /tmp/x_*.png` 无匹配会报 `no matches found` 并中断整条命令链。

## 8. 性能与滚动基准
- **禁止「滚动页里嵌限高滚动框」**：浏览器会把滚到头的滚动链式传给父级，Flutter 不会（`pointerSignalResolver` 只交给一个命中者，内层注册在先就赢），光标停在内层上页面彻底滚不动（量法：`TestPointer(kind: trackpad)` + `pointer.scroll`）。「数据更新历」已改**折叠 4 条 + 展开全部**（`ChangelogPanel.collapsedCount`，全量 51 条不再一次全建）。以后长列表面板都按这个来，别照搬网页版。
- **课表页滚动卡顿（2026-10-24 修）**三成因：`ListView` 默认 `cacheExtent` 只有 250（滑两屏就回收网格，单帧 build 30~110ms）→ `scrollCacheExtent: ScrollCacheExtent.pixels(800)`；`buildKeywordSpans` 每次都全量重算 → 按 `(content, isDark, tiered, baseStyle)` 缓存 256 条 FIFO；更新历每行 `IntrinsicHeight` layout 两遍 → 改 `Stack` + `Positioned(top/bottom)` 拉伸（`StackFit.passthrough` 保宽度）。
- API：`ListView.cacheExtent` 在 3.47 已弃用 → `scrollCacheExtent`，类型 `ScrollCacheExtent.pixels(n)`，**`material.dart` 不导出**，要 `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`。
- 基准跑法（只有 profile 有意义；`flutter test integration_test/...` 不支持 `--profile`）：`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/scroll_perf_test.dart -d macos --profile`，结果写 `build/integration_response_data.json`（微秒）。判断线：build/rasterizer 平均 >16.7ms 必掉帧。
- 基线（macOS profile，滚动 6 个来回）：修前 build 均 1.63 / 最差 109.7ms（6 帧超预算）、raster 均 3.10 / 最差 44.1ms；修后 build 均 0.24 / 最差 2.5ms（0 帧超预算）、raster 均 1.36 / 最差 8.8ms。**回归先看「build 超预算帧数」是否为 0**。

## 9. 待办页（todo，2026-10-26 完成 + 自动拉取增强）
- 目录 `lib/features/todo/`：`todo_page.dart`(页面) + `todo_model.dart`(TodoItem/TodoCategory/TodoSource) + `todo_storage.dart`(TodoStorage + TodoStore + FileTodoStorage + MemoryTodoStorage)；远端源 `lib/core/todo_repository.dart`(NetworkTodoRemoteSource + parseTodoHtml)。
- **自动拉取**：打开即拉取博客《待办清单》文章 `https://yiyu14.top/posts/todo/`（回退 raw.githubusercontent.com / cdn.jsdelivr.net 的 `src/content/posts/todo.md`，二者都含 `.todo-root` HTML 结构），用 `html` 包（**新增依赖 ^0.15.4**）解析成远端待办项（data-todo-id / 标题 / 分组→分类 / .todo-status 截止 / .todo-note 备注 / .todo-subhead 子标题上下文）。**不另建 JSON、不碰博客仓库、不触发上线**——直接吃那篇文章。
- **版本管理合并**：远端决定「有哪些任务 + 标题/分类/截止/备注」；本地保留 ①完成状态 ②自建项(source=local) ③对远端项的删除(墓碑 `deletedRemoteIds`)。合并：本地自建项原样保留；远端项按 `remoteId` 匹配刷新内容、保留 done；远端已移除的项丢弃；墓碑项不再复活。`TodoItem` 增 `source/remoteId/dueLabel`，`dueText()` 优先显示远端原文。
- 排序：未完成在前、有截止日(`dueDate` 或标签解析出的日期)靠前、再按 `createdAt`。`id`=时间戳+自增；远端项 id=`remote-<data-todo-id>`。
- 交互：统计头 + `SegmentedButton` 筛选 + 列表(Checkbox/分类 chip/逾期红/点整条编辑/滑动删除) + 右下角 `Stack` 内 FAB（HomeShell 不透传 Scaffold.FAB）；**头部加手动同步按钮 + 同步状态(已同步/同步中/离线)，列表套 `RefreshIndicator` 下拉刷新**。编辑远端项会转为本地自建(source=local)以免被覆盖。离线回退上次合并的本地数据。
- FAB 仍是 body 内 `Positioned`（非 Scaffold FAB）；页面只返回 body，被 `HomeShell` 的 `ImmersiveScaffold` 包裹。
- 测试：`test/todo_page_test.dart`(注入 MemoryTodoStorage/FakeRemote，空态/新建/完成筛选/删除/编辑/自动拉取/离线/墓碑复活/序列化往返) + `test/todo_repository_test.dart`(解析器，含真实文章结构样例)。全量 140 项测试全绿。
- 待定：备注长文是否接 keyword_highlight（当前未接）；远端无「完成态」概念（博客侧 done 在 localStorage，App 不读），完成态纯本地。
