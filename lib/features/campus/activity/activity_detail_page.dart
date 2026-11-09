import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/permissions.dart';
import '../../../models/campus/campus_activity.dart';
import '../shared/campus_format.dart';
import '../shared/campus_gallery.dart';
import '../shared/campus_sub_page.dart';
import '../shared/section_header.dart';
import '../shared/status_chip.dart';
import 'activity_editor_page.dart';
import 'activity_signups_page.dart';

/// 活动详情。报名 / 取消 / 审核 / 编辑都在这一页收口。
class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.services,
    required this.activity,
  });

  final CampusServices services;
  final CampusActivity activity;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late CampusActivity _activity = widget.activity;
  bool _busy = false;
  bool _changed = false;

  bool get _isAdmin =>
      can(widget.services.session.user?.role, Capability.reviewActivity);

  bool get _canViewSignups =>
      _activity.isMine ||
      can(widget.services.session.user?.role, Capability.viewSignupList);

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _reload() async {
    try {
      final fresh = await widget.services.activities.detail(_activity.id);
      if (!mounted) return;
      setState(() {
        _activity = fresh;
        _changed = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _signup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.services.activities.signup(_activity.id);
      if (!mounted) return;
      setState(() {
        _activity = updated;
        _changed = true;
      });
      _toast(updated.mySignup?.status == SignupStatus.waitlisted
          ? '名额已满，已排到候补第 ${updated.mySignup?.queuePosition} 位'
          : '报名成功');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSignup() async {
    if (_busy) return;
    final confirmed = await _confirm(
      title: '退出这个活动？',
      message: _activity.mySignup?.status == SignupStatus.confirmed
          ? '你退出后，候补第一位的同学会自动补上。'
          : '退出后要重新排候补。',
      confirmLabel: '退出',
      confirmKey: const Key('ac-cancel-signup-confirm'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated =
          await widget.services.activities.cancelSignup(_activity.id);
      if (!mounted) return;
      setState(() {
        _activity = updated;
        _changed = true;
      });
      _toast('已退出');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final confirmed = await _confirm(
      title: '通过这个活动？',
      message: '通过后符合可见范围的同学就能报名了。',
      confirmLabel: '通过',
      confirmKey: const Key('ac-approve-confirm'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated =
          await widget.services.activities.review(_activity.id, approve: true);
      if (!mounted) return;
      setState(() {
        _activity = updated;
        _changed = true;
      });
      _toast('已通过，同学可以报名了');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await widget.services.activities
          .review(_activity.id, approve: false, reason: reason);
      if (!mounted) return;
      setState(() {
        _activity = updated;
        _changed = true;
      });
      _toast('已驳回并通知发起人');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityEditorPage(
          services: widget.services,
          existing: _activity,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _cancelActivity() async {
    final confirmed = await _confirm(
      title: '取消这个活动？',
      message: '已报名和候补的同学都会收到通知，名单会清空。',
      confirmLabel: '取消活动',
      confirmKey: const Key('ac-cancel-activity-confirm'),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await widget.services.activities.cancel(_activity.id);
      if (!mounted) return;
      setState(() {
        _activity = updated;
        _changed = true;
      });
      _toast('活动已取消');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Key? confirmKey,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('不了'),
            ),
            TextButton(
              key: confirmKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  void _openSignups() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivitySignupsPage(
          services: widget.services,
          activity: _activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: CampusSubPage(
        title: '活动详情',
        bottomNavigationBar: _actionBar(),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        bottom: AppTheme.spacingXl,
      ),
      children: [
        if (_activity.imageIds.isNotEmpty)
          CampusGallery(
            imageIds: _activity.imageIds,
            media: widget.services.media,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _activity.title,
                      key: const Key('ac-detail-title'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  StatusChip(
                    label: _activity.status.label,
                    color: _statusColor(scheme),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              _meta(Icons.schedule_rounded, _timeRange()),
              _meta(Icons.place_outlined, _activity.location),
              _meta(Icons.how_to_reg_outlined,
                  '报名${formatDeadline(_activity.signupDeadline)}（${formatDateTime(_activity.signupDeadline)}）'),
              _meta(Icons.person_outline, '发起人 ${_activity.organizerName}'),
              if (_activity.status == ActivityStatus.rejected &&
                  (_activity.rejectReason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: scheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '驳回原因：${_activity.rejectReason}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingMd),
              _capacityCard(context),
              const SizedBox(height: AppTheme.spacingMd),
              SectionHeader(title: '活动说明'),
              Text(
                _activity.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              if (_canViewSignups) ...[
                const SizedBox(height: AppTheme.spacingMd),
                Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: InkWell(
                    key: const Key('ac-signups-entry'),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    onTap: _openSignups,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              '报名名单（${_activity.confirmedCount} 人'
                              '${_activity.waitlistCount > 0 ? '，候补 ${_activity.waitlistCount} 人' : ''}）',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(ColorScheme scheme) => switch (_activity.status) {
        ActivityStatus.approved => scheme.primary,
        ActivityStatus.pendingReview => scheme.tertiary,
        ActivityStatus.rejected => scheme.error,
        ActivityStatus.cancelled || ActivityStatus.finished => scheme.outline,
      };

  String _timeRange() {
    final start = formatDateTime(_activity.startAt);
    final end = _activity.endAt;
    if (end == null) return start;
    return '$start — ${formatTime(end)}';
  }

  Widget _meta(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _capacityCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = _activity.mySignup;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '已报名 ${_activity.confirmedCount} / ${_activity.capacity}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_activity.waitlistCount > 0)
                Text(
                  '候补 ${_activity.waitlistCount} 人',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.tertiary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _activity.fillRatio,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: _activity.isFull ? scheme.error : scheme.primary,
            ),
          ),
          if (mine != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                StatusChip(
                  label: mine.status == SignupStatus.confirmed
                      ? '你已报名'
                      : '你在候补第 ${mine.queuePosition ?? '-'} 位',
                  color: mine.status == SignupStatus.confirmed
                      ? scheme.primary
                      : scheme.tertiary,
                  icon: Icons.person_outline,
                ),
                if (mine.promotedAt != null) ...[
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    '候补递补成功',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.primary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ] else if (_activity.isFull &&
              _activity.status == ActivityStatus.approved) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              '名额已满，现在报名会排进候补，有人退出就自动补上。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _actionBar() {
    final status = _activity.status;
    final mine = _activity.mySignup;

    final children = <Widget>[];

    if (_isAdmin && status == ActivityStatus.pendingReview) {
      children.addAll([
        Expanded(
          child: OutlinedButton(
            key: const Key('ac-reject'),
            onPressed: _busy ? null : _reject,
            child: const Text('驳回'),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            key: const Key('ac-approve'),
            onPressed: _busy ? null : _approve,
            child: const Text('通过审核'),
          ),
        ),
      ]);
    } else if (_activity.isMine &&
        (status == ActivityStatus.pendingReview ||
            status == ActivityStatus.approved)) {
      children.addAll([
        Expanded(
          child: OutlinedButton(
            key: const Key('ac-edit'),
            onPressed: _busy ? null : _edit,
            child: const Text('编辑'),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            key: const Key('ac-cancel-activity'),
            onPressed: _busy ? null : _cancelActivity,
            child: const Text('取消活动'),
          ),
        ),
      ]);
    } else if (!_activity.isMine && status == ActivityStatus.approved) {
      if (mine != null) {
        children.add(
          Expanded(
            child: OutlinedButton(
              key: const Key('ac-cancel-signup'),
              onPressed: _busy ? null : _cancelSignup,
              child: const Text('取消报名'),
            ),
          ),
        );
      } else {
        children.add(
          Expanded(
            child: ElevatedButton(
              key: const Key('ac-signup'),
              onPressed: _busy ? null : _signup,
              child: Text(_activity.isFull ? '加入候补' : '报名'),
            ),
          ),
        );
      }
    }

    if (children.isEmpty) return null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingSm,
        ),
        child: Row(children: children),
      ),
    );
  }
}

/// 驳回必须写原因，所以单独一个弹窗。
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = '写一句原因，发起人才知道怎么改');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('驳回活动'),
      content: TextField(
        key: const Key('ac-reject-reason'),
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: '驳回原因',
          hintText: '如「场地与课程冲突」',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('ac-reject-submit'),
          onPressed: _submit,
          child: const Text('驳回'),
        ),
      ],
    );
  }
}
