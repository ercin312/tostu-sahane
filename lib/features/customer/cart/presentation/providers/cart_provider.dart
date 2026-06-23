import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../shared/domain/entities/order.dart';

class CartBranchIdNotifier extends Notifier<String?> {
  static const _storageKey = 'customer_cart_branch_v1';

  @override
  String? build() {
    Future.microtask(_loadFromStorage);
    return null;
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == null) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, state!);
    }
  }

  void set(String branchId) {
    state = branchId;
    _persist();
  }

  void clear() {
    state = null;
    _persist();
  }
}

final cartBranchIdProvider =
    NotifierProvider<CartBranchIdNotifier, String?>(
  CartBranchIdNotifier.new,
);

class CartNotifier extends Notifier<List<CartItem>> {
  static const _storageKey = 'customer_cart_v1';

  @override
  List<CartItem> build() {
    Future.microtask(_loadFromStorage);
    return [];
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = json.decode(raw) as List<dynamic>;
      final items = list
          .map((e) => _cartItemFromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) state = items;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      final encoded = json.encode(state.map(_cartItemToJson).toList());
      await prefs.setString(_storageKey, encoded);
    }
  }

  Map<String, dynamic> _cartItemToJson(CartItem item) => {
        'id': item.id,
        'product_id': item.productId,
        'product_name_key': item.productNameKey,
        'unit_price': item.unitPrice,
        'quantity': item.quantity,
        'selected_options': item.selectedOptions,
        'portion_key': item.portionKey,
        'note': item.note,
      };

  CartItem _cartItemFromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productNameKey: json['product_name_key'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        selectedOptions: (json['selected_options'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        portionKey: json['portion_key'] as String?,
        note: json['note'] as String?,
      );

  void addItem(CartItem item, {required String branchId}) {
    ref.read(cartBranchIdProvider.notifier).set(branchId);
    state = [...state, item];
    _persist();
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    state = [
      for (final item in state)
        if (item.id == itemId) item.copyWith(quantity: quantity) else item,
    ];
    _persist();
  }

  void removeItem(String itemId) {
    state = state.where((item) => item.id != itemId).toList();
    _persist();
    if (state.isEmpty) {
      ref.read(cartBranchIdProvider.notifier).clear();
    }
  }

  void clear() {
    state = [];
    _persist();
    ref.read(cartBranchIdProvider.notifier).clear();
  }

  void reorderItems(List<CartItem> items, {required String branchId}) {
    ref.read(cartBranchIdProvider.notifier).set(branchId);
    state = [
      for (final item in items)
        CartItem(
          id: generateCartItemId(),
          productId: item.productId,
          productNameKey: item.productNameKey,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          selectedOptions: item.selectedOptions,
          portionKey: item.portionKey,
          note: item.note,
        ),
    ];
    _persist();
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.totalPrice);

  bool get meetsMinimumOrder => subtotal >= AppConstants.minimumOrderAmount;

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

final cartMeetsMinimumProvider = Provider<bool>((ref) {
  return ref.watch(cartSubtotalProvider) >= AppConstants.minimumOrderAmount;
});

String generateCartItemId() =>
    'cart_${DateTime.now().microsecondsSinceEpoch}';
