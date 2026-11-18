# Yuki-Blog App 项目记忆

## 1. 标识与发版
- 工程 **Yuki-Blog App**（显示名 Yuki Blog，全英），Dart 包 `yuki_blog_app`；仓库 `cixiy1/Yuki-Blog-App`（公开）。`/材料/` 已 gitignore，别 `git add -A`。
- 应用 ID：Android `com.yiyu14.yuki_blog_app`；iOS `com.yiyu14.yukiblogapp`；**macOS `com.yiyu14.yukiblogapp.mac`**（UTI 只允许字母数字连字符点）。改标识要同步：android namespace/applicationId/源码目录/Manifest；iOS `PRODUCT_BUNDLE_IDENTIFIER`+`PRODUCT_NAME`（连带 pbxproj `TEST_HOST`、xcscheme `BuildableName`）；macOS `AppInfo.xcconfig`+pbxproj RunnerTests；web `manifest.json`/`index.html`。别把 iOS/macOS 统一回下划线版。
- **macOS 与 iOS 不能同 id**：同 id 时 `open` 返回 1 → 窗口拉不起/纯黑。
- 发版：改 `pubspec.yaml` version → Conventional Commits 推送 → `git tag vX.Y.Z && git push origin vX.Y.Z` → Actions 发 Release（App 内更新弹窗读它）。
- 命名铁律：不要中英文夹杂。

## 2. 发布铁律（最高优先级）
**未经明确允许：不升版本号、不构建、不 `git push`、不打 tag、不触发上线（CI 发版 / 博客 push 上 Cloudflare）。** 默认只做「改代码 → `flutter analyze` + `flutter test` → 本地 commit」。升版本与构建都要授权（产可分发产物）；回退＝改回 version → `git commit --amend --no-edit`（未推送才可）→ 删产出包。判断推送失败看 `git status -sb | head -1` 有无 `[ahead N]`，别信 `git push | tail` 退出码。

## 3. 签名
**Android**：release 一律用 `android/key.properties` 的 keystore，**签名参数全由用户填写，我不得代拟任何口令/别名/证书信息**。模板 `key.properties.example`，脚本 `tool/gen_release_keystore.sh`、备份 `tool/make_signing_secrets.sh`。未配置回退 debug 签名（无法覆盖安装 → App 内更新失效）。已定参数勿改：`keyAlias=yuki-blog`、`dname=CN=Yukiho, O=Yukiho, C=CN`、36500 天、`storeFile=release.jks`；口令用户自持不落文档。证书 SHA-256 `91:40:6D:E2:74:3B:11:6E:92:86:5A:26:80:B5:D4:66:1D:FA:DB:ED:49:BF:6E:31:00:5F:D6:35:B5:6B:5B:E2`（核 `apksigner verify --print-certs`），备份 `~/Documents/Yuki/signing-2615/`。换签名＝用户全部卸载重装。

**iOS 真机**：Team `R4A23FHD6Y`（证书到 2027-10-24），pbxproj Runner 三 config 已写 `CODE_SIGN_STYLE=Automatic`+`DEVELOPMENT_TEAM`。装法：`flutter build ios --release` → `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` → `devicectl device process launch --device <udid> com.yiyu14.yukiblogapp`。UDID：iPhone 12 `00008101-001459AA0E46001E`、iPhone 11 Pro Max `00008030-00180C622208802E`（iOS 16+ 先开开发者模式）。
- iOS 14+ debug 版只能从 Flutter/Xcode 启动；`flutter run` 常卡「local network」（mDNS 5353），App 其实已装好，别当失败。
- `ProvisionedDevices` 只列已登记机型，**换机型必须重新 build**（`-allowProvisioningUpdates`）；免费 profile 7 天过期。
- **全 SPM，不装 CocoaPods**：`open_filex` 5.0.0 起带 `Package.swift`；已删 `ios/Podfile` 与 `ios/Flutter/*.xcconfig` 的 Pods include，别加回来。

## 4. 沉浸标题栏（公共组件）
`lib/widgets/immersive_app_bar.dart`（`ImmersiveGlassLayer`/`ImmersiveAppBar`/`immersiveProgressOf`/`kImmersive*`）+ `immersive_scaffold.dart`（抽屉/滚动监听/路由复位）。配方：贴顶全透明 → 滚过 **50px** → `card-bg 45%` + 整条 `blur(20px)` + 仅顶端高光阴影线，过渡 **360ms `Cubic(0.22,1,0.36,1)`**，进度**二值化**。
- ① 别用 `Scaffold.appBar`+`flexibleSpace` 承载铺满型内容（flexibleSpace 在 `OverflowBox(maxHeight: infinity)` 下 → `BackdropFilter` 撑到全屏、整页糊）。自实现 `PreferredSizeWidget`+`SizedBox(height: kToolbarHeight+状态栏)`。
- ② Web 不必关模糊（CanvasKit 裁剪正常）；整页糊真凶是 ①。
- ③ `extendBodyBehindAppBar: true` 时 Scaffold 会清 body 的 `MediaQuery.padding.top`，组件自己补回；写死 padding 的页面加 `MediaQuery.paddingOf(context).top`，根部 `SafeArea(top: false)`。
- ④ 模糊整条统一（一层 `BackdropFilter` σ=20 + 一层 45% surface 底），`ImmersiveGlassLayer` 是 Stateless，不需 `BackdropGroup`。**渐进模糊已废弃**（包 `BackdropFilter` 会引入 saveLayer 取不到样，接缝必然可见）。
- 左侧按钮顺序：`leading` > `onMenu` > 抽屉 > 返回键；开抽屉用 `GlobalKey<ScaffoldState>`，别在创建 Scaffold 的 context 上调 `Scaffold.of`。

## 5. 课表（双端同步）
App 与博客 yiyu14.top 各一套，改一处必须改两处：
1. 词表 `keyword_highlight.dart` `kwMap` ↔ `ClassSchedule.astro` `TT_KW_MAP`。
2. 解析与档位 `parseAnnotations + sentenceTierOf + buildKeywordSpans` ↔ `ttParseMarks + ttSentTierOf + hlLog`。
3. 面板顺序（2026-10-26 定稿）：网格 → 课程详情（选中才出现）→ 通知 → 本周调整 → 图例 → 更新历 → 页脚。**App 与网页版已不一致**，别对齐回去。
4. 数据 `assets/data/schedule-2615.json` ↔ 博客 `public/assets/data/schedule-2615.json`（`cp` 同步，sha256 同）。
5. 同格优先级：`ResolvedEntry.cellPriority` ↔ `render().cellRank`；**本周实际发生（有课/停课/新增）> 晚自习 > 非本周占位**，同级后者胜。
- **整周视图（2026-11-09）**：`TimetableGrid` 无横向滚动，7 列 `Expanded` 平分（周末留空列）；行标 `labelWidth` 30 只显示短节次号；表头两行（短星期 + M/d，今天 primary 胶囊，`_headerHeight` 32）。`CourseCell` 紧凑：课名 maxLines 4、字号 11/9/8.5、角标独立行；表头两行文字带 `height: 1.15` 否则胶囊溢出 3px。
- 滑动翻周：`GestureDetector(onHorizontalDragEnd)`（阈值 150）+ `AnimatedSwitcher`（280ms，`_slideDir` 定方向）；`_setWeek(week, direction:)` 是周条/选择器/手势统一入口，换周清空选中。
- 数据**网络优先（yiyu14.top）+ 打包资源兜底**；同步后写死数据量的断言要一起改。定位格子按 `entry.key`。
- playwright 验鼠标拖拽不可信（无动画不出帧，down+up 变点按）；**手势以 `tester.fling` 为准**（debugPrint 在浏览器 console，不在 flutter run stdout）。

## 6. 文字高亮（铁律）
- 重点不写死也不靠算法猜：新信息入库必须**先读内容再逐条标注**；词表只管配色，锚点算法只兜底未审阅内容。
- 语法（写在正文、渲染前剥离）：`{{…}}` 必看、`[[…]]` 关注、`((…))` 一般。整段出现过任何标注即视为已审阅（没标＝一般）；一个都没有才回退算法。括号不成对按原文保留，正文别出现裸 `{{`/`[[`/`((`。
- 范围：`meta.changelog.content` + `notices.text`。例外「本周调整」面板关掉定档（只留词表着色）：`buildKeywordSpans(..., tiered: false)` / `hlLog(c.txt, true)`。
- 凡「一段话」级信息型正文一律接这套；纯 UI 状态提示（离线提醒/无课横幅/图例）不接。
- 密度：底色只留「必看」、加粗只留「人工标注」；关键词只着色 + 同色划线。每条至多 1 处 `{{}}` + 1 处 `[[]]`；讲工具本身与历史条目一律 `(( ))`。

## 7. 本机环境与踩坑
- `flutter build apk` 会 unlink `~/it/flutter/flutter/bin/cache/engine.stamp.tmp.*`，沙箱以 `file-unlink` 拒绝 → **必须前台 + 脱离沙箱**。Flutter `/Users/yuki/it/flutter/flutter/bin/flutter`；Android SDK `/Users/yuki/it/andriodstudio/sdk`（`build-tools/36.0.0/apksigner`）。`flutter test` 需 `env -u HTTP_PROXY -u http_proxy -u HTTPS_PROXY -u HTTPS_proxy`。
- 代理间歇抽风（github `info/refs?service=git-receive-pack` 偶发 000）：先 `curl -o /dev/null -w "%{http_code}"` 探，再循环重试 push。
- `open_file_plus` 不可用（v1 `PluginRegistry.Registrar` 已被删）；`open_filex` 5.0.0 正常，别换回。
- 别手动删 Flutter SDK 的 `compileKotlin/classpath-snapshot` 再跑 `android/gradlew`（会用 JDK 27 重编 → `Unsupported class file major version 71`）；验证 Android 编译走 `flutter build apk`。
- `.widget_preview/` 写死绝对路径（项目搬过家）：`pubspec.yaml` 的 `dependency_overrides` path、`pubspec.lock`、`preview_manifest.json`、`lib/src/dtd/dtd_connection_info.dart`；改完删 `.dart_tool`/`build` 重跑 `flutter pub get --no-example`。override 键必须是包名 `yuki_blog_app`。该目录 gitignore。
- 截图回归：`RepaintBoundary.toImage` 在 fake async 里永久挂起，必须包 `tester.runAsync`。zsh `rm -f /tmp/x_*.png` 无匹配会 `no matches found` 中断命令链。

## 8. 性能与滚动基准
- **禁止「滚动页里嵌限高滚动框」**：滚动链不传父级，光标停内层上页面彻底滚不动（量法 `TestPointer(kind: trackpad)` + `pointer.scroll`）。「数据更新历」已改折叠 4 条 + 展开全部，长列表面板照此办。
- 课表页卡顿（2026-10-24 修）：`ListView.cacheExtent` 250→`scrollCacheExtent: ScrollCacheExtent.pixels(800)`（需 `import 'package:flutter/rendering.dart' show ScrollCacheExtent;`）；`buildKeywordSpans` 按 `(content,isDark,tiered,baseStyle)` 缓存 256 条 FIFO；更新历改 `Stack`+`Positioned`。
- 基准：`flutter drive --driver=test_driver/integration_test.dart --target=integration_test/scroll_perf_test.dart -d macos --profile` → `build/integration_response_data.json`（微秒）。build/rasterizer 均值 >16.7ms 必掉帧；**回归先看「build 超预算帧数」是否为 0**。

## 9. 待办页（todo）
- 文件：`lib/features/todo/` 下 `todo_page.dart`、`todo_model.dart`（TodoItem/TodoCategory/TodoSource）、`todo_storage.dart`（TodoStore/FileTodoStorage/MemoryTodoStorage）、`todo_trash_page.dart`（回收站）；远端源 `lib/core/todo_repository.dart`。
- **自动拉取**：打开即拉 `https://yiyu14.top/posts/todo/`（回退 raw.githubusercontent / jsDelivr 的 `src/content/posts/todo.md`），解析 `.todo-root`（data-todo-id / 标题 / 分组 / `.todo-status` 截止 / `.todo-note` / `.todo-subhead`）。**不另建 JSON、不碰博客仓库**（依赖 `html ^0.15.4`）。远端无「完成态」。
- **合并**：远端决定任务清单与标题/分类/截止/备注；本地保留 ①完成状态 ②自建项(source=local) ③回收站/墓碑。远端项按 `remoteId` 刷新、保留 done；远端已移除则丢弃；**回收站里的远端项冻结**（不刷新、远端删了也不动、先占用 id 防重复添加）；`deletedRemoteIds` 只在彻底删除时写；编辑远端项转本地自建。
- **删除＝软删除（2026-11-09）**：`TodoItem.deletedAt` 非空即进回收站；主列表/统计/进度/分组只算未删项。还原清 `deletedAt` 并顺手清墓碑（撤销优先）；彻底删除移除 + 记墓碑；清空回收站批量照做。删除后 SnackBar 可撤销（**无 Scaffold 时跳过**，否则 ScaffoldMessenger 断言失败、纯 pump 本页的测试会炸）。入口在头部 `Icons.restore_from_trash_outlined`+`Badge.count`——**不能用 delete_outline，会和条目删除按钮撞 finder**。
- **布局**：顶层按「人/组」(`group` ← `.todo-group-title`) 分块，组内按科目(`subject` ← `.todo-subhead`) 子区，无科目归「其他」；本地自建 `group` 为 null → `groupLabel` 回退分类默认名。`_PersonGroup`、`TodoCheckCircle`、进度条 + `SegmentedButton` 筛选、截止胶囊、备注左边线、滑动删除；FAB 在 body 内 `Positioned`；`_TodoTile` 需 `Material(type: transparency)` 才能用 InkWell。
- 排序：未完成在前、有截止日（dueDate 或标签解析日期）靠前、再按 createdAt。id=时间戳+自增；远端项 `remote-<data-todo-id>`。
- 测试：`test/todo_page_test.dart` + `todo_trash_test.dart` + `todo_repository_test.dart`（全量 158 项全绿）。待定：备注长文是否接 keyword_highlight（当前未接）。
