import 'package:flutter/foundation.dart';

/// One line in the cart. Holds a snapshot of what the buyer sees (selling price,
/// packaging) — never any supplier data.
class CartLine {
  final String productId;
  final String code;
  final String? description;
  final double sellingPrice;
  final int unitsPerCarton;
  final bool cartonOnly;
  final int moq;
  final int availableQty;
  final String? imageUrl;
  int qty;

  CartLine({
    required this.productId,
    required this.code,
    required this.description,
    required this.sellingPrice,
    required this.unitsPerCarton,
    required this.cartonOnly,
    required this.moq,
    required this.availableQty,
    required this.imageUrl,
    required this.qty,
  });

  double get lineTotal => sellingPrice * qty;
}

/// Simple app-wide cart. Client-side only; the order is created server-side by
/// the place_order RPC at checkout.
class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();
  int get count => _lines.length;
  double get subtotal => _lines.values.fold(0, (s, l) => s + l.lineTotal);

  int qtyFor(String productId) => _lines[productId]?.qty ?? 0;

  void addOrUpdate(CartLine line) {
    if (line.qty <= 0) {
      _lines.remove(line.productId);
    } else {
      _lines[line.productId] = line;
    }
    notifyListeners();
  }

  void setQty(String productId, int qty) {
    final l = _lines[productId];
    if (l == null) return;
    if (qty <= 0) {
      _lines.remove(productId);
    } else {
      l.qty = qty;
    }
    notifyListeners();
  }

  void remove(String productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toRpcItems() =>
      _lines.values.map((l) => {'product_id': l.productId, 'qty': l.qty}).toList();
}
