import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/notifications/notification_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/domain/entities/app_broadcast.dart';
import '../../../../../shared/presentation/providers/broadcast_providers.dart';

/// Yeni duyuru gelince yerel bildirimi gösterir; bildirime tıklanınca ayrıntıyı açar.
class BroadcastOpenListener extends ConsumerStatefulWidget {
  const BroadcastOpenListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BroadcastOpenListener> createState() =>
      _BroadcastOpenListenerState();
}

class _BroadcastOpenListenerState extends ConsumerState<BroadcastOpenListener> {
  static const _notifiedKey = 'notified_broadcast_ids_v1';
  static const _bootKey = 'broadcast_inbox_bootstrapped_v1';

  Set<String> _notified = {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    NotificationService.onBroadcastOpened = _open;
    Future.microtask(_boot);
  }

  @override
  void dispose() {
    if (NotificationService.onBroadcastOpened == _open) {
      NotificationService.onBroadcastOpened = null;
    }
    super.dispose();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    _notified = prefs.getStringList(_notifiedKey)?.toSet() ?? {};
    _ready = true;
    if (!mounted) return;
    NotificationService.consumePending(_open);
    final items = ref.read(broadcastsProvider).valueOrNull;
    if (items != null) await _onItems(items);
  }

  void _open(String id) {
    NotificationService.pendingBroadcastId = null;
    if (!mounted || id.isEmpty) return;
    ref.read(seenBroadcastsProvider.notifier).markAll([id]);
    context.push(RoutePaths.broadcastDetail(id));
  }

  Future<void> _onItems(List<AppBroadcast> items) async {
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final bootstrapped = prefs.getBool(_bootKey) ?? false;
    if (!bootstrapped) {
      _notified = items.map((item) => item.id).toSet();
      await prefs.setStringList(_notifiedKey, _notified.toList());
      await prefs.setBool(_bootKey, true);
      await ref.read(seenBroadcastsProvider.notifier).markAll(_notified);
      return;
    }

    final fresh = items.where((item) => !_notified.contains(item.id)).toList();
    if (fresh.isEmpty) return;
    _notified = {..._notified, ...fresh.map((item) => item.id)};
    await prefs.setStringList(_notifiedKey, _notified.toList());
    for (final item in fresh) {
      final preview = item.body.length > 140
          ? '${item.body.substring(0, 137)}...'
          : item.body;
      try {
        await NotificationService.instance.showLocal(
          title: item.title,
          body: preview,
          payload: 'broadcast:${item.id}',
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(broadcastsProvider, (previous, next) {
      final items = next.valueOrNull;
      if (items != null) _onItems(items);
    });
    return widget.child;
  }
}

class CustomerNotificationBell extends ConsumerWidget {
  const CustomerNotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(broadcastsProvider).valueOrNull ?? [];
    final seen = ref.watch(seenBroadcastsProvider);
    final unread = unreadBroadcastCount(items, seen);

    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white,
        shape: const CircleBorder(),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.primary,
        label: Text(
          unread > 9 ? '9+' : '$unread',
          style: const TextStyle(color: AppColors.white),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => context.push(RoutePaths.customerNotifications),
    );
  }
}
