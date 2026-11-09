import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/campus_activity.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import '../shared/status_chip.dart';

/// 报名名单：已报名在前，候补按位次跟在后面。
class ActivitySignupsPage extends StatefulWidget {
  const ActivitySignupsPage({
    super.key,
    required this.services,
    required this.activity,
  });

  final CampusServices services;
  final CampusActivity activity;

  @override
  State<ActivitySignupsPage> createState() => _ActivitySignupsPageState();
}

class _ActivitySignupsPageState extends State<ActivitySignupsPage> {
  List<ActivitySignup> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.services.activities.signups(widget.activity.id);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '报名名单',
      padBodyTop: true,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '看不到名单',
            message: _error,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.group_outlined,
            title: '还没人报名',
            message: '名单会随报名实时更新',
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final confirmed = _items.where((s) => s.status == SignupStatus.confirmed);
    final waitlisted = _items.where((s) => s.status == SignupStatus.waitlisted);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingXl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '已报名 ${confirmed.length} / ${widget.activity.capacity}'
            '${waitlisted.isEmpty ? '' : '，候补 ${waitlisted.length} 人'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          for (final signup in _items) _row(signup),
        ],
      ),
    );
  }

  Widget _row(ActivitySignup signup) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isConfirmed = signup.status == SignupStatus.confirmed;
    final letter = signup.userName.isEmpty
        ? '?'
        : String.fromCharCode(signup.userName.runes.first);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signup.userName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  signup.className,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(
                label: isConfirmed
                    ? '已报名'
                    : '候补第 ${signup.queuePosition ?? '-'} 位',
                color: isConfirmed ? scheme.primary : scheme.tertiary,
              ),
              const SizedBox(height: 2),
              Text(
                formatRelative(signup.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
