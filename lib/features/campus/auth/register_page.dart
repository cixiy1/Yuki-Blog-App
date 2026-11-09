import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/route_paths.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import 'widgets/auth_bits.dart';
import 'widgets/demo_account_card.dart';

/// 注册页。新账号一律是「学生」，要当班委得让管理员改数据。
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.services});

  final CampusServices? services;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentId = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _className = TextEditingController(text: '软件2615');

  bool _busy = false;
  String? _error;

  CampusServices get _services => widget.services ?? CampusServices.instance;

  @override
  void dispose() {
    _studentId.dispose();
    _password.dispose();
    _name.dispose();
    _className.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await _services.auth.register(
        studentId: _studentId.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        className: _className.text.trim(),
      );
      await _services.session.establish(session);
      await _services.refreshUnread();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.fieldErrors.isNotEmpty
          ? e.fieldErrors.values.first
          : e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '注册失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                const AuthBrandHeader(
                  title: '注册账号',
                  subtitle: '新账号默认为学生角色',
                ),
                const SizedBox(height: AppTheme.spacingXl),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('register-student-id'),
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
                        key: const Key('register-name'),
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '姓名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '请输入姓名' : null,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      TextFormField(
                        key: const Key('register-class'),
                        controller: _className,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '班级',
                          hintText: '如 软件2615',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '请输入班级' : null,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      TextFormField(
                        key: const Key('register-password'),
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
                          if (value.isEmpty) return '请设置密码';
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
                  key: const Key('register-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('注册并登录'),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(
                            from == null || from.isEmpty
                                ? RoutePaths.login
                                : '${RoutePaths.login}?from=$from',
                          ),
                  child: const Text('已有账号？去登录'),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                DemoAccountCard(
                  onPick: (account) {
                    _studentId.text = account.studentId;
                    _password.text = account.password;
                    _name.text = account.name;
                    _className.text = account.className;
                    setState(() => _error = null);
                  },
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  '演示账号已存在，直接去登录即可。',
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
