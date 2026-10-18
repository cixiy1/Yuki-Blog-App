import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';

/// 设置页：应用信息与常规操作。
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _checking = false;

  /// 当前安装版本，形如 `1.4.4+14`（读的是系统里的实际值，不是写死的常量）。
  String? _version;

  /// 是否已经读过一次版本（区分「读取中」与「读不到」）。
  bool _versionReady = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('当前版本'),
                subtitle: Text(
                  !_versionReady
                      ? '读取中…'
                      : (_version ?? '未知'),
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
}
