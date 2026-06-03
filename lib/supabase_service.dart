import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => client.auth.currentUser?.id;

  static Future<bool> isAdmin() async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final profile = await fetchProfile(uid);
      return profile?['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isUserVerified(String userId) async {
    try {
      final profile = await fetchProfile(userId);
      return profile?['nid_verified'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canPerformActions() async {
    final uid = currentUserId;
    if (uid == null) return false;
    if (await isAdmin()) return true;
    final verified = await isUserVerified(uid);
    return verified;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNREAD MESSAGES - NEW METHODS
  // ─────────────────────────────────────────────────────────────────────────

  // Get unread message count for current user
  static Future<int> getUnreadMessageCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;
    try {
      final result = await client.rpc('get_unread_message_count');
      return result as int? ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark all messages in a conversation as read
  static Future<void> markConversationRead(String conversationId) async {
    try {
      await client.rpc('mark_conversation_read', params: {'conv_id': conversationId});
    } catch (e) {
      print('Error marking conversation read: $e');
    }
  }

  // Stream unread message count for real-time updates
  static Stream<int> streamUnreadMessageCount() {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((_) => 0)
        .asyncMap((_) => getUnreadMessageCount());
  }

  // Auth
  static Future<AuthResponse> signUp(String email, String password,
      {String? fullName}) async {
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    return res;
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth
        .signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Profile
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data;
  }

  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    await client.from('profiles').upsert(data);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NID Verification
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> uploadNIDImages(
      String userId, Uint8List frontBytes, Uint8List backBytes) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final frontFileName = '$userId/front_$timestamp.jpg';
    final frontUrl = await _uploadNIDImageBytes(frontBytes, frontFileName);

    final backFileName = '$userId/back_$timestamp.jpg';
    final backUrl = await _uploadNIDImageBytes(backBytes, backFileName);

    await upsertProfile({
      'id': userId,
      'nid_front_url': frontUrl,
      'nid_back_url': backUrl,
      'verification_requested_at': DateTime.now().toIso8601String(),
      'nid_verified': false,
    });
  }

  static Future<String> _uploadNIDImageBytes(
      Uint8List bytes, String filePath) async {
    await client.storage.from('verification').uploadBinary(
      filePath,
      bytes,
      fileOptions:
      const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return filePath;
  }

  static Future<String> getSignedNIDUrl(String storedValue,
      {int expiresInSeconds = 3600}) async {
    final path = _extractNIDPath(storedValue);
    final signedUrl = await client.storage
        .from('verification')
        .createSignedUrl(path, expiresInSeconds);
    return signedUrl;
  }

  static String _extractNIDPath(String storedValue) {
    if (!storedValue.startsWith('http')) return storedValue;
    final uri = Uri.parse(storedValue);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('verification');
    if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
      return segments.sublist(bucketIndex + 1).join('/');
    }
    return storedValue;
  }

  static Future<List<Map<String, dynamic>>> getVerificationRequests() async {
    final data = await client
        .from('profiles')
        .select()
        .not('nid_front_url', 'is', null)
        .eq('nid_verified', false)
        .order('verification_requested_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> approveVerification(String userId) async {
    await upsertProfile({
      'id': userId,
      'nid_verified': true,
      'verification_verified_at': DateTime.now().toIso8601String(),
      'verification_rejected_reason': null,
    });
    await _logAdminAction('approve_verification', targetUserId: userId);
  }

  static Future<void> rejectVerification(String userId, String reason) async {
    await upsertProfile({
      'id': userId,
      'nid_verified': false,
      'verification_rejected_reason': reason,
      'nid_front_url': null,
      'nid_back_url': null,
    });
    await _logAdminAction('reject_verification',
        targetUserId: userId, details: {'reason': reason});
  }

  // Admin User Management
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final data = await client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> banUser(String userId, bool ban,
      {String? reason}) async {
    await upsertProfile({'id': userId, 'is_banned': ban});
    await _logAdminAction(ban ? 'ban_user' : 'unban_user',
        targetUserId: userId,
        details: reason != null ? {'reason': reason} : null);
  }

  static Future<void> setAdminStatus(String userId, bool isAdmin) async {
    await upsertProfile({'id': userId, 'is_admin': isAdmin});
    await _logAdminAction(
        isAdmin ? 'make_admin' : 'remove_admin',
        targetUserId: userId);
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final data = await client
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();
    return data;
  }

  static Future<void> _logAdminAction(String action,
      {String? targetUserId, Map<String, dynamic>? details}) async {
    final adminId = currentUserId;
    if (adminId == null) return;
    await client.from('admin_logs').insert({
      'admin_id': adminId,
      'action': action,
      'target_user_id': targetUserId,
      'details': details,
    });
  }

  static Future<List<Map<String, dynamic>>> getAdminLogs(
      {int limit = 50}) async {
    final data = await client
        .from('admin_logs')
        .select(
        '*, admin:profiles!admin_logs_admin_id_fkey(full_name), target:profiles!admin_logs_target_user_id_fkey(full_name, email)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Products  (now also fetches product_images)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchProducts(
      {String? category, String? listingType}) async {
    var query = client.from('products').select(
        '*, profiles(full_name, avatar_url, nid_verified, is_banned), product_images(image_url, is_cover, sort_order)');
    if (category != null) query = query.eq('category', category);
    if (listingType != null) query = query.eq('listing_type', listingType);
    final data = await query
        .order('created_at', ascending: false)
        .order('sort_order', referencedTable: 'product_images');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> fetchProduct(String id) async {
    final data = await client
        .from('products')
        .select(
        '*, profiles(full_name, avatar_url, nid_verified, is_banned), product_images(image_url, is_cover, sort_order)')
        .eq('id', id)
        .order('sort_order', referencedTable: 'product_images')
        .maybeSingle();
    return data;
  }

  static Future<void> insertProduct(Map<String, dynamic> data) async {
    await client.from('products').insert(data);
  }

  static Future<void> updateProduct(
      String id, Map<String, dynamic> data) async {
    await client.from('products').update(data).eq('id', id);
  }

  static Future<void> deleteProduct(String id) async {
    await client.from('products').delete().eq('id', id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Product Images
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> uploadProductImage(
      String userId, String productId, Uint8List bytes,
      {bool isCover = false, int sortOrder = 0}) async {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final fileName = '$userId/${ts}_$sortOrder.jpg';
    await client.storage.from('products').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    final url = client.storage.from('products').getPublicUrl(fileName);

    await client.from('product_images').insert({
      'product_id': productId,
      'image_url': url,
      'is_cover': isCover,
      'sort_order': sortOrder,
    });

    if (isCover) {
      await client
          .from('products')
          .update({'image_url': url}).eq('id', productId);
    }
    return url;
  }

  static Future<void> setProductCoverImage(
      String productId, String imageId) async {
    await client
        .from('product_images')
        .update({'is_cover': false}).eq('product_id', productId);
    final row = await client
        .from('product_images')
        .update({'is_cover': true})
        .eq('id', imageId)
        .select('image_url')
        .single();
    await client
        .from('products')
        .update({'image_url': row['image_url']}).eq('id', productId);
  }

  static Future<void> deleteProductImage(
      String imageId, String imageUrl, String userId) async {
    await client.from('product_images').delete().eq('id', imageId);
    try {
      final uri = Uri.parse(imageUrl);
      final idx = uri.pathSegments.indexOf('products');
      if (idx != -1) {
        final path = uri.pathSegments.sublist(idx + 1).join('/');
        await client.storage.from('products').remove([path]);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Saves
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchSaves(
      String userId) async {
    final data = await client
        .from('saves')
        .select(
        '*, products(*, profiles(full_name), product_images(image_url, is_cover, sort_order))')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> saveProduct(String userId, String productId) async {
    await client
        .from('saves')
        .upsert({'user_id': userId, 'product_id': productId});
  }

  static Future<void> unsaveProduct(
      String userId, String productId) async {
    await client
        .from('saves')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  static Future<bool> isSaved(String userId, String productId) async {
    final data = await client
        .from('saves')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();
    return data != null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cart  (rental_days support)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchCart(
      String userId) async {
    final data = await client
        .from('cart_items')
        .select('*, products(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addToCart(
      String userId, String productId, {int rentalDays = 1}) async {
    await client.from('cart_items').upsert({
      'user_id': userId,
      'product_id': productId,
      'quantity': 1,
      'rental_days': rentalDays,
    });
  }

  static Future<void> updateCartRentalDays(
      String cartItemId, int days) async {
    if (days <= 0) {
      await client.from('cart_items').delete().eq('id', cartItemId);
    } else {
      await client
          .from('cart_items')
          .update({'rental_days': days})
          .eq('id', cartItemId);
    }
  }

  static Future<void> removeFromCart(String cartItemId) async {
    await client.from('cart_items').delete().eq('id', cartItemId);
  }

  // Chat
  static Future<List<Map<String, dynamic>>> fetchConversations(
      String userId) async {
    final data = await client
        .from('conversations')
        .select(
        '*, messages(text, created_at, sender_id, read_at), buyer:profiles!conversations_buyer_id_fkey(full_name, avatar_url), seller:profiles!conversations_seller_id_fkey(full_name, avatar_url), products(name)')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(
      String conversationId) async {
    final data = await client
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(full_name)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> sendMessage(
      String conversationId, String senderId, String text) async {
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
    });
    await client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()}).eq(
        'id', conversationId);
  }

  static Future<String> getOrCreateConversation(
      String buyerId, String sellerId, String productId) async {
    final existing = await client
        .from('conversations')
        .select('id')
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final res = await client
        .from('conversations')
        .insert({
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId
    })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // Chat delete feature
  static Future<void> deleteConversation(String conversationId) async {
    try {
      await client.from('conversations').delete().eq('id', conversationId);
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }

  static Future<bool> canDeleteConversation(String conversationId) async {
    try {
      final result = await client.rpc('can_delete_conversation', params: {
        'conv_id': conversationId,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  // Rentals / Orders
  static Future<List<Map<String, dynamic>>> fetchMyRentals(
      String userId) async {
    final data = await client
        .from('rentals')
        .select('*, products(*, profiles(full_name))')
        .eq('renter_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchMyListings(
      String userId) async {
    final data = await client
        .from('products')
        .select('*, product_images(image_url, is_cover, sort_order)')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // Bills / Top-Up / Rewards / Vouchers
  static Future<List<Map<String, dynamic>>> fetchVouchers(
      String userId) async {
    final data = await client
        .from('vouchers')
        .select('*')
        .or('user_id.eq.$userId,user_id.is.null');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchRewards(
      String userId) async {
    final data = await client
        .from('rewards')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchBillHistory(
      String userId) async {
    final data = await client
        .from('bill_payments')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> payBill(Map<String, dynamic> billData) async {
    await client.from('bill_payments').insert(billData);
  }

  static Future<Map<String, dynamic>?> fetchWallet(String userId) async {
    return await client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  static Future<void> topUpWallet(String userId, double amount) async {
    final wallet = await fetchWallet(userId);
    if (wallet == null) {
      await client
          .from('wallets')
          .insert({'user_id': userId, 'balance': amount});
    } else {
      final newBalance = (wallet['balance'] as num).toDouble() + amount;
      await client
          .from('wallets')
          .update({'balance': newBalance}).eq('user_id', userId);
    }
    await client
        .from('topup_history')
        .insert({'user_id': userId, 'amount': amount});
  }
}