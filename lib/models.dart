// ─────────────────────────────────────────────────────────────────────────────
// Shared models for the Rental App
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String name;
  final String imageUrl;      // cover image (legacy / fallback)
  final List<String> images;  // all images; first is cover if not empty
  final double price;
  final double originalPrice;
  final bool freeDelivery;
  final double coinsSaved;
  final double coinsSave;
  final String location;
  final String? description;
  final String? category;
  final String? listingType; // 'rent' | 'buy'
  final String? ownerId;
  final String? ownerName;
  final String? ownerAvatar;

  Product({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.images = const [],
    required this.price,
    required this.originalPrice,
    this.freeDelivery = false,
    this.coinsSaved = 0.0,
    this.coinsSave = 0.0,
    required this.location,
    this.description,
    this.category,
    this.listingType,
    this.ownerId,
    this.ownerName,
    this.ownerAvatar,
  });

  // ── Image URL helpers ──────────────────────────────────────────────────────

  /// Returns true only for non-empty strings that look like real URLs.
  static bool _isValidUrl(String? url) =>
      url != null && url.isNotEmpty && url.startsWith('http');

  /// The cover image to display in cards and as the first slideshow image.
  /// Prefers the first entry of [images] (product_images join), then falls back
  /// to [imageUrl] (products.image_url column). Returns empty string if neither
  /// is available so widgets can show their own placeholder.
  String get coverImage {
    // Try the first image from the product_images join (already sorted cover-first)
    for (final img in images) {
      if (_isValidUrl(img)) return img;
    }
    // Fall back to the denormalised image_url column on products
    if (_isValidUrl(imageUrl)) return imageUrl;
    return '';
  }

  /// All images to show in slideshow, filtering out any blank/invalid URLs.
  /// Falls back to [imageUrl] when the product_images join returned nothing.
  List<String> get allImages {
    final valid = images.where(_isValidUrl).toList();
    if (valid.isNotEmpty) return valid;
    if (_isValidUrl(imageUrl)) return [imageUrl];
    return [];
  }

  int get discountPercent =>
      originalPrice > 0
          ? ((originalPrice - price) / originalPrice * 100).round()
          : 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;

    // Build image list from product_images join (if present)
    List<String> imgs = [];
    final rawImgs = map['product_images'];
    if (rawImgs is List) {
      // Sort by is_cover desc then sort_order asc so cover is always first
      final sorted = List<Map<String, dynamic>>.from(rawImgs)
        ..sort((a, b) {
          final aCover = (a['is_cover'] == true) ? 0 : 1;
          final bCover = (b['is_cover'] == true) ? 0 : 1;
          if (aCover != bCover) return aCover.compareTo(bCover);
          return ((a['sort_order'] as num?) ?? 0)
              .compareTo((b['sort_order'] as num?) ?? 0);
        });
      imgs = sorted
          .map((m) => (m['image_url'] as String?) ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    }

    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      imageUrl: map['image_url'] ?? '',
      images: imgs,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['original_price'] as num?)?.toDouble() ?? 0.0,
      freeDelivery: map['free_delivery'] ?? false,
      coinsSaved: (map['coins_saved'] as num?)?.toDouble() ?? 0.0,
      coinsSave: (map['coins_save'] as num?)?.toDouble() ?? 0.0,
      location: map['location'] ?? '',
      description: map['description'],
      category: map['category'],
      listingType: map['listing_type'],
      ownerId: map['owner_id'],
      ownerName: profile?['full_name'],
      ownerAvatar: profile?['avatar_url'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'image_url': imageUrl,
    'price': price,
    'original_price': originalPrice,
    'free_delivery': freeDelivery,
    'coins_saved': coinsSaved,
    'coins_save': coinsSave,
    'location': location,
    'description': description,
    'category': category,
    'listing_type': listingType,
    'owner_id': ownerId,
  };
}

class CartItem {
  final String id;
  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  final bool isRental;    // true = listing_type is 'rent'
  int rentalDays;         // used when isRental == true  (min 1)
  final bool freeDelivery;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.isRental = false,
    this.rentalDays = 1,
    this.freeDelivery = false,
  });

  /// Total price: for rentals = price * days; for sales = price (single unit)
  double get totalPrice => isRental ? price * rentalDays : price;

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final product = map['products'] as Map<String, dynamic>? ?? {};
    final listingType = product['listing_type'] as String?;
    final isRental = listingType == 'rent';
    return CartItem(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      name: product['name'] ?? '',
      imageUrl: product['image_url'] ?? '',
      price: (product['price'] as num?)?.toDouble() ?? 0.0,
      isRental: isRental,
      rentalDays: isRental
          ? ((map['rental_days'] as num?)?.toInt() ?? 1).clamp(1, 365)
          : 1,
      freeDelivery: product['free_delivery'] ?? false,
    );
  }
}

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final double walletBalance;
  final int rewardPoints;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.walletBalance = 0.0,
    this.rewardPoints = 0,
  });

  factory AppUser.fromMap(String id, String email, Map<String, dynamic> profile) {
    return AppUser(
      id: id,
      email: email,
      fullName: profile['full_name'] ?? 'User',
      avatarUrl: profile['avatar_url'],
      walletBalance: (profile['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      rewardPoints: (profile['reward_points'] as num?)?.toInt() ?? 0,
    );
  }
}