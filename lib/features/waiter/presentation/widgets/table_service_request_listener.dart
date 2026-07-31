import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/services/branch_alert_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/domain/entities/qr_menu_settings.dart';
import '../../../../shared/presentation/providers/repository_providers.dart';
import '../../../admin/qr_menu/presentation/providers/qr_menu_provider.dart';

/// QR menüden gelen garson çağır — kalıcı banner + sesli uyarı.
class TableServiceRequestListener extends ConsumerStatefulWidget {
  const TableServiceRequestListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TableServiceRequestListener> createState() =>
      _TableServiceRequestListenerState();
}

class _TableServiceRequestListenerState
    extends ConsumerState<TableServiceRequestListener> {
  final _announced = <String>{};
  var _active = <TableServiceRequest>[];
  var _soundPlaying = false;

  @override
  void dispose() {
    unawaited(BranchAlertService.stopAlert());
    super.dispose();
  }

  String _label(TableServiceRequest req) {
    if (req.message.isNotEmpty) return req.message;
    return req.type == TableServiceRequestType.callWaiter
        ? LocaleKeys.qrCallWaiterAlert.tr(
            namedArgs: {'table': '${req.tableNumber}'},
          )
        : LocaleKeys.qrRequestBillAlert.tr(
            namedArgs: {'table': '${req.tableNumber}'},
          );
  }

  Future<void> _syncSound() async {
    if (_active.isEmpty) {
      _soundPlaying = false;
      await BranchAlertService.stopAlert();
      return;
    }
    if (_soundPlaying) return;
    _soundPlaying = true;
    await BranchAlertService.playWaiterCallAlert();
  }

  Future<void> _ack(TableServiceRequest req) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .acknowledgeTableServiceRequest(req.id);
      if (!mounted) return;
      setState(() {
        _active = _active.where((e) => e.id != req.id).toList();
      });
      await _syncSound();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingTableServiceRequestsProvider, (previous, next) {
      final list = next.valueOrNull ?? const <TableServiceRequest>[];
      final pendingIds = list.map((e) => e.id).toSet();

      // Ack edilenleri ekrandan kaldır
      final pruned = _active.where((e) => pendingIds.contains(e.id)).toList();
      final added = <TableServiceRequest>[];
      for (final req in list) {
        if (_announced.add(req.id)) {
          added.add(req);
        }
      }

      if (pruned.length != _active.length || added.isNotEmpty) {
        setState(() {
          _active = [...pruned, ...added];
        });
        unawaited(_syncSound());
      } else if (_active.isEmpty && _soundPlaying) {
        unawaited(_syncSound());
      }
    });

    return Stack(
      children: [
        widget.child,
        if (_active.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 12,
              color: AppColors.primaryDark,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final req in _active)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          req.type == TableServiceRequestType.callWaiter
                              ? Icons.notifications_active
                              : Icons.receipt_long,
                          color: Colors.white,
                        ),
                        title: Text(
                          _label(req),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => unawaited(_ack(req)),
                          child: Text(
                            LocaleKeys.qrRequestAck.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
