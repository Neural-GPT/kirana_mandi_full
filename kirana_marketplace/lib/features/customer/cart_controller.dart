import 'package:flutter/foundation.dart';
import '../../core/errors/exceptions.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/order_repository.dart';

/// Holds the current customer's cart in memory (backed by
/// [CartRepository]'s SQLite table so it survives app restarts /
/// brief offline spells) and notifies listeners so the cart badge and
/// Cart screen stay in sync everywhere in the app.
class CartController extends ChangeNotifier {
  final CartRepository _cartRepository;
  final OrderRepository _orderRepository;

  CartController(this._cartRepository, this._orderRepository);

  String? _customerId;
  List<CartItemModel> _items = [];
  bool _loading = false;
  String? _error;

  // When set (white-label / single-shop mode -- see ShopThemeController
  // and CustomerShellScreen), the cart refuses to add or check out items
  // belonging to any other shop_id, even if a stale product reference
  // from before the lock somehow made it back into a widget's state.
  // This mirrors the equivalent guard on the backend
  // (deps.verify_tenant_scope) at the client layer.
  String? _restrictedToShopId;

  bool get loading => _loading;
  String? get error => _error;
  List<CartItemModel> get items => _items;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get total => _items.fold(0.0, (sum, i) => sum + i.lineTotal);
  String? get restrictedToShopId => _restrictedToShopId;

  /// Locks this cart to a single shop -- call once when the app is
  /// running in single-shop (white-label) mode. Pass null to lift the
  /// restriction (multi-shop marketplace mode, the default).
  void restrictToShop(String? shopId) {
    _restrictedToShopId = (shopId == null || shopId.isEmpty) ? null : shopId;
  }

  List<CartShopGroup> get groupedByShop {
    final byShop = <String, List<CartItemModel>>{};
    for (final item in _items) {
      byShop.putIfAbsent(item.shopId, () => []).add(item);
    }
    return byShop.entries
        .map((e) => CartShopGroup(
              shopId: e.key,
              shopName: e.value.first.shopName,
              items: e.value,
            ))
        .toList();
  }

  /// Call once the logged-in customer is known (e.g. right after login,
  /// or on app start once the session is restored).
  Future<void> loadForCustomer(String customerId) async {
    if (_customerId == customerId && _items.isNotEmpty) return;
    _customerId = customerId;
    await refresh();
  }

  Future<void> refresh() async {
    final customerId = _customerId;
    if (customerId == null) return;
    _loading = true;
    notifyListeners();
    try {
      _items = await _cartRepository.getCartItems(customerId);
      _error = null;
    } catch (e) {
      _error = friendlyErrorMessage(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  int quantityFor(String productId) => _items
      .firstWhere((i) => i.productId == productId,
          orElse: () => CartItemModel(
              id: '',
              customerId: '',
              shopId: '',
              shopName: '',
              productId: '',
              productName: '',
              unit: '',
              unitPrice: 0,
              quantity: 0,
              addedAt: ''))
      .quantity;

  Future<void> addItem({
    required String shopId,
    required String shopName,
    required String productId,
    required String productName,
    required String unit,
    required double unitPrice,
  }) async {
    final customerId = _customerId;
    if (customerId == null) return;
    if (_restrictedToShopId != null && _restrictedToShopId != shopId) {
      _error = "This app is locked to a single shop's catalog.";
      notifyListeners();
      return;
    }
    try {
      await _cartRepository.addOrIncrement(
        customerId: customerId,
        shopId: shopId,
        shopName: shopName,
        productId: productId,
        productName: productName,
        unit: unit,
        unitPrice: unitPrice,
      );
      await refresh();
    } catch (e) {
      _error = friendlyErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> setQuantity(String productId, int quantity) async {
    final customerId = _customerId;
    if (customerId == null) return;
    await _cartRepository.setQuantity(
        customerId: customerId, productId: productId, quantity: quantity);
    await refresh();
  }

  Future<void> removeItem(String productId) async {
    final customerId = _customerId;
    if (customerId == null) return;
    await _cartRepository.removeItem(customerId: customerId, productId: productId);
    await refresh();
  }

  /// Places one order per shop in [groups] (usually the customer's whole
  /// cart, or a single shop group if they check out one shop at a time).
  Future<List<OrderModel>> checkout({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<CartShopGroup> groups,
    required Map<String, String> shopPhoneById,
  }) async {
    final allowedGroups = _restrictedToShopId == null
        ? groups
        : groups.where((g) => g.shopId == _restrictedToShopId).toList();
    final orders = await _orderRepository.placeOrdersFromGroups(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      groups: allowedGroups,
      shopPhoneById: shopPhoneById,
    );
    await refresh();
    return orders;
  }

  void clearOnLogout() {
    _customerId = null;
    _items = [];
    notifyListeners();
  }
}
