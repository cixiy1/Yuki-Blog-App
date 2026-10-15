import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.settings_outlined,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '设置',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
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
