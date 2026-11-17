import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yuki_blog_app/app/routes/route_paths.dart';

/// 启动页：品牌展示 + 「为人民服务」标语，停留约 1.6 秒后进主界面。
///
/// 原生层（Android launch_background）只有纯色背景，画不了文字；
/// 真正的启动视觉放在这里——Flutter 引擎出首帧后立即显示，
/// 原生启动屏到这里的交接只用背景色对齐（surface），无跳变。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  /// 是否已开始跳转，防止 Timer 重复触发。
  bool _leaving = false;

  /// 停留计时；页面被外部替换（dispose）时取消，不再跳转。
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    _timer = Timer(const Duration(milliseconds: 1600), _leave);
  }

  void _leave() {
    if (!mounted || _leaving) return;
    _leaving = true;
    // go 会把启动页从栈里替换掉，返回键不会退回启动页。
    context.go(RoutePaths.home);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 品牌标：萤火虫（Firefly 主题的 🔥）
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Yuki Blog',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 28),
                    // 标语牌：启动页的核心视觉
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        // letterSpacing 会在末字右侧多出 8px，左侧补齐保持视觉居中。
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '为人民服务',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 8,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'yiyu14.top',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
