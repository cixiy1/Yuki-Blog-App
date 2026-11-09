import 'package:flutter/material.dart';

import '../../../widgets/immersive_scaffold.dart';

/// 校园服务二级页的统一骨架。
///
/// 这些页面都是 `Navigator.push` 进来的，没有底栏；标题栏自动出返回键。
/// body 外用 `SafeArea(top: false)`：顶部留白由 [ImmersiveScaffold] 补回。
class CampusSubPage extends StatelessWidget {
  const CampusSubPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return ImmersiveScaffold(
      title: title,
      actions: actions,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(top: false, child: body),
    );
  }
}
