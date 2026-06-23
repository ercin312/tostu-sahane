import '../../entities/order.dart';

import '../use_case.dart';

import '../../../data/repositories/app_repositories.dart';



class PlaceOrderParams {

  const PlaceOrderParams({

    required this.items,

    required this.totalAmount,

    required this.customerId,

    required this.customerName,

    required this.branchId,

    required this.address,

    required this.paymentMethod,

    this.orderNote,

    this.deliveryNow = true,

    this.scheduledAt,

    this.deliveryLatitude,

    this.deliveryLongitude,

    this.customerPhone,

    this.deliveryDirections,

    this.paymentTransactionId,

    this.couponCode,

    this.discountAmount = 0,

    this.deliveryFeeAmount = 0,

    this.estimatedDeliveryMinutes,

  });



  final List<CartItem> items;

  final double totalAmount;

  final String customerId;

  final String customerName;

  final String branchId;

  final String address;

  final PaymentMethod paymentMethod;

  final String? orderNote;

  final bool deliveryNow;

  final DateTime? scheduledAt;

  final double? deliveryLatitude;

  final double? deliveryLongitude;

  final String? customerPhone;

  final String? deliveryDirections;

  final String? paymentTransactionId;

  final String? couponCode;

  final double discountAmount;

  final double deliveryFeeAmount;

  final int? estimatedDeliveryMinutes;

}



class PlaceOrderUseCase extends UseCase<Order, PlaceOrderParams> {

  PlaceOrderUseCase(this._repository);



  final OrderRepository _repository;



  @override

  Future<Order> call(PlaceOrderParams params) async {

    final order = await _repository.buildOrder(

      items: params.items,

      totalAmount: params.totalAmount,

      customerId: params.customerId,

      customerName: params.customerName,

      branchId: params.branchId,

      address: params.address,

      paymentMethod: params.paymentMethod,

      orderNote: params.orderNote,

      deliveryNow: params.deliveryNow,

      scheduledAt: params.scheduledAt,

      deliveryLatitude: params.deliveryLatitude,

      deliveryLongitude: params.deliveryLongitude,

      customerPhone: params.customerPhone,

      deliveryDirections: params.deliveryDirections,

      paymentTransactionId: params.paymentTransactionId,

      couponCode: params.couponCode,

      discountAmount: params.discountAmount,

      deliveryFeeAmount: params.deliveryFeeAmount,

      estimatedDeliveryMinutes: params.estimatedDeliveryMinutes,

    );

    return _repository.placeOrder(order);

  }

}

