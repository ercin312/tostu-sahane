import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/shared/data/datasources/firestore/firestore_datasource.dart';
import 'package:tostu_sahane/shared/data/datasources/firestore/firestore_rest_client.dart';
import 'package:tostu_sahane/shared/data/mappers/entity_mappers.dart';
import 'package:tostu_sahane/shared/data/models/api_models.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

void main() {
  test('dine-in order REST codec roundtrip', () {
    final order = Order(
      id: 'order_test',
      orderNumber: 1001,
      customerId: 'w1',
      customerName: 'Masa 5',
      branchId: 'branch_alanya',
      items: [
        CartItem(
          id: 'line1',
          productId: 'ts_kasarli_tost',
          productNameKey: 'product_kasarli_tost_name',
          unitPrice: 100,
          quantity: 1,
        ),
      ],
      totalAmount: 100,
      status: OrderStatus.preparing,
      createdAt: DateTime.parse('2026-06-22T12:00:00.000'),
      address: 'Salon - Masa 5',
      paymentMethod: PaymentMethod.cashOnDelivery,
      orderType: OrderType.dineIn,
      tableNumber: 5,
      waiterId: 'w1',
      waiterName: 'Garson',
      statusTimestamps: {
        OrderStatus.preparing: DateTime.parse('2026-06-22T12:00:00.000'),
      },
      statusActorIds: {OrderStatus.preparing: 'w1'},
      statusActorNames: {OrderStatus.preparing: 'Garson'},
    );

    final model = EntityMappers.fromOrder(order);
    final json = FirestoreDataSource.stripNullFields(
      FirestoreDataSource.normalizeOrderJson(model.toJson()),
    );
    final encoded = FirestoreRestValueCodec.encodeDocumentFields(json);
    final decoded = FirestoreRestValueCodec.documentToJson(encoded);
    decoded['id'] = order.id;

    final parsed = OrderModel.fromJson(
      FirestoreDataSource.normalizeOrderJson(decoded),
    );
    final back = EntityMappers.toOrder(parsed);

    expect(back.id, order.id);
    expect(back.orderType, OrderType.dineIn);
    expect(back.tableNumber, 5);
  });

  test('phone order source survives REST codec', () {
    final order = Order(
      id: 'order_phone',
      orderNumber: 2002,
      customerId: 'phone_5325120349',
      customerName: 'Telefon müşteri',
      branchId: 'branch_1',
      items: [
        CartItem(
          id: 'line1',
          productId: 'ts_kasarli_tost',
          productNameKey: 'product_kasarli_tost_name',
          unitPrice: 100,
          quantity: 1,
        ),
      ],
      totalAmount: 100,
      status: OrderStatus.received,
      createdAt: DateTime.parse('2026-07-25T12:00:00.000'),
      address: 'Alanya Merkez',
      paymentMethod: PaymentMethod.cashOnDelivery,
      customerPhone: '0532 512 03 49',
      orderSource: OrderSource.phone,
      statusTimestamps: {
        OrderStatus.received: DateTime.parse('2026-07-25T12:00:00.000'),
      },
    );

    final model = EntityMappers.fromOrder(order);
    expect(model.orderSource, 'phone');
    final json = FirestoreDataSource.stripNullFields(
      FirestoreDataSource.normalizeOrderJson(model.toJson()),
    );
    expect(json['order_source'], 'phone');
    final encoded = FirestoreRestValueCodec.encodeDocumentFields(json);
    final decoded = FirestoreRestValueCodec.documentToJson(encoded);
    decoded['id'] = order.id;
    final back = EntityMappers.toOrder(
      OrderModel.fromJson(FirestoreDataSource.normalizeOrderJson(decoded)),
    );
    expect(back.isPhoneOrder, isTrue);
    expect(back.orderSource, OrderSource.phone);
  });

  test('stripNullFields removes null cart item fields', () {
    final json = FirestoreDataSource.stripNullFields({
      'items': [
        {
          'id': 'line1',
          'product_id': 'ts_ayran',
          'product_name_key': 'product_ayran_name',
          'unit_price': 35.0,
          'quantity': 1,
          'selected_options': <String>[],
          'portion_key': null,
          'note': null,
        },
      ],
      'order_note': null,
    });

    expect(json.containsKey('order_note'), isFalse);
    final item = json['items'] as List<dynamic>;
    expect((item.first as Map).containsKey('note'), isFalse);
  });
}
