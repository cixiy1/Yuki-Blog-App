import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

/// 唤起系统安装器的结果。
enum InstallOutcome {
  /// 系统安装界面已打开。
  launched,

  /// 当前平台没有 APK 安装器（Web / iOS / 桌面）。
  unsupported,

  /// 系统未允许本应用安装应用（Android 8+ 的「未知来源」限制）。
  permissionDenied,

  /// 其它失败。
  failed,
}

/// 用系统安装器打开已下载的 APK（Android 通过 FileProvider 授予读权限）。
Future<InstallOutcome> launchApkInstaller(String apkPath) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return InstallOutcome.unsupported;
  }
  try {
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    switch (result.type) {
      case ResultType.done:
        return InstallOutcome.launched;
      case ResultType.permissionDenied:
        return InstallOutcome.permissionDenied;
      case ResultType.fileNotFound:
      case ResultType.noAppToOpen:
      case ResultType.error:
        return InstallOutcome.failed;
    }
  } catch (_) {
    return InstallOutcome.failed;
  }
}
