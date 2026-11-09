import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
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
    // top: false —— 顶部让给沉浸标题栏：内容要能从它下面穿过去，
    // 滚动视口一旦被 SafeArea 压到标题栏下沿，就再也钻不进去了。
    // 首屏的避让改由下面 ListView 的 padding 负责（取 MediaQuery 里
    // ImmersiveScaffold 补进来的标题栏高度）。
    return SafeArea(
      top: false,
      child: FutureBuilder<TimetableData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ScheduleError(onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // 网络拉取失败回退到离线数据时，提醒用户数据可能过期
          final repo = _effectiveRepository;
          final stale =
              repo is SyncTimetableRepository && repo.usingFallback.value;
          return _ScheduleBody(data: snapshot.data!, stale: stale);
        },
      ),
    );
  }
}

class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({required this.data, required this.stale});

  final TimetableData data;

  /// true = 网络同步失败，当前为离线回退数据（可能不是最新）。
  final bool stale;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends State<_ScheduleBody>
    with TickerProviderStateMixin {
  late TimetableResolver _resolver;
  late int _realWeek;
  late int _viewWeek;

  String? _selectedKey;

  /// 周次解析缓存：跟手翻周时每一帧都要同时取本周与相邻周的数据，
  /// resolve 是纯计算但不便宜，按周 memo（换数据源时整体清空）。
  final Map<int, WeekSchedule> _scheduleCache = {};

  // —— 跟手翻周（PageView 式：内容跟手指位移，松手按速度/位移吸附）——

  /// 松手后的吸附动画：把 [_dragDx] 从松手值动画到 ±页宽（翻周）或 0（弹回）。
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// 当前水平位移（px）：左滑为负（露出下一周），右滑为正（露出上一周）。
  double _dragDx = 0;

  /// 拖拽/吸附过程中露出的相邻周；null = 没有相邻页（边界周或未拖动）。
  int? _neighborWeek;

  /// 吸附动画的位移插值（begin = 松手时位移，end = ±页宽或 0）。
  Tween<double>? _settleTween;

  /// 吸附结束时是否翻到 [_pendingTargetWeek]。
  bool _pendingCommit = false;
  int? _pendingTargetWeek;

  /// 网格区宽度（拖拽位移换算进度用），由网格的 LayoutBuilder 回填。
  double _pagerWidth = 0;

  @override
  void initState() {
    super.initState();
    _resolver = TimetableResolver(widget.data);
    _realWeek = _resolver.currentWeek();
    _viewWeek = _realWeek;
    _settle.addListener(_onSettleTick);
    _settle.addStatusListener(_onSettleStatus);
  }

  void _onSettleTick() {
    final tween = _settleTween;
    if (tween == null) return;
    setState(() => _dragDx = tween.evaluate(_settle));
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      if (_pendingCommit && _pendingTargetWeek != null) {
        _viewWeek = _pendingTargetWeek!;
        _selectedKey = null;
      }
      _dragDx = 0;
      _neighborWeek = null;
      _settleTween = null;
      _pendingCommit = false;
      _pendingTargetWeek = null;
    });
  }

  @override
  void didUpdateWidget(_ScheduleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resolver = TimetableResolver(widget.data);
      _scheduleCache.clear();
      _realWeek = _resolver.currentWeek();
      _viewWeek = _realWeek;
      _selectedKey = null;
      _settle.stop();
      _dragDx = 0;
      _neighborWeek = null;
      _settleTween = null;
      _pendingCommit = false;
      _pendingTargetWeek = null;
    }
  }

  @override
  void dispose() {
    _settle
      ..removeListener(_onSettleTick)
      ..removeStatusListener(_onSettleStatus)
      ..dispose();
    super.dispose();
  }

  WeekSchedule _scheduleOf(int week) =>
      _scheduleCache.putIfAbsent(week, () => _resolver.resolve(week));

  /// 今天的星期（1-7）落在 [week] 那一周时返回星期值，否则 -1。
  int _todayWeekdayOf(int week) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final monday = _resolver.mondayOf(week);
    final sunday = _resolver.sundayOf(week);
    return !todayDate.isBefore(monday) && !todayDate.isAfter(sunday)
        ? now.weekday
        : -1;
  }

  /// 周条按钮/周次选择翻周：以滑动动画过渡到目标周（等效一次快速拖拽）。
  void _animateToWeek(int week) {
    final target = week.clamp(1, widget.data.meta.totalWeeks).toInt();
    if (target == _viewWeek) return;
    if (_pagerWidth <= 0) {
      // 布局还没量到宽度（极端时序）：直接切换，不播动画。
      setState(() {
        _viewWeek = target;
        _selectedKey = null;
      });
      return;
    }
    _settle.stop();
    setState(() {
      _neighborWeek = target;
      _pendingCommit = true;
      _pendingTargetWeek = target;
    });
    _settleTween = Tween(
      begin: _dragDx,
      end: target > _viewWeek ? -_pagerWidth : _pagerWidth,
    );
    _settle
      ..reset()
      ..forward();
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
      // 默认 cacheExtent（250）对这张长页面太小：往下滑两屏，上面的课表网格
      // 就被回收，再滑回来要重建整张网格（四十来个格子）连同后面的面板，
      // 实测重建一次 30~100ms，手一滑就顿一下。整页内容总共也就两千多像素，
      // 留 800 的缓存区基本能让它们全程常驻，滚动不再触发重建。
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        // 标题栏悬浮在内容之上，这段留白让首屏内容避开它（值是
        // ImmersiveScaffold 补进 MediaQuery 的「状态栏 + 工具栏」高度；
        // 没套沉浸标题栏时它是 0，这时只剩常规留白）。
        AppTheme.spacingSm + MediaQuery.paddingOf(context).top,
        AppTheme.spacingMd,
        AppTheme.spacingXl,
      ),
      children: [
        if (widget.stale) _StaleDataBanner(updated: meta.updated),
        _ScheduleHeader(meta: meta),
        const SizedBox(height: AppTheme.spacingMd),
        WeekBar(
          week: _viewWeek,
          totalWeeks: meta.totalWeeks,
          currentWeek: _realWeek,
          weekMonday: monday,
          weekSunday: sunday,
          onPrev: () => _animateToWeek(_viewWeek - 1),
          onNext: () => _animateToWeek(_viewWeek + 1),
          onToday: () => _animateToWeek(_realWeek),
          onPickWeek: () => showWeekPicker(
            context,
            week: _viewWeek,
            totalWeeks: meta.totalWeeks,
            currentWeek: _realWeek,
            week1Monday: meta.week1Monday,
            onPick: _animateToWeek,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (!schedule.hasClass) _NoClassBanner(week: _viewWeek),
        // 网格跟手翻周（PageView 式）：拖动时本周网格跟手指位移、相邻周
        // 网格从旁露出；松手按位移/速度吸附到目标周或弹回。手势在水平
        // 方向识别，与外层纵向列表不冲突。
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _settle.stop(),
          onHorizontalDragUpdate: (details) => setState(() {
            _dragDx += details.delta.dx;
            final total = widget.data.meta.totalWeeks;
            if (_dragDx < 0 && _viewWeek < total) {
              _neighborWeek = _viewWeek + 1;
            } else if (_dragDx > 0 && _viewWeek > 1) {
              _neighborWeek = _viewWeek - 1;
            } else {
              // 边界周：没有相邻页可露，位移归零（不橡皮筋）。
              _neighborWeek = null;
              _dragDx = 0;
            }
            _dragDx = _dragDx.clamp(-_pagerWidth, _pagerWidth);
          }),
          onHorizontalDragEnd: (details) {
            final w = _pagerWidth;
            final v = details.primaryVelocity ?? 0;
            final dx = _dragDx;
            // 速度优先，其次位移过半（PageView 的判定策略）。
            final int? dir;
            if (v < -600 || (v <= 0 && dx < -w * 0.4)) {
              dir = 1; // 左滑 → 下一周
            } else if (v > 600 || (v >= 0 && dx > w * 0.4)) {
              dir = -1; // 右滑 → 上一周
            } else {
              dir = null;
            }
            final target = dir == null
                ? null
                : (_viewWeek + dir).clamp(1, widget.data.meta.totalWeeks).toInt();
            if (target == null || target == _viewWeek) {
              // 弹回：吸附回原位，不翻周。
              _settleTween = Tween(begin: dx, end: 0);
              _pendingCommit = false;
              _pendingTargetWeek = null;
              _settle
                ..reset()
                ..forward();
            } else {
              _animateToWeek(target);
            }
          },
          onHorizontalDragCancel: () {
            _settleTween = Tween(begin: _dragDx, end: 0);
            _pendingCommit = false;
            _pendingTargetWeek = null;
            _settle
              ..reset()
              ..forward();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _pagerWidth = constraints.maxWidth;
              final w = _pagerWidth;
              final progress = w > 0 ? _dragDx / w : 0.0;
                  final neighbor = _neighborWeek;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 当前周：跟随手指位移（FractionalTranslation 只影响
                      // 绘制/命中测试，不影响布局——Stack 尺寸仍由它决定）。
                      FractionalTranslation(
                        translation: Offset(progress, 0),
                        child: TimetableGrid(
                          schedule: schedule,
                          weekMonday: monday,
                          todayWeekday: todayWeekday,
                          selectedKey: _selectedKey,
                          onSelectEntry: _selectEntry,
                        ),
                      ),
                      // 相邻周：从拖拽方向一侧露出。只约束左右、顶部对齐，
                      // 高度放开——fill 会把更高的网格压出 overflow。
                      if (neighbor != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: FractionalTranslation(
                            translation: Offset(
                              progress < 0 ? progress + 1 : progress - 1,
                              0,
                            ),
                            child: TimetableGrid(
                              schedule: _scheduleOf(neighbor),
                              weekMonday: _resolver.mondayOf(neighbor),
                              todayWeekday: _todayWeekdayOf(neighbor),
                              selectedKey: null,
                              onSelectEntry: _selectEntry,
                            ),
                          ),
                        ),
                    ],
                  );
            },
          ),
        ),
        // 选中课程后，详情紧贴课表网格（在通知之上）：点的哪一格、就接着
        // 在它下面看这一格的信息，不用跨过通知区去找。
        if (selected != null) ...[
          const SizedBox(height: AppTheme.spacingMd),
          CourseDetailPanel(
            entry: selected,
            onClose: () => setState(() => _selectedKey = null),
          ),
        ],
        // 顺序：网格 → 课程详情 → 通知 → 本周调整 → 图例 → 数据更新历。
        // 通知（NoticesPanel）自带下边距，本周调整直接跟在它下面。
        const SizedBox(height: AppTheme.spacingMd),
        NoticesPanel(notices: notices),
        if (schedule.changes.isNotEmpty) ...[
          WeekChangesPanel(changes: schedule.changes),
          const SizedBox(height: AppTheme.spacingMd),
        ],
        const TimetableLegend(),
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
                // 页名「动态课程表」由标题栏承担，这里只留班级名，避免重复
                meta.className,
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

/// 离线数据提醒横幅：网络同步失败回退本地数据时置顶展示，
/// 明确告知用户当前数据可能不是最新。
class _StaleDataBanner extends StatelessWidget {
  const _StaleDataBanner({required this.updated});

  final String updated;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFA94D); // 暖橙警示，与更新历色板呼应
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
                children: [
                  const TextSpan(
                    text: '网络同步失败，当前展示离线数据',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (updated.isNotEmpty)
                    TextSpan(text: '（最近更新于 $updated）'),
                  const TextSpan(text: '，可能不是最新。恢复网络后重新进入即可同步。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoClassBanner extends StatelessWidget {  const _NoClassBanner({required this.week});

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
