import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'supabase_service.dart';
import 'product_detail.dart';
import 'profile.dart';
import 'cart.dart';
import 'saves.dart';
import 'chat.dart';
import 'upload.dart';
import 'search.dart';
import 'bills.dart';
import 'vouchers.dart';
import 'top_up.dart';
import 'rewards.dart';
import 'all_products.dart';
import 'notifications.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  List<Product> allProducts = [];
  List<Product> products = [];
  bool _loading = true;

  final List<String> filters = [
    'Best Match', 'Filter', 'Voucher Max', 'Mall', 'Free Delivery', 'Buy More Save',
  ];
  int _selectedFilterIndex = 0;
  int _selectedNavIndex = 0;
  String _selectedExploreMode = 'Rent';

  // Key to access the chat nav item's state so we can refresh the unread count
  final GlobalKey<_ChatNavItemState> _chatNavKey = GlobalKey<_ChatNavItemState>();

  late PageController _carouselController;
  late Timer _carouselTimer;
  int _currentCarouselPage = 0;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Electronics', 'image': 'https://images.unsplash.com/photo-1498049794561-7780e7231661?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'},
    {'name': 'Furniture',   'image': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'},
    {'name': 'Vehicles',    'image': 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'},
    {'name': 'Accessories', 'image': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'},
    {'name': 'Other',       'image': 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'},
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
    _startCarouselTimer();
    _loadProducts();
  }

  Future<void> _loadProducts({String? listingType}) async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.fetchProducts(listingType: listingType);
      final loaded = data.map((m) => Product.fromMap(m)).toList();
      setState(() {
        allProducts = loaded;
        products = List.from(loaded);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    }
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_carouselController.hasClients) {
        final next = (_currentCarouselPage + 1) % _categories.length;
        _carouselController.animateToPage(next,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _applyFilter(int index) {
    setState(() {
      _selectedFilterIndex = index;
      switch (index) {
        case 0: products = List.from(allProducts); break;
        case 1:
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Filter options coming soon!')));
          break;
        case 2: products = allProducts.where((p) => p.discountPercent >= 30).toList(); break;
        case 3: products = List.from(allProducts); break;
        case 4: products = allProducts.where((p) => p.freeDelivery).toList(); break;
        case 5: products = allProducts.where((p) => p.discountPercent >= 20).toList(); break;
        default: products = List.from(allProducts);
      }
    });
  }

  void _onNavItemTapped(int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavesPage()));
      return;
    }
    if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListPage()))
          .then((_) {
        // Reload unread count when returning from chat so badge clears
        _chatNavKey.currentState?._loadUnreadCount();
      });
      return;
    }
    if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return;
    }
    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Rental Market'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filters[index],
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    onSelected: (_) => _applyFilter(index),
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: primaryColor,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadProducts(),
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carousel
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _carouselController,
                            onPageChanged: (i) => setState(() => _currentCarouselPage = i),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => SearchPage(query: cat['name']))),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                      image: NetworkImage(cat['image']),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(0.3), BlendMode.darken),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(cat['name'],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            shadows: [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(2, 2))])),
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 12, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_categories.length, (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentCarouselPage == i ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentCarouselPage == i ? primaryColor : Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Explore + Rent/Buy toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Explore', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AllProductsPage(products: products))),
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _ExploreToggleButton(
                            label: 'Rent', isSelected: _selectedExploreMode == 'Rent',
                            onTap: () { setState(() => _selectedExploreMode = 'Rent'); _loadProducts(listingType: 'rent'); },
                            selectedColor: primaryColor,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _ExploreToggleButton(
                            label: 'Buy', isSelected: _selectedExploreMode == 'Buy',
                            onTap: () { setState(() => _selectedExploreMode = 'Buy'); _loadProducts(listingType: 'buy'); },
                            selectedColor: primaryColor,
                          )),
                        ],
                      ),
                    ),

                    // Bills & Vouchers
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Bills & Vouchers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _serviceItem(Icons.receipt_long, 'Pay Bills', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillsPage()))),
                          _serviceItem(Icons.local_offer, 'Vouchers', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VouchersPage()))),
                          _serviceItem(Icons.credit_card, 'Top Up', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpPage()))),
                          _serviceItem(Icons.card_giftcard, 'Rewards', Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage()))),
                        ],
                      ),
                    ),

                    // Recommended header
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recommended for you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AllProductsPage(products: products))),
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Product grid
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (products.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No products yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                              const SizedBox(height: 8),
                              const Text('Be the first to list an item!', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) => ProductGridCard(product: products[index]),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: primaryColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0),
              _buildNavItem(icon: Icons.bookmark_border, activeIcon: Icons.bookmark, label: 'Save', index: 1),
              const SizedBox(width: 48),
              _buildNavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat', index: 3),
              _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 4),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 65, height: 65,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage()));
            _loadProducts();
          },
          backgroundColor: primaryColor,
          elevation: 8,
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _serviceItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int index}) {
    final isSelected = _selectedNavIndex == index;

    if (index == 3) {
      return _ChatNavItem(
        key: _chatNavKey,
        isSelected: isSelected,
        onTap: () => _onNavItemTapped(index),
        label: label,
        icon: icon,
        activeIcon: activeIcon,
      );
    }

    return InkWell(
      onTap: () => _onNavItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? activeIcon : icon, color: isSelected ? Colors.white : Colors.white70),
          Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }
}

// Chat Navigation Item with Unread Badge (Fixed)
class _ChatNavItem extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _ChatNavItem({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  @override
  State<_ChatNavItem> createState() => _ChatNavItemState();
}

class _ChatNavItemState extends State<_ChatNavItem> {
  int _unreadCount = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await SupabaseService.getUnreadMessageCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _setupRealtimeListener() {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    _channel = SupabaseService.client
        .channel('messages_unread_${userId.substring(0, 8)}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (_, [__]) => _loadUnreadCount(),
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (_, [__]) => _loadUnreadCount(),
    )
        .subscribe((status, [_]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _loadUnreadCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.isSelected ? widget.activeIcon : widget.icon,
                  color: widget.isSelected ? Colors.white : Colors.white70),
              Text(widget.label,
                  style: TextStyle(fontSize: 12,
                      color: widget.isSelected ? Colors.white : Colors.white70)),
            ],
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            top: -6,
            right: -10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExploreToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  const _ExploreToggleButton({required this.label, required this.isSelected, required this.onTap, required this.selectedColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? selectedColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Center(child: Text(label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 16))),
      ),
    );
  }
}

class ProductGridCard extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final Product product;
  const ProductGridCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailPage(product: product))),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = constraints.maxHeight * 0.55;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.18), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: product.coverImage.isEmpty
                        ? Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                    )
                        : Image.network(
                      product.coverImage,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, prog) {
                        if (prog == null) return child;
                        return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)));
                      },
                      errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image, size: 30)),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          Text('৳${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          if (product.originalPrice > product.price) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                  '৳${product.originalPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      decoration:
                                      TextDecoration.lineThrough),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          if (product.discountPercent > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('${product.discountPercent}% OFF',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700)),
                            ),
                          if (product.listingType != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                  product.listingType == 'rent'
                                      ? 'Rent'
                                      : 'Buy',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor)),
                            ),
                          ],
                        ]),
                        const Spacer(),
                        Row(children: [
                          if (product.freeDelivery) ...[
                            Icon(Icons.local_shipping,
                                size: 11, color: Colors.green.shade700),
                            const SizedBox(width: 2),
                            Text('FREE',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                          ],
                          Icon(Icons.location_on,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 1),
                          Expanded(
                              child: Text(product.location,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}