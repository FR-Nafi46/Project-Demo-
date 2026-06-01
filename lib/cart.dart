import 'package:flutter/material.dart';
import 'models.dart';
import 'supabase_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  List<CartItem> cartItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final data = await SupabaseService.fetchCart(uid);
      setState(() {
        cartItems = data.map((m) => CartItem.fromMap(m)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateQty(CartItem item, int delta) async {
    final newQty = item.quantity + delta;
    setState(() {
      if (newQty <= 0) {
        cartItems.removeWhere((i) => i.id == item.id);
      } else {
        item.quantity = newQty;
      }
    });
    await SupabaseService.updateCartQuantity(item.id, newQty);
  }

  Future<void> _removeItem(CartItem item) async {
    setState(() => cartItems.removeWhere((i) => i.id == item.id));
    await SupabaseService.removeFromCart(item.id);
  }

  double get subtotal => cartItems.fold(0.0, (s, i) => s + i.price * i.quantity);
  double get deliveryFee => cartItems.any((i) => !i.freeDelivery) ? 5.99 : 0.0;
  double get total => subtotal + deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor, foregroundColor: Colors.white,
        title: const Text('My Cart'), centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SupabaseService.currentUserId == null
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Please log in to view your cart', style: TextStyle(fontSize: 16)),
        ]),
      )
          : cartItems.isEmpty
          ? Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            child: const Text('Start Shopping'),
          ),
        ]),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cartItems.length,
              itemBuilder: (_, i) => _CartItemCard(
                item: cartItems[i],
                onIncrease: () => _updateQty(cartItems[i], 1),
                onDecrease: () => _updateQty(cartItems[i], -1),
                onRemove: () => _removeItem(cartItems[i]),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _summaryRow('Subtotal', '৳${subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _summaryRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '৳${deliveryFee.toStringAsFixed(2)}'),
                const Divider(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('৳${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Proceeding to checkout…'))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(label), Text(value)],
  );
}

class _CartItemCard extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final CartItem item;
  final VoidCallback onIncrease, onDecrease, onRemove;

  const _CartItemCard({required this.item, required this.onIncrease, required this.onDecrease, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(item.imageUrl, width: 80, height: 80, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 80, height: 80,
                  color: Colors.grey.shade300, child: const Icon(Icons.broken_image))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('৳${item.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(onTap: onDecrease, child: const Icon(Icons.remove, size: 16, color: primaryColor)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
                GestureDetector(onTap: onIncrease, child: const Icon(Icons.add, size: 16, color: primaryColor)),
              ]),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onRemove),
          ]),
          if (item.freeDelivery)
            Row(children: [
              Icon(Icons.local_shipping_outlined, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('Free Delivery', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
            ]),
        ])),
      ]),
    );
  }
}