import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/app_message.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'widgets/message_tile.dart';

/// 统一收件箱：审核结果、接单、送达、催填都在这里。
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key, this.services, this.onOpenRef});

  final CampusServices? services;

  /// 点击消息后的跳转。各模块的详情页接入后由调用方传进来。
  final Future<void> Function(AppMessage message)? onOpenRef;

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  List<AppMessage> _items = const [];
  bool _loading = true;
  String? _error;

  CampusServices get _services => widget.services ?? CampusServices.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _services.messages.list();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
      await _services.refreshUnread();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _services.messages.markAllRead();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部标为已读')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _open(AppMessage message) async {
    if (!message.read) {
      try {
        await _services.messages.markRead(message.id);
        await _services.refreshUnread();
        if (mounted) {
          setState(() {
            _items = [
              for (final m in _items)
                m.id == message.id ? m.copyWith(read: true) : m,
            ];
          });
        }
      } on ApiException {
        // 标记已读失败不影响后续跳转
      }
    }

    if (!mounted) return;
    final handler = widget.onOpenRef;
    if (handler != null) {
      await handler(message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('对应详情页会在该模块上线后开放')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '消息中心',
      actions: [
        if (_items.any((m) => !m.read))
          TextButton(
            onPressed: _markAllRead,
            child: const Text('全部已读'),
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '消息加载失败',
            message: _error,
            actionLabel: '重试',
            onAction: _load,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.notifications_none_rounded,
            title: '还没有消息',
            message: '活动审核结果、接单与送达提醒都会出现在这里',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingSm,
        bottom: AppTheme.spacingXl,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 66, endIndent: AppTheme.spacingMd),
      itemBuilder: (context, index) {
        final message = _items[index];
        return MessageTile(
          message: message,
          onTap: () => _open(message),
        );
      },
    );
  }
}
