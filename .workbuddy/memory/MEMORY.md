# Yuki-Blog App 项目记忆

## 1. 标识与发版
- 工程 **Yuki-Blog App**（显示名 Yuki Blog，全英），Dart 包 `yuki_blog_app`；仓库 `cixiy1/Yuki-Blog-App`（公开，班级个人材料 `/材料/` 已 gitignore，别 `git add -A` 误推）。
- 应用 ID：Android `com.yiyu14.yuki_blog_app`；iOS `com.yiyu14.yukiblogapp`；**macOS `com.yiyu14.yukiblogapp.mac`**。Bundle ID 是 UTI，只允许字母/数字/连字符/点，下划线非法。
  - 改标识要同步：android namespace/applicationId/源码目录/Manifest、iOS `PRODUCT_BUNDLE_IDENTIFIER`+`PRODUCT_NAME`（连带 pbxproj `TEST_HOST`、xcscheme `BuildableName`）、macOS `AppInfo.xcconfig`+pbxproj RunnerTests、web `manifest.json`/`index.html`。**别把 iOS/macOS 顺手"统一"回下划线版**。
  - **macOS 与 iOS 绝不能同 id**：同 id 时 `open` 命中 iOS 那条返回 1 → 窗口拉不起来/纯黑（`Failed to foreground app; open returned 1`）。
- 发版：改 `pubspec.yaml` version → Conventional Commits 推送 → `git tag vX.Y.Z && git push origin vX.Y.Z` → Actions 自动测试+构建+发 Release（App 内更新弹窗读该 Release）。
- 命名铁律：不要中英文夹杂。

## 2. 发布铁律（最高优先级）
**未经用户明确允许：不升版本号、不构建、不 `git push`、不打 tag、不触发上线（CI 发版 / 博客 push 上 Cloudflare）。** 默认只做「改代码 → `flutter analyze` + `flutter test` → 本地 commit」，改完说「等你允许再升版本/构建/推送」。
- **「本地 commit 不受限」≠「构建不受限」**：升版本是发版信号、构建产出可分发产物，两者都要授权。回退：改回 version → `git commit --amend --no-edit`（未推送才可）→ 删产出包。
- 判断推送是否真失败：看 `git status -sb | head -1` 有无 `[ahead N]`，别信 `git push | tail` 的退出码（取的是 `tail`）。

## 3. 签名
**Android（固定 keystore，铁律）**：release 一律用 `android/key.properties` 指定的 keystore，**签名参数全部由用户填写，我不得代拟任何口令/别名/证书信息**。模板 `key.properties.example`，生成 `tool/gen_release_keystore.sh`，备份 `tool/make_signing_secrets.sh`。未配置回退 AGP debug 签名（互相无法覆盖安装 → App 内更新失效）。keystore+口令丢＝永远发不了可覆盖升级的版本，必须仓库外备份。
- 已定参数（勿改）：`keyAlias=yuki-blog`、`dname=CN=Yukiho, O=Yukiho, C=CN`、36500 天、`storeFile=release.jks`。口令用户自持，**不记入任何文档**。
- 证书 SHA-256 `91:40:6D:E2:74:3B:11:6E:92:86:5A:26:80:B5:D4:66:1D:FA:DB:ED:49:BF:6E:31:00:5F:D6:35:B5:6B:5B:E2`，核对 `apksigner verify --print-certs`。备份 `~/Documents/Yuki/signing-2615/`。换签名＝所有用户卸载重装。

**iOS 真机**：Team `R4A23FHD6Y`（证书到 2027-10-24），pbxproj Runner 三个 config 已写 `CODE_SIGN_STYLE=Automatic`+`DEVELOPMENT_TEAM`。装法＝`flutter build ios --release` → `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` → `devicectl device process launch --device <udid> com.yiyu14.yukiblogapp`。
- **iOS 14+ debug 版只能从 Flutter/Xcode 启动**（桌面点开报 `debug mode Flutter apps can only be launched from Flutter tooling`）。
- `flutter run` 在真机常卡「local network」（mDNS 5353 被拦），**App 其实已装好启动**，别当失败。
- UDID：iPhone 12 `00008101-001459AA0E46001E`；iPhone 11 Pro Max `00008030-00180C622208802E`（iOS 16+ 须先开「开发者模式」）。
- 描述文件 `ProvisionedDevices` 只列已登记机型，**换机型必须重新 build** 让 Xcode 用 `-allowProvisioningUpdates` 登记+重签。免费 profile 7 天过期。
- **iOS 工程全 SPM 化，不装 CocoaPods**：`open_filex` 5.0.0 起带 `Package.swift`；已删 `ios/Podfile` 与 `ios/Flutter/*.xcconfig` 的 Pods include。别把 Podfile 加回来。

## 4. 沉浸标题栏（公共组件）
`lib/widgets/immersive_app_bar.dart`（`ImmersiveGlassLayer` / `ImmersiveAppBar` / `immersiveProgressOf` / `kImmersive*`）+ `lib/widgets/immersive_scaffold.dart`（抽屉 / 滚动监听 / 路由切换复位）。
配方照网页版 Firefly semifull：贴顶全透明 → 滚过 **50px** → `card-bg 45%` + 整条 `blur(20px)` + **仅顶端**一条高光阴影线，过渡 **360ms `Cubic(0.22,1,0.36,1)`**，进度**二值化**。
- ① 别用 `Scaffold.appBar` + `AppBar.flexibleSpace` 承载铺满型内容（flexibleSpace 挂在 `OverflowBox(maxHeight: infinity)` 下 → `BackdropFilter` 撑到全屏）。自己实现 `PreferredSizeWidget` + `SizedBox(height: kToolbarHeight + 状态栏高)`。
- ② **Web 不需要关模糊**（旧结论「Web 不裁剪 BackdropFilter」已推翻，CanvasKit 裁剪正常）；整页糊的真凶是 ①。别把「修完 A 后症状也消失」当成「B 也确认是 bug」。
- ③ `extendBodyBehindAppBar: true` 让内容从标题栏底下穿过，但挂 appBar 会清 body `MediaQuery.padding.top` → 组件自己补回；写死 padding 的页面要加 `MediaQuery.paddingOf(context).top`，根部 `SafeArea(top: false)`。
- ④ **模糊整条统一**（一层 `BackdropFilter` σ=20 + 一层 45% `surface` 底色），`ImmersiveGlassLayer` 是 **Stateless**，不需要 `BackdropGroup`/`BackdropKey`。**渐进模糊已废弃**（接缝必然可见，`ShaderMask`/`Opacity` 包 `BackdropFilter` 会引入 saveLayer 取不到样）。
- 左侧按钮取用顺序：`leading` > `onMenu` > Scaffold 抽屉 > 返回键；开抽屉用 `GlobalKey<ScaffoldState>`，**别在创建 Scaffold 的 context 上调 `Scaffold.of`**。

## 5. 课表（双端同步 + 网格布局）
App 与博客 yiyu14.top 各一套，改一处必须改两处：
1. 关键词词表 `keyword_highlight.dart` 的 `kwMap` ↔ 博客 `ClassSchedule.astro` 的 `TT_KW_MAP`。
2. 标注解析与档位 `parseAnnotations + sentenceTierOf + buildKeywordSpans` ↔ `ttParseMarks + ttSentTierOf + hlLog`。
3. 面板布局顺序（2026-10-26 定稿）：课表网格 → **课程详情**（选中才出现）→ 通知 → **本周调整** → 图例 → 数据更新历 → 页脚。**App 与网页版此处已不一致**，别按网页版 `#tt-grid → #tt-changes` 对齐回去。
4. 数据文件 `assets/data/schedule-2615.json` ↔ 博客 `public/assets/data/schedule-2615.json`（**两份 `cp` 同步**，sha256 相同）。
5. 同格优先级：App `ResolvedEntry.cellPriority` + `resolve().cells` ↔ 博客 `render().cellRank`；规则＝**本周实际发生（有课/停课/新增）> 晚自习 > 非本周占位**，同级后者胜。
- **作息行标内联进横向滚动视图（2026-10-26 定稿）**：`TimetableGrid` = `SingleChildScrollView(horizontal, child: Column[_DayHeaderRow(首尾留 labelWidth 占位), SizedBox(_headerGap), ..._GridRow])`，`_GridRow` = `[SlotLabelCell(行首), ...各天格子, if(!fitsWithoutScroll) SlotLabelCell(行尾, alignEnd)]`。**行标与格子同滚动，不固定外层**。`fitsWithoutScroll`(`maxWidth >= labelWidth + 天数×cellMinWidth`) 决定行尾补行标：放得下只留行首；放不下补行尾、列宽按 2 列扣。行标无底色无边框纯文本，节次 11/w600、时间 9/maxLines2。`_headerHeight(28)` 固定表头高。测试 `test/timetable_grid_test.dart`。
  - 坑：`Row` 非 flex 子拿到 `0..infinity` 松约束，行标 Column 用 `crossAxisAlignment: stretch` 会把无限宽传给子节点 → `BoxConstraints forces an infinite width`。外面包 `SizedBox(width: labelWidth)`。
- App 课表数据**网络优先（yiyu14.top）+ 打包资源兜底**；打包那份仍按 4 同步，同步后测试里写死的数据量断言要一起改。定位格子按 `entry.key`。

## 6. 文字高亮（铁律）
- **重点不写死、也不靠算法猜**：新信息入库必须**先读内容再逐条标注**；固定词表只负责词类配色，锚点算法只兜底未审阅内容。
- 语法（写在正文里、渲染前整段剥离）：`{{…}}` 必看、`[[…]]` 关注、`((…))` 一般。**整段出现过任何标注即视为已人工审阅，全以标注为准**（没标＝一般）；一个标注都没有才回退算法。括号不成对按原文保留，正文别出现裸 `{{`/`[[`/`((`。
- 范围：`meta.changelog.content` + `notices.text`。**例外「本周调整」面板**整层关掉定档（不铺底纹/不加竖条/不按档加粗，只留词表着色）：App `buildKeywordSpans(..., tiered: false)`；博客 `hlLog(c.txt, true)`。
- 长内容铁律：凡「一段话」级信息型正文（通知/更新历/本周调整/课程详情说明）一律接这套高亮；纯 UI 状态提示（离线提醒/无课横幅/图例）不接。
- 密度：底色只留「必看」、加粗只留「人工标注」；关键词只「着色 + 同色划线」。每条至多 1 处 `{{}}` + 1 处 `[[]]`；讲工具本身与历史条目一律 `(( ))`。

## 7. 本机环境与踩坑
- 构建权限：`flutter build apk` 会 rename/unlink `~/it/flutter/flutter/bin/cache/engine.stamp.tmp.*`，沙箱以 `file-unlink` 拒绝 → **必须前台 + 脱离沙箱**。Flutter `/Users/yuki/it/flutter/flutter/bin/flutter`；Android SDK `/Users/yuki/it/andriodstudio/sdk`（`build-tools/36.0.0/apksigner`）。`flutter test` 需 `env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u HTTPS_proxy`。
- 代理选择性抽风：github 的 `info/refs?service=git-receive-pack` 间歇 000。**别一看到 000/502 就判断网**，先 `curl -o /dev/null -w "%{http_code}"` 探，再循环重试 push（1～10 次内成）。
- `open_file_plus` 不可用（3.4.1+1 用 v1 `PluginRegistry.Registrar`，Flutter 3.47 已删该类）。**别换回**；`open_filex` 5.0.0 正常。
- 别手动删 Flutter SDK 的 `compileKotlin/classpath-snapshot` 再跑 `android/gradlew`（会用 PATH 上 JDK 27 重编 `:gradle` → `Unsupported class file major version 71`）。验证 Android 编译一律走 `flutter build apk`。
- `.widget_preview/` 写死绝对路径（项目搬过家）：`pubspec.yaml` 的 `dependency_overrides` path、`pubspec.lock`、`preview_manifest.json`、`lib/src/dtd/dtd_connection_info.dart` 四处，改完删 `.dart_tool`/`build` 重跑 `flutter pub get --no-example`。`dependency_overrides` 键必须是包名 `yuki_blog_app`。该目录被 gitignore。
- 截图回归：`RepaintBoundary.toImage` 在 `testWidgets` 的 fake async 里**永久挂起**，必须包 `tester.runAsync`。zsh 下 `rm -f /tmp/x_*.png` 无匹配会报 `no matches found` 并中断整条命令链。

## 8. 性能与滚动基准
- **禁止「滚动页里嵌限高滚动框」**：Flutter 不会把滚到头的滚动链式传给父级（内层注册在先就赢），光标停在内层上页面彻底滚不动（量法：`TestPointer(kind: trackpad)` + `pointer.scroll`）。「数据更新历」已改**折叠 4 条 + 展开全部**。以后长列表面板都按这个来。
- **课表页滚动卡顿（2026-10-24 修）**：`ListView.cacheExtent` 默认 250 → `scrollCacheExtent: ScrollCacheExtent.pixels(800)`（`material.dart` 不导出，需 `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`）；`buildKeywordSpans` 按 `(content, isDark, tiered, baseStyle)` 缓存 256 条 FIFO；更新历改 `Stack`+`Positioned` 拉伸。
- 基准跑法：`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/scroll_perf_test.dart -d macos --profile`，结果写 `build/integration_response_data.json`（微秒）。判断线：build/rasterizer 平均 >16.7ms 必掉帧。**回归先看「build 超预算帧数」是否为 0**。

## 9. 待办页（todo）
- 目录 `lib/features/todo/`：`todo_page.dart`(页面) + `todo_model.dart`(TodoItem/TodoCategory/TodoSource) + `todo_storage.dart`(TodoStorage/TodoStore/FileTodoStorage/MemoryTodoStorage)；远端源 `lib/core/todo_repository.dart`(NetworkTodoRemoteSource + parseTodoHtml)。
- **自动拉取**：打开即拉取博客《待办清单》`https://yiyu14.top/posts/todo/`（回退 raw.githubusercontent.com / cdn.jsdelivr.net 的 `src/content/posts/todo.md`，都含 `.todo-root` HTML；**新增依赖 `html ^0.15.4`**），解析成远端项（data-todo-id / 标题 / 分组→分类 / .todo-status 截止 / .todo-note 备注 / .todo-subhead 子标题上下文）。**不另建 JSON、不碰博客仓库**。
- **版本管理合并**：远端决定「有哪些任务 + 标题/分类/截止/备注」；本地保留 ①完成状态 ②自建项(source=local) ③对远端项的删除(墓碑 `deletedRemoteIds`)。本地自建项原样保留；远端项按 `remoteId` 刷新内容、保留 done；远端已移除丢弃；墓碑项不再复活。编辑远端项转本地自建以免被覆盖。远端无「完成态」概念（纯本地）。
- **布局（2026-10-26 重写对齐网页 Firefly）**：按分类分组（淡主色容器 + 主色左边线组标题，去掉卡片与分类 chip）、`TodoCheckCircle` 圆形成勾选框、顶部进度条 + `SegmentedButton` 筛选 + 同步状态/手动刷新、截止日胶囊徽标、备注左边线、滑动删除。FAB 仍在 body 内 `Positioned`（非 Scaffold FAB）。头部 `InkWell` 需 `Material` 祖先——`_TodoTile` 用 `Material(type: transparency)` 包裹。
- 排序：未完成在前、有截止日(dueDate 或标签解析日期)靠前、再按 createdAt。id=时间戳+自增；远端项 id=`remote-<data-todo-id>`。
- 测试：`test/todo_page_test.dart`(注入 MemoryTodoStorage/FakeRemote) + `test/todo_repository_test.dart`(解析器)。全量 140 项测试全绿。
- 待定：备注长文是否接 keyword_highlight（当前未接）。
