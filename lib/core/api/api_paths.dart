/// 全部后端端点。repository 与 Mock 路由表共用同一份常量，
/// 杜绝两边字符串写岔。
class ApiPaths {
  ApiPaths._();

  // ── 认证 / 用户 ────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  static const String users = '/users';
  static String user(String id) => '$users/$id';

  // ── 媒体 ──────────────────────────────────────────────────
  static const String media = '/media';
  static String mediaOne(String id) => '$media/$id';

  // ── 门户 ──────────────────────────────────────────────────
  static const String portalSummary = '/portal/summary';

  // ── 失物招领 ──────────────────────────────────────────────
  static const String lostFound = '/lost-found';
  static String lostFoundOne(String id) => '$lostFound/$id';
  static String lostFoundClose(String id) => '$lostFound/$id/close';

  // ── 二手闲置 ──────────────────────────────────────────────
  static const String market = '/market';
  static String marketOne(String id) => '$market/$id';
  static String marketSold(String id) => '$market/$id/sold';

  // ── 快递代取 ──────────────────────────────────────────────
  static const String express = '/express';
  static String expressOne(String id) => '$express/$id';
  static String expressAccept(String id) => '$express/$id/accept';
  static String expressDeliver(String id) => '$express/$id/deliver';
  static String expressComplete(String id) => '$express/$id/complete';
  static String expressCancel(String id) => '$express/$id/cancel';

  // ── 活动报名 ──────────────────────────────────────────────
  static const String activities = '/activities';
  static const String activitiesPendingReview = '/activities/pending-review';
  static String activityOne(String id) => '$activities/$id';
  static String activityReview(String id) => '$activities/$id/review';
  static String activitySignup(String id) => '$activities/$id/signup';
  static String activityCancelSignup(String id) =>
      '$activities/$id/cancel-signup';
  static String activitySignups(String id) => '$activities/$id/signups';
  static String activityCancel(String id) => '$activities/$id/cancel';

  // ── 表单收集 ──────────────────────────────────────────────
  static const String forms = '/forms';
  static String formOne(String id) => '$forms/$id';
  static String formClose(String id) => '$forms/$id/close';
  static String formSubmissions(String id) => '$forms/$id/submissions';
  static String formRemind(String id) => '$forms/$id/remind';

  // ── 代买跑腿 ──────────────────────────────────────────────
  static const String purchases = '/purchases';
  static String purchaseOne(String id) => '$purchases/$id';
  static String purchaseAccept(String id) => '$purchases/$id/accept';
  static String purchaseDeliver(String id) => '$purchases/$id/deliver';
  static String purchaseComplete(String id) => '$purchases/$id/complete';
  static String purchaseCancel(String id) => '$purchases/$id/cancel';
  static String purchaseReviews(String id) => '$purchases/$id/reviews';

  // ── 消息 ──────────────────────────────────────────────────
  static const String messages = '/messages';
  static const String messagesUnreadCount = '/messages/unread-count';
  static const String messagesReadAll = '/messages/read-all';
  static String messageRead(String id) => '$messages/$id/read';
}
