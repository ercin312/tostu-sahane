import '../../shared/domain/entities/order.dart';
import '../utils/order_status_utils.dart';
import '../utils/waiter_order_notes.dart';

/// Yerel önbellek ile Firestore senkronu arasında sipariş durumu birleştirme.
abstract final class OrderMerge {
  static Order resolve(Order local, Order remote) {
    Order picked;
    if (local.status == OrderStatus.cancelled ||
        remote.status == OrderStatus.cancelled) {
      picked = remote.status == OrderStatus.cancelled ? remote : local;
    } else if (_shouldRejectRemoteStatus(local, remote)) {
      picked = _mergeFields(statusSource: local, fieldSource: remote);
    } else {
      final localStep = OrderStatusUtils.fulfillmentStepIndex(local.status);
      final remoteStep = OrderStatusUtils.fulfillmentStepIndex(remote.status);
      if (localStep != remoteStep) {
        picked = remoteStep > localStep ? remote : local;
      } else {
        final localAt = local.atStatus(local.status) ?? local.createdAt;
        final remoteAt = remote.atStatus(remote.status) ?? remote.createdAt;
        picked = remoteAt.isAfter(localAt) ? remote : local;
      }
    }

    picked = _mergeContent(local, remote, picked);

    final rating = picked.rating ?? local.rating ?? remote.rating;
    final ratingComment =
        picked.ratingComment ?? local.ratingComment ?? remote.ratingComment;
    if (rating != picked.rating || ratingComment != picked.ratingComment) {
      picked = picked.copyWith(rating: rating, ratingComment: ratingComment);
    }
    return picked;
  }

  /// Sunucudaki kalem/ekler/not gibi içerik alanlarını kaybetmeyi önler.
  static Order _mergeContent(Order local, Order remote, Order base) {
    final remoteItems = remote.items.length;
    final localItems = local.items.length;
    final remoteTags = remote.preparationTags.length;
    final localTags = local.preparationTags.length;

    final items = remoteItems >= localItems ? remote.items : base.items;
    final preparationTags =
        remoteTags >= localTags ? remote.preparationTags : base.preparationTags;
    final totalAmount =
        remoteItems >= localItems ? remote.totalAmount : base.totalAmount;
    final orderNote = WaiterOrderNotes.mergePreferRicher(
      local.orderNote,
      remote.orderNote,
      base.orderNote,
    );

    if (items == base.items &&
        preparationTags == base.preparationTags &&
        totalAmount == base.totalAmount &&
        orderNote == base.orderNote) {
      return base;
    }

    return base.copyWith(
      items: items,
      preparationTags: preparationTags,
      totalAmount: totalAmount,
      orderNote: orderNote,
    );
  }

  static bool _shouldRejectRemoteStatus(Order local, Order remote) {
    if (local.status == remote.status) return false;
    final localStep = OrderStatusUtils.fulfillmentStepIndex(local.status);
    final remoteStep = OrderStatusUtils.fulfillmentStepIndex(remote.status);
    if (remoteStep <= localStep) return false;
    if (remote.status == OrderStatus.delivered &&
        remote.atStatus(OrderStatus.delivered) == null) {
      return true;
    }
    if (remote.status == OrderStatus.delivered &&
        local.isDineIn &&
        OrderStatusUtils.isDineInBillCloseStatus(local.status)) {
      return false;
    }
    return !OrderStatusUtils.isValidTransition(local.status, remote.status);
  }

  static Order _mergeFields({
    required Order statusSource,
    required Order fieldSource,
  }) {
    return statusSource.copyWith(
      courierId: fieldSource.courierId ?? statusSource.courierId,
      courierName: fieldSource.courierName ?? statusSource.courierName,
      courierLatitude: fieldSource.courierLatitude ?? statusSource.courierLatitude,
      courierLongitude:
          fieldSource.courierLongitude ?? statusSource.courierLongitude,
      statusTimestamps: {
        ...statusSource.statusTimestamps,
        ...fieldSource.statusTimestamps,
      },
      statusActorIds: {
        ...statusSource.statusActorIds,
        ...fieldSource.statusActorIds,
      },
      statusActorNames: {
        ...statusSource.statusActorNames,
        ...fieldSource.statusActorNames,
      },
      approachNotificationSent: fieldSource.approachNotificationSent ||
          statusSource.approachNotificationSent,
      items: fieldSource.items.length >= statusSource.items.length
          ? fieldSource.items
          : statusSource.items,
      preparationTags:
          fieldSource.preparationTags.length >= statusSource.preparationTags.length
              ? fieldSource.preparationTags
              : statusSource.preparationTags,
      totalAmount: fieldSource.items.length >= statusSource.items.length
          ? fieldSource.totalAmount
          : statusSource.totalAmount,
      orderNote: WaiterOrderNotes.mergePreferRicher(
        statusSource.orderNote,
        fieldSource.orderNote,
        statusSource.orderNote ?? fieldSource.orderNote,
      ),
      paymentMethod: fieldSource.paymentMethod,
      paymentTransactionId:
          fieldSource.paymentTransactionId ?? statusSource.paymentTransactionId,
    );
  }
}
