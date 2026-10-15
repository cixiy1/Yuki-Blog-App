import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/network_timetable_repository.dart';
import 'package:yuki_blog_app/core/timetable_repository.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/models/timetable.dart';
import 'package:yuki_blog_app/features/schedule/widgets/changelog_panel.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_detail_panel.dart';
import 'package:yuki_blog_app/features/schedule/widgets/notices_panel.dart';
import 'package:yuki_blog_app/features/schedule/widgets/timetable_grid.dart';
import 'package:yuki_blog_app/features/schedule/widgets/timetable_legend.dart';
import 'package:yuki_blog_app/features/schedule/widgets/week_bar.dart';
import 'package:yuki_blog_app/features/schedule/widgets/week_changes_panel.dart';

/// 动态课程表页。
///
/// 数据通过 [TimetableRepository] 接口获取（默认网络同步源：
/// 优先拉取博客线上最新课表，离线自动回退本地 asset），
/// UI 只消费解析后的网格数据；换数据源不用改这个页面。
class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    this.repository,
  });

  final TimetableRepository? repository;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Future<TimetableData> _future;
  SyncTimetableRepository? _ownedRepository;

  /// 未注入数据源时创建默认网络同步源，随页面销毁释放底层连接。
  TimetableRepository get _effectiveRepository =>
      widget.repository ?? (_ownedRepository ??= SyncTimetableRepository());

  @override
  void initState() {
    super.initState();
    _future = _effectiveRepository.loadTimetable();
  }

  void _retry() {
    setState(() {
      _future = _effectiveRepository.loadTimetable();
    });
  }

  @override
  void dispose() {
    _ownedRepository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<TimetableData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ScheduleError(onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ScheduleBody(data: snapshot.data!);
        },
      ),
    );
  }
}

class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({required this.data});

  final TimetableData data;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends State<_ScheduleBody> {
  late TimetableResolver _resolver;
  late int _realWeek;
  late int _viewWeek;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _resolver = TimetableResolver(widget.data);
    _realWeek = _resolver.currentWeek();
    _viewWeek = _realWeek;
  }

  @override
  void didUpdateWidget(_ScheduleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resolver = TimetableResolver(widget.data);
      _realWeek = _resolver.currentWeek();
      _viewWeek = _realWeek;
      _selectedKey = null;
    }
  }

  void _selectEntry(ResolvedEntry entry) {
    setState(() {
      _selectedKey = _selectedKey == entry.key ? null : entry.key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = widget.data.meta;
    final schedule = _resolver.resolve(_viewWeek);
    final notices = _resolver.visibleNotices(_realWeek);
    final monday = _resolver.mondayOf(_viewWeek);
    final sunday = _resolver.sundayOf(_viewWeek);

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayInViewWeek =
        !todayDate.isBefore(monday) && !todayDate.isAfter(sunday);
    final todayWeekday = todayInViewWeek ? today.weekday : -1;

    ResolvedEntry? selected;
    if (_selectedKey != null) {
      for (final e in schedule.entries) {
        if (e.key == _selectedKey) {
          selected = e;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingXl,
      ),
      children: [
        _ScheduleHeader(meta: meta),
        const SizedBox(height: AppTheme.spacingMd),
        WeekBar(
          week: _viewWeek,
          totalWeeks: meta.totalWeeks,
          currentWeek: _realWeek,
          weekMonday: monday,
          weekSunday: sunday,
          onPrev: () => setState(() => _viewWeek = (_viewWeek - 1).clamp(1, meta.totalWeeks).toInt()),
          onNext: () => setState(() => _viewWeek = (_viewWeek + 1).clamp(1, meta.totalWeeks).toInt()),
          onToday: () => setState(() => _viewWeek = _realWeek),
          onPickWeek: () => showWeekPicker(
            context,
            week: _viewWeek,
            totalWeeks: meta.totalWeeks,
            currentWeek: _realWeek,
            week1Monday: meta.week1Monday,
            onPick: (w) => setState(() => _viewWeek = w),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        NoticesPanel(notices: notices),
        if (!schedule.hasClass) _NoClassBanner(week: _viewWeek),
        TimetableGrid(
          schedule: schedule,
          weekMonday: monday,
          todayWeekday: todayWeekday,
          selectedKey: _selectedKey,
          onSelectEntry: _selectEntry,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        const TimetableLegend(),
        if (selected != null) ...[
          const SizedBox(height: AppTheme.spacingMd),
          CourseDetailPanel(
            entry: selected,
            onClose: () => setState(() => _selectedKey = null),
          ),
        ],
        if (schedule.changes.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMd),
          WeekChangesPanel(changes: schedule.changes),
        ],
        const SizedBox(height: AppTheme.spacingMd),
        ChangelogPanel(meta: meta),
        const SizedBox(height: AppTheme.spacingLg),
        Center(
          child: Text(
            '最近更新于 ${meta.updated} · 周次基准 ${_formatDate(meta.week1Monday)}',
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({required this.meta});

  final TimetableMeta meta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(Icons.calendar_month,
              size: 20, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meta.className} · 动态课程表',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${meta.term} · ${meta.campus}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoClassBanner extends StatelessWidget {
  const _NoClassBanner({required this.week});

  final int week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            '第 $week 周无课安排（放假 / 实践周）',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              '课表数据加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              '请检查本地数据文件后重试',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
