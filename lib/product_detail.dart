import 'package:flutter/material.dart';
import 'models.dart';
import 'supabase_service.dart';
import 'chat.dart';
import 'merit_system.dart';
import 'merit_history.dart';
import 'nid_verification.dart';
import 'verification_popup.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  bool _isSaved = false;
  bool _isLoading = false;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    final saved = await SupabaseService.isSaved(uid, widget.product.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }
    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      await SupabaseService.saveProduct(uid, widget.product.id);
    } else {
      await SupabaseService.unsaveProduct(uid, widget.product.id);
    }
  }

  Future<void> _addToCart() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    // Check if user can perform actions (verified or admin)
    final canPerform = await SupabaseService.canPerformActions();
    if (!canPerform) {
      VerificationRequiredPopup.show(context, onVerify: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NIDVerificationPage()));
      });
      return;
    }

    // Merit check for rentals
    final isRental = widget.product.listingType == 'rent';
    if (isRental) {
      final merit = await MeritService.getUserMerit(uid);
      if (!merit.canRent) {
        _showMeritBlockDialog(merit);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.addToCart(uid, widget.product.id, _qty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart!'), backgroundColor: Color(0xFF381932)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMeritBlockDialog(UserMerit merit) {
    final tier = merit.tier;
    final tierColor = Color(tier.color as int);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: tierColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.block, color: tierColor, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Cannot Rent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your current merit score is ${merit.points}/100.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            const Text(
              'You need at least 40 merit points to rent items.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: merit.points / 100,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${merit.points} pts', style: TextStyle(fontSize: 12, color: tierColor, fontWeight: FontWeight.bold)),
              Text('Need: 40 pts', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('How to improve your merit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                const SizedBox(height: 8),
                ..._meritTips().map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.add_circle, color: Colors.green, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(tip, style: const TextStyle(fontSize: 12))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MeritHistoryPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Merit'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  List<String> _meritTips() => [
    'Complete your profile (+5 pts)',
    'List quality products (+3 pts each)',
    'Leave reviews for sellers (+2 pts)',
    'Respond to messages quickly (+1 pt)',
    'Refer friends to the app (+10 pts)',
  ];

  Future<void> _chatWithSeller() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }
    final sellerId = widget.product.ownerId;
    if (sellerId == null || sellerId == uid) return;
    try {
      final convId = await SupabaseService.getOrCreateConversation(uid, sellerId, widget.product.id);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
          conversationId: convId,
          otherUserName: widget.product.ownerName ?? 'Seller',
          otherUserAvatar: widget.product.ownerAvatar ?? '',
          productName: widget.product.name,
        )));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isRental = p.listingType == 'rent';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300, pinned: true,
            backgroundColor: primaryColor, foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(p.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 60))),
            ),
            actions: [
              IconButton(
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: _toggleSave,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('৳${p.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                      if (isRental) ...[
                        const SizedBox(width: 4),
                        Text('/day', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(width: 12),
                      if (p.originalPrice > p.price)
                        Text('৳${p.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600,
                                decoration: TextDecoration.lineThrough)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('${p.discountPercent}% OFF',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (p.freeDelivery) _tag(Icons.local_shipping, 'Free Delivery', Colors.green),
                      if (p.listingType != null)
                        _tag(p.listingType == 'rent' ? Icons.loop : Icons.sell,
                            p.listingType == 'rent' ? 'For Rent' : 'For Sale', primaryColor),
                      _tag(Icons.location_on, p.location, Colors.blue),
                      if (p.category != null) _tag(Icons.category, p.category!, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (p.coinsSaved > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200)),
                      child: Row(children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Save ${p.coinsSaved.toStringAsFixed(0)} coins  •  Earn ${p.coinsSave.toStringAsFixed(1)} coins',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  const SizedBox(height: 20),
                  if (p.ownerName != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: p.ownerAvatar != null ? NetworkImage(p.ownerAvatar!) : null,
                          backgroundColor: primaryColor.withOpacity(0.2),
                          child: p.ownerAvatar == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Listed by', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(p.ownerName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ])),
                        if (p.ownerId != null && p.ownerId != SupabaseService.currentUserId)
                          TextButton.icon(
                            onPressed: _chatWithSeller,
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('Chat'),
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 20),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(p.description!, style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.6)),
                    const SizedBox(height: 20),
                  ],
                  Row(children: [
                    const Text('Quantity:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: primaryColor.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                          color: primaryColor,
                        ),
                        Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _qty++),
                          color: primaryColor,
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _chatWithSeller,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Chat Seller', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Text(isRental ? 'Rent Now' : 'Add to Cart', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}