import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:yuki_blog_app/app/routes/route_paths.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/core/campus/permissions.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/campus/shared/role_badge.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';

/// 设置页：应用信息、账号与常规操作。
class SettingPage extends StatefulWidget {
  const SettingPage({super.key, this.services});

  /// 校园服务门面；为 null 时用全局实例（测试可注入假实现）。
  final CampusServices? services;

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _checking = false;

  /// 当前安装版本，形如 `1.4.12`（读的是系统里的实际值，不是写死的常量）。
  String? _version;

  /// 是否已经读过一次版本（区分「读取中」与「读不到」）。
  bool _versionReady = false;

  CampusServices? get _services =>
      widget.services ?? (CampusServices.isReady ? CampusServices.instance : null);

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    String? version;
    try {
      // 只显示版本名（`1.4.12`），不带内部 buildNumber：versionCode 现在是
      // epoch 天数（自动生成），拼出来只会是 `1.4.12+20636` 这种噪音。
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {
      version = null; // 取不到就不显示，不因此报错
    }
    if (!mounted) return;
    setState(() {
      _version = version;
      _versionReady = true;
    });
  }

  Future<void> _copyVersion() async {
    final version = _version;
    if (version == null) return;
    await Clipboard.setData(ClipboardData(text: version));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制版本号 $version'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    AppRelease? release;
    try {
      release = await UpdateService().checkForUpdate();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    await showUpdateDialog(context, release: release, manual: true);
  }

  Future<void> _logout() async {
    final services = _services;
    if (services == null) return;
    await services.auth.logout();
    await services.session.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退出登录')),
    );
  }

  Future<void> _resetDemoData() async {
    final services = _services;
    if (services == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置演示数据'),
        content: const Text(
          '会清空本地全部校园服务数据并重新灌入示例内容，当前账号也会退出登录。'
          '这个操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await services.resetDemoData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('演示数据已重置，请重新登录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '设置',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            _accountCard(context),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('当前版本'),
                subtitle: Text(
                  !_versionReady ? '读取中…' : (_version ?? '未知'),
                ),
                trailing: _version == null
                    ? null
                    : const Icon(Icons.copy_rounded, size: 18),
                onTap: _version == null ? null : _copyVersion,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: _checking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.system_update_alt),
                title: const Text('检查更新'),
                subtitle: const Text('从 GitHub Releases 获取最新版本，可应用内下载安装'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _checking ? null : _checkUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context) {
    final services = _services;
    if (services == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: services.session,
      builder: (context, _) {
        final user = services.session.user;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        if (user == null) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.login_rounded, color: scheme.primary),
              title: const Text('未登录'),
              subtitle: const Text('登录后可发布失物、二手、跑腿与活动'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.login),
            ),
          );
        }

        final isAdmin = can(user.role, Capability.resetDemoData);
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    user.avatarLetter,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    RoleBadge(role: user.role),
                  ],
                ),
                subtitle: Text(
                  '${user.studentId} · ${user.className} · 信用 ${user.creditScore}',
                ),
                trailing: TextButton(
                  onPressed: _logout,
                  child: const Text('退出'),
                ),
              ),
              if (isAdmin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
                  title: const Text('重置演示数据'),
                  subtitle: const Text('清空本地库并重新灌入示例内容'),
                  onTap: _resetDemoData,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
