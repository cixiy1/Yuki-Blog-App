import 'package:flutter/material.dart';

import 'package:yuki_blog_app/core/apk_downloader.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/update/apk_installer.dart';
import 'package:yuki_blog_app/features/update/release_launcher.dart';

/// 下载函数签名，方便测试注入替身。
typedef ApkDownloadFn = Future<String> Function(
  String url, {
  required String fileName,
  void Function(DownloadProgress progress)? onProgress,
  DownloadCancelToken? cancelToken,
});

/// 唤起系统安装器的函数签名，方便测试注入替身。
typedef ApkInstallFn = Future<InstallOutcome> Function(String apkPath);

/// 应用内下载更新包：带进度条，下载完成后直接唤起系统安装器。
///
/// 失败（网络异常 / 系统未授权安装）时留在弹窗里给出重试与「浏览器下载」出路，
/// 不把用户丢在一个没有下一步的错误提示上。
Future<void> showDownloadProgressDialog(
  BuildContext context, {
  required AppRelease release,
  ApkDownloadFn download = downloadToFile,
  ApkInstallFn install = launchApkInstaller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _DownloadDialog(release: release, download: download, install: install),
  );
}

enum _Phase { downloading, installing, failed }

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({
    required this.release,
    required this.download,
    required this.install,
  });

  final AppRelease release;
  final ApkDownloadFn download;
  final ApkInstallFn install;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  _Phase _phase = _Phase.downloading;
  DownloadProgress? _progress;
  String? _error;

  /// 系统未授权「安装未知应用」导致的失败（不该给「重试」，要给「浏览器下载」）。
  bool _needPermission = false;

  DownloadCancelToken? _token;
  DateTime? _sampleAt;
  int _sampleBytes = 0;
  double? _speed;

  @override
  void initState() {
    super.initState();
    _start();
  }

  String get _fileName {
    final fromUrl = Uri.tryParse(widget.release.apkUrl)?.pathSegments;
    final last = (fromUrl == null || fromUrl.isEmpty) ? '' : fromUrl.last;
    if (last.toLowerCase().endsWith('.apk')) return last;
    return 'yuki-blog-${widget.release.tagName}.apk';
  }

  Future<void> _start() async {
    final token = DownloadCancelToken();
    _token = token;
    _progress = null;
    _error = null;
    _needPermission = false;
    _sampleAt = null;
    _sampleBytes = 0;
    _speed = null;
    // 首次进入时本 state 还没 build 过，直接改字段即可；「重试」才需要 setState。
    if (_phase != _Phase.downloading && mounted) {
      setState(() => _phase = _Phase.downloading);
    }

    final String path;
    try {
      path = await widget.download(
        widget.release.apkUrl,
        fileName: _fileName,
        onProgress: _onProgress,
        cancelToken: token,
      );
    } on DownloadCancelledException {
      if (mounted) Navigator.of(context).pop();
      return;
    } on DownloadException catch (e) {
      if (mounted) setState(() => _fail(e.message));
      return;
    } catch (e) {
      if (mounted) setState(() => _fail('下载失败：$e'));
      return;
    }

    if (!mounted) return;
    setState(() => _phase = _Phase.installing);

    final outcome = await widget.install(path);
    if (!mounted) return;
    switch (outcome) {
      case InstallOutcome.launched:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('已唤起系统安装程序，按提示完成安装')),
        );
      case InstallOutcome.permissionDenied:
        setState(() => _fail(
              '系统未允许本应用安装应用。请在系统设置里允许「Yuki Blog」安装应用后，'
              '用浏览器下载路径重试，或直接安装已下载的安装包。',
              needPermission: true,
            ));
      case InstallOutcome.unsupported:
      case InstallOutcome.failed:
        setState(() => _fail('安装包已下载，但无法唤起系统安装程序。'));
    }
  }

  void _fail(String message, {bool needPermission = false}) {
    _phase = _Phase.failed;
    _error = message;
    _needPermission = needPermission;
  }

  /// 每收到一段数据回调一次；按 200ms 节流后再刷新界面
  /// （几十 MB 的包没必要每个数据块都重建一次）。
  void _onProgress(DownloadProgress p) {
    final now = DateTime.now();
    final last = _sampleAt;
    final complete = p.hasTotal && p.received >= p.total;
    if (last != null && !complete && now.difference(last).inMilliseconds < 200) {
      _progress = p;
      return;
    }
    if (last != null) {
      final seconds = now.difference(last).inMilliseconds / 1000;
      if (seconds > 0) {
        final instant = (p.received - _sampleBytes) / seconds;
        _speed = _speed == null ? instant : _speed! * 0.6 + instant * 0.4;
      }
    }
    _sampleAt = now;
    _sampleBytes = p.received;
    if (!mounted) {
      _progress = p;
      return;
    }
    setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progress;
    final fraction = progress?.fraction;
    final downloading = _phase == _Phase.downloading;

    return PopScope(
      canPop: !downloading,
      child: AlertDialog(
        icon: Icon(
          _phase == _Phase.failed
              ? Icons.error_outline
              : Icons.system_update_alt,
        ),
        title: Text(
          switch (_phase) {
            _Phase.downloading => '正在下载 ${widget.release.tagName}',
            _Phase.installing => '下载完成',
            _Phase.failed => '下载失败',
          },
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_phase == _Phase.failed)
                Text(
                  _error ?? '下载失败',
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: scheme.error),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _phase == _Phase.installing ? 1 : fraction,
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _phase == _Phase.installing
                            ? '正在唤起系统安装程序…'
                            : _progressLine(progress, fraction),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (downloading && fraction != null)
                      Text(
                        '${(fraction * 100).floor()}%',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                downloading
                    ? '安装包来自 GitHub Releases，下载完成后会直接打开系统安装界面。'
                    : '安装包来自 GitHub Releases。',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: _actions(context, downloading),
      ),
    );
  }

  String _progressLine(DownloadProgress? p, double? fraction) {
    if (p == null) return '准备中…';
    final received = formatBytes(p.received);
    if (!p.hasTotal) return '已下载 $received';
    final line = '$received / ${formatBytes(p.total)}';
    final speed = _speed;
    if (speed != null && speed > 0) {
      final left = p.total - p.received;
      final eta = formatDuration((left / speed).round());
      return '$line · ${formatBytes(speed.round())}/s${eta.isEmpty ? '' : ' · 剩余 $eta'}';
    }
    return line;
  }

  List<Widget> _actions(BuildContext context, bool downloading) {
    if (downloading) {
      return [
        TextButton(
          onPressed: () => _token?.cancel(),
          child: const Text('取消'),
        ),
      ];
    }
    if (_phase == _Phase.installing) return const [];
    return [
      if (!_needPermission)
        TextButton(
          onPressed: _start,
          child: const Text('重试'),
        ),
      TextButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          navigator.pop();
          if (!await launchReleaseDownload(widget.release)) {
            messenger.showSnackBar(
              const SnackBar(content: Text('无法打开浏览器，请手动访问 GitHub Releases')),
            );
          }
        },
        child: const Text('浏览器下载'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
    ];
  }
}

/// 字节数转可读文本，如 `48.8 MB`。
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// 秒数转 `1 分 20 秒` / `45 秒`；不可用时返回空串。
String formatDuration(int seconds) {
  if (seconds <= 0 || seconds > 24 * 3600) return '';
  if (seconds < 60) return '$seconds 秒';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return rest == 0 ? '$minutes 分' : '$minutes 分 $rest 秒';
}
