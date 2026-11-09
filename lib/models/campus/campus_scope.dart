/// 内容的可见范围。二手 / 失物默认全校，活动 / 表单 / 跑腿默认本班。
enum VisibilityScope {
  classOnly('仅本班'),
  schoolWide('全校可见');

  const VisibilityScope(this.label);

  final String label;
}
