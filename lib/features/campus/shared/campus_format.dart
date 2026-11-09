// 时间与金额的展示格式。所有对外文案集中在这里，避免各页面自己拼。

/// 金额：分 → `¥12.50`。全链路只在这里做一次除法。
String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final value = cents.abs();
  return '$sign¥${(value / 100).toStringAsFixed(2)}';
}

/// 元 → 分。用户输入「12.5」得到 1250。
int yuanToCents(String input) {
  final parsed = double.tryParse(input.trim());
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0;
  return (parsed * 100).round();
}

/// 分 → 元，用于编辑框回填。
String centsToYuan(int cents) => (cents / 100).toStringAsFixed(2);

String _two(int v) => v.toString().padLeft(2, '0');

/// `11月9日 19:30`
String formatDateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.month}月${local.day}日 ${_two(local.hour)}:${_two(local.minute)}';
}

/// `19:30`
String formatTime(DateTime time) {
  final local = time.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// `2026-11-09`
String formatDate(DateTime time) {
  final local = time.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}

/// 相对时间：刚刚 / 5 分钟前 / 3 小时前 / 昨天 / 11月9日
String formatRelative(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.isNegative) return '刚刚';
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 2) return '昨天';

  final local = time.toLocal();
  if (local.year == DateTime.now().year) {
    return '${local.month}月${local.day}日';
  }
  return '${local.year}年${local.month}月${local.day}日';
}

/// 截止倒计时：`3 小时后截止` / `还剩 12 分钟` / `已截止`
String formatDeadline(DateTime deadline) {
  final diff = deadline.toLocal().difference(DateTime.now());
  if (diff.isNegative) return '已截止';
  if (diff.inMinutes < 1) return '即将截止';
  if (diff.inHours < 1) return '还剩 ${diff.inMinutes} 分钟';
  if (diff.inDays < 1) return '还剩 ${diff.inHours} 小时';
  return '还剩 ${diff.inDays} 天';
}

bool isPast(DateTime time) => time.toLocal().isBefore(DateTime.now());
