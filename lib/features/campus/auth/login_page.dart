import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/route_paths.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/demo_accounts.dart';
import 'widgets/auth_bits.dart';
import 'widgets/demo_account_card.dart';

/// 登录页。挂 `/login`，在 ShellRoute 之外，因此自带 Scaffold。
///
/// 登录成功后不需要手动跳转：`SessionController` 通知 GoRouter，
/// redirect 会把当前地址换成 `from`（或门户）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.services});

  final CampusServices? services;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentId = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  CampusServices get _services => widget.services ?? CampusServices.instance;

  @override
  void dispose() {
    _studentId.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fill(DemoAccount account) {
    setState(() {
      _studentId.text = account.studentId;
      _password.text = account.password;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await _services.auth.login(
        studentId: _studentId.text.trim(),
        password: _password.text,
      );
      await _services.session.establish(session);
      await _services.refreshUnread();
      // 跳转交给路由守卫，这里不发指令。
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageOf(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '登录失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageOf(ApiException e) {
    if (e.fieldErrors.isNotEmpty) return e.fieldErrors.values.first;
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final from = GoRouterState.of(context).uri.queryParameters['from'];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: AppTheme.spacingXl,
              ),
              children: [
                const AuthBrandHeader(),
                const SizedBox(height: AppTheme.spacingXl),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('login-student-id'),
                        controller: _studentId,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '学号',
                          hintText: '8-12 位数字',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return '请输入学号';
                          if (!RegExp(r'^\d{8,12}$').hasMatch(value)) {
                            return '学号需 8-12 位数字';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      TextFormField(
                        key: const Key('login-password'),
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: '密码',
                          hintText: '至少 6 位',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return '请输入密码';
                          if (value.length < 6) return '密码至少 6 位';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: AppTheme.spacingLg),
                ElevatedButton(
                  key: const Key('login-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(
                            from == null || from.isEmpty
                                ? RoutePaths.register
                                : '${RoutePaths.register}?from=$from',
                          ),
                  child: const Text('还没有账号？注册一个'),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                DemoAccountCard(onPick: _fill),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  '当前为本地模拟后端，数据存在本机，换设备不同步。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
