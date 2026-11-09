/// 信用分规则。
///
/// 初始 70，只受收到的评价影响，结果落在 0–100。故意做得平缓：
/// 一次一星掉的分，要靠两次五星才补得回来。这套规则同时写进
/// `mock_seed.dart` 的初始分与 `permissions` 之外的展示层，改之前想清楚。
library;

const int kInitialCredit = 70;

const Map<int, int> _deltas = {5: 2, 4: 1, 3: 0, 2: -2, 1: -4};

/// 一条评价带来的分数变化。星级超出 1–5 按边界算。
int creditDeltaFor(int stars) => _deltas[stars.clamp(1, 5)] ?? 0;

/// 把一条评价应用到当前信用分上。
int applyReviewToCredit(int current, int stars) =>
    (current + creditDeltaFor(stars)).clamp(0, 100);

/// 界面提示用：「五星 +2，二星 -2，一星 -4」这类文案集中在这里。
String describeCreditDelta(int stars) {
  final delta = creditDeltaFor(stars);
  if (delta == 0) return '不加减分';
  return delta > 0 ? '+$delta 分' : '$delta 分';
}
