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
    this.padBodyTop = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  /// body 是「固定头 + 滚动列表」这类结构时置 true。
  ///
  /// 沉浸标题栏让 body 从屏幕顶端开始铺，滚动视图会自己吃掉
  /// `MediaQuery.padding.top`，但固定不滚的表头不会——不加这个就钻到
  /// 标题栏底下去了，看着像被裁掉。
  final bool padBodyTop;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padBodyTop) {
      content = Builder(
        // 补偿过的 padding 只在 body 子树里，必须用 body 内的 context 取。
        builder: (context) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: body,
        ),
      );
    }

    return ImmersiveScaffold(
      title: title,
      actions: actions,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(top: false, child: content),
    );
  }
}
