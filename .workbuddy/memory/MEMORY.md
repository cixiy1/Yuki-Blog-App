
## 项目约定
- App 名：仓库/工程名 **Yuki-Blog App**，应用显示名 **Yuki Blog**（全英文显示），Dart 包名 yuki_blog_app，应用 ID com.yiyu14.yuki_blog_app；GitHub 仓库 cixiy1/Yuki-Blog-App（公开）。
- 发版流程：改 pubspec version → Conventional Commits 提交推送 → `git tag vX.Y.Z && git push origin vX.Y.Z`，GitHub Actions 自动测试+构建 APK 并发 Release；App 内更新弹窗读该 Release。
- 各平台标识四处必须同步：android namespace/applicationId/源码包目录/Manifest，iOS/macOS 的 `PRODUCT_BUNDLE_IDENTIFIER`、`PRODUCT_NAME` 与产物引用（macOS `AppInfo.xcconfig` 决定 PRODUCT_NAME，pbxproj 的 `TEST_HOST` 与 xcscheme 的 `BuildableName` 要跟着改），web `manifest.json`/`index.html`。
- 命名铁律：不要中英文夹杂，要么全英要么全中。
- **联动维护义务**：每次为本项目（Yuki-Blog App）开发出实质性功能/里程碑时，必须同步维护博客 yiyu14.top 的「项目展示页」条目及对应的 .md 文档（维护流程见 skill: firefly-projects-page）。新增功能、改名、上线等节点都要检查博客展示项是否需要更新。
- **Git 日志维护**：每个实质性开发节点（新功能 / 修复 / 重构 / 改名）都要及时单独提交，用 Conventional Commits 规范（feat/fix/docs/chore...），不要攒一堆改动混成一个提交；完成即推送 GitHub（cixiy1/Yuki-Blog-App）。
