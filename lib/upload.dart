import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'nid_verification.dart';
import 'verification_popup.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _origPriceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // ── Multi-image state ──────────────────────────────────────────────────────
  // Each entry: { 'bytes': Uint8List, 'isCover': bool }
  final List<Map<String, dynamic>> _selectedImages = [];
  int _coverIndex = 0; // index in _selectedImages that is cover

  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'Electronics';
  String _listingType = 'rent';
  bool _freeDelivery = false;
  bool _loading = false;

  final List<String> _categories = [
    'Electronics', 'Furniture', 'Vehicles', 'Fashion', 'Sports', 'Books', 'Other'
  ];

  LatLng? _selectedLocation;
  bool _isMapLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _origPriceCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final List<XFile> picked = await _picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;

    for (final xfile in picked) {
      if (_selectedImages.length >= 8) break; // max 8 images
      final bytes = await xfile.readAsBytes();
      setState(() {
        _selectedImages.add({'bytes': bytes});
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_coverIndex >= _selectedImages.length) {
        _coverIndex = _selectedImages.isEmpty ? 0 : _selectedImages.length - 1;
      }
    });
  }

  void _setCover(int index) {
    setState(() => _coverIndex = index);
  }

  // ── Upload helpers ─────────────────────────────────────────────────────────

  /// Uploads a single image. [uniqueName] must be globally unique e.g. "$uid/${ts}_$i.jpg"
  Future<String> _uploadSingleImage(Uint8List bytes, String uniqueName) async {
    await SupabaseService.client.storage
        .from('products')
        .uploadBinary(
      uniqueName,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return SupabaseService.client.storage
        .from('products')
        .getPublicUrl(uniqueName);
  }

  // ── Map helpers ────────────────────────────────────────────────────────────

  Future<void> _openMap() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permission is required to use the map feature'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enable location permission in app settings'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(
          initialLocation: _selectedLocation,
          onLocationSelected: (LatLng location, String address) {
            setState(() {
              _selectedLocation = location;
              _locationCtrl.text = address;
            });
          },
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isMapLoading = true);
    try {
      PermissionStatus permissionStatus = await Permission.location.request();
      if (!permissionStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')));
        }
        setState(() => _isMapLoading = false);
        return;
      }

      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location services are disabled')));
          }
          setState(() => _isMapLoading = false);
          return;
        }
      }

      loc.LocationData currentLocation = await location.getLocation();
      LatLng currentLatLng = LatLng(
          currentLocation.latitude ?? 0, currentLocation.longitude ?? 0);
      String address = await _getAddressFromLatLng(currentLatLng);

      setState(() {
        _selectedLocation = currentLatLng;
        _locationCtrl.text = address;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location detected: $address'),
                backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error getting location: $e'),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  // Google Maps API key — must match AndroidManifest.xml & Info.plist
  static const String _googleApiKey = 'AIzaSyC1Lr5p_w2AnxPNgdsvqVCwnMPwxOlUGA0';

  Future<String> _getAddressFromLatLng(LatLng position) async {
    // Build latlng string outside the map so Dart interpolates it correctly
    final latlng = '${position.latitude},${position.longitude}';
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': latlng,
        'key': _googleApiKey,
        'language': 'en',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            return results.first['formatted_address'] as String? ?? 'Selected location';
          }
        }
      }
    } catch (_) {}
    try {
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) return _formatDetailedAddress(placemarks[0]);
    } catch (_) {}
    return 'Selected location';
  }

  String _formatDetailedAddress(Placemark place) {
    List<String> parts = [];
    String street = '';
    if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
      street = '${place.subThoroughfare} ${place.thoroughfare ?? ''}'.trim();
    } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      street = place.thoroughfare!;
    } else if (place.street != null && place.street!.isNotEmpty) {
      street = place.street!;
    }
    if (street.isNotEmpty) parts.add(street);
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.postalCode?.isNotEmpty == true) parts.add(place.postalCode!);
    if (place.administrativeArea?.isNotEmpty == true)
      parts.add(place.administrativeArea!);
    if (place.country?.isNotEmpty == true) parts.add(place.country!);
    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    final canPerform = await SupabaseService.canPerformActions();
    if (!canPerform) {
      VerificationRequiredPopup.show(context, onVerify: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NIDVerificationPage()));
      });
      return;
    }

    setState(() => _loading = true);
    try {
      // Use first uploaded image (cover) as the main image_url, fallback to placeholder
      String coverUrl =
          'https://images.unsplash.com/photo-1601784551446-20c9e07cdb9b?auto=format&fit=crop&w=800&q=80';

      // ── Upload ALL images first with guaranteed unique filenames ────────
      final baseTs = DateTime.now().millisecondsSinceEpoch;
      final List<String> uploadedUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final bytes = _selectedImages[i]['bytes'] as Uint8List;
        final uniqueName = '\$uid/\${baseTs + i * 1000}_\$i.jpg';
        final url = await _uploadSingleImage(bytes, uniqueName);
        uploadedUrls.add(url);
      }

      // Cover URL: use designated cover image, or placeholder if no images
      if (uploadedUrls.isNotEmpty) coverUrl = uploadedUrls[_coverIndex];

      // Insert the product row
      final inserted = await SupabaseService.client
          .from('products')
          .insert({
        'owner_id': uid,
        'name': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'original_price': _origPriceCtrl.text.isNotEmpty
            ? double.parse(_origPriceCtrl.text)
            : double.parse(_priceCtrl.text),
        'location': _locationCtrl.text.trim(),
        'image_url': coverUrl,
        'category': _selectedCategory,
        'listing_type': _listingType,
        'free_delivery': _freeDelivery,
        'coins_saved': 0.0,
        'coins_save': 0.0,
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
      })
          .select('id')
          .single();

      final productId = inserted['id'] as String;

      // Insert product_images rows (URLs already uploaded)
      for (int i = 0; i < uploadedUrls.length; i++) {
        await SupabaseService.client.from('product_images').insert({
          'product_id': productId,
          'image_url': uploadedUrls[i],
          'is_cover': i == _coverIndex,
          'sort_order': i,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Item listed successfully!'),
            backgroundColor: Color(0xFF381932)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final priceLabel =
    _listingType == 'rent' ? 'Price per day (৳) *' : 'Sell Price (৳) *';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('List New Item'),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Post',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Listing type
              const Text('Listing Type',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _typeButton('rent', 'For Rent', Icons.loop)),
                const SizedBox(width: 12),
                Expanded(child: _typeButton('buy', 'For Sale', Icons.sell)),
              ]),
              const SizedBox(height: 20),

              // ── Multi-image picker ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Product Images',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${_selectedImages.length}/8',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap ★ on an image to set it as the cover photo.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 10),

              // Grid of selected images + add button
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Existing images
                  for (int i = 0; i < _selectedImages.length; i++)
                    _ImageThumb(
                      bytes: _selectedImages[i]['bytes'] as Uint8List,
                      isCover: i == _coverIndex,
                      onSetCover: () => _setCover(i),
                      onRemove: () => _removeImage(i),
                    ),

                  // Add button (shown if < 8 images)
                  if (_selectedImages.length < 8)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: primaryColor.withOpacity(0.4),
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 28, color: primaryColor),
                            const SizedBox(height: 4),
                            Text('Add',
                                style: TextStyle(
                                    fontSize: 11, color: primaryColor)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              _label('Title *'),
              _field(_titleCtrl, 'e.g. Canon EOS 80D DSLR Camera', Icons.title),
              const SizedBox(height: 16),

              _label('Category'),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDec('', Icons.category),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              _label('Description *'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _inputDec(
                    'Describe the item, condition, any extras…', Icons.description),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Description required' : null,
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(priceLabel),
                      _field(_priceCtrl, '0.00', Icons.currency_exchange,
                          isNumber: true),
                    ],
                  ),
                ),
                if (_listingType == 'buy') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Market Price (৳)'),
                        _field(_origPriceCtrl, 'Original price', Icons.money_off,
                            required: false, isNumber: true),
                      ],
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              _label('Location *'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Modina Market, Sylhet',
                      prefixIcon:
                      const Icon(Icons.location_on, color: Colors.grey),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.my_location, color: primaryColor),
                            onPressed: _isMapLoading ? null : _getCurrentLocation,
                            tooltip: 'Use current location',
                          ),
                          IconButton(
                            icon: Icon(Icons.map, color: primaryColor),
                            onPressed: _openMap,
                            tooltip: 'Open map',
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: primaryColor, width: 1.5)),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Location required' : null,
                  ),
                  if (_selectedLocation != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: _openMap,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: primaryColor.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                    target: _selectedLocation!, zoom: 15),
                                markers: {
                                  Marker(
                                      markerId: const MarkerId('selected'),
                                      position: _selectedLocation!),
                                },
                                zoomGesturesEnabled: false,
                                scrollGesturesEnabled: false,
                                tiltGesturesEnabled: false,
                                rotateGesturesEnabled: false,
                                myLocationEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                              ),
                              Container(
                                color: Colors.black12,
                                child: const Center(
                                    child: Icon(Icons.edit_location,
                                        color: Colors.white, size: 30)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  if (_isMapLoading)
                    const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: LinearProgressIndicator()),
                ]),
              ),
              const SizedBox(height: 16),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(children: [
                      Icon(Icons.local_shipping_outlined, color: Colors.grey),
                      SizedBox(width: 12),
                      Text('Free Delivery',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ]),
                    Switch(
                      value: _freeDelivery,
                      onChanged: (v) => setState(() => _freeDelivery = v),
                      activeColor: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Post Listing',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(String type, String label, IconData icon) {
    final sel = _listingType == type;
    return GestureDetector(
      onTap: () => setState(() => _listingType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? primaryColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool required = true, bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _inputDec(hint, icon),
      validator: required
          ? (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isNumber && double.tryParse(v) == null)
          return 'Invalid number';
        return null;
      }
          : (v) {
        if (isNumber &&
            v != null &&
            v.isNotEmpty &&
            double.tryParse(v) == null) return 'Invalid number';
        return null;
      },
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small image thumbnail used in the multi-image picker grid
// ─────────────────────────────────────────────────────────────────────────────
class _ImageThumb extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final Uint8List bytes;
  final bool isCover;
  final VoidCallback onSetCover;
  final VoidCallback onRemove;

  const _ImageThumb({
    required this.bytes,
    required this.isCover,
    required this.onSetCover,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCover ? primaryColor : Colors.grey.shade300,
              width: isCover ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        // Cover star button
        Positioned(
          bottom: 4,
          left: 4,
          child: GestureDetector(
            onTap: onSetCover,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isCover ? primaryColor : Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCover ? Icons.star : Icons.star_border,
                size: 14,
                color: isCover ? Colors.amber : Colors.white,
              ),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
        // "Cover" label badge
        if (isCover)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Cover',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Picker Map (unchanged logic, kept intact)
// ─────────────────────────────────────────────────────────────────────────────
class LocationPickerMap extends StatefulWidget {
  final LatLng? initialLocation;
  final Function(LatLng, String) onLocationSelected;

  const LocationPickerMap({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = true;
  bool _isMovingMap = false;
  bool _isGeocoding = false;

  final loc.Location _location = loc.Location();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _getAddressFromLatLng(_selectedLocation!);
    } else {
      _getCurrentUserLocation();
    }
  }

  Future<void> _getCurrentUserLocation() async {
    setState(() => _isLoading = true);
    try {
      PermissionStatus status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() => _isLoading = false);
        return;
      }
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() => _isLoading = false);
          return;
        }
      }
      loc.LocationData currentLocation = await _location.getLocation();
      LatLng userLocation = LatLng(
          currentLocation.latitude ?? 23.8103,
          currentLocation.longitude ?? 90.4125);
      setState(() {
        _selectedLocation = userLocation;
        _isLoading = false;
      });
      _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
              CameraPosition(target: userLocation, zoom: 15)));
      await _getAddressFromLatLng(userLocation);
    } catch (e) {
      setState(() => _isLoading = false);
      LatLng defaultLocation = const LatLng(23.8103, 90.4125);
      _selectedLocation = defaultLocation;
      await _getAddressFromLatLng(defaultLocation);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isGeocoding = true);
    // Build latlng string outside the map so Dart interpolates it correctly
    final latlng = '${position.latitude},${position.longitude}';
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': latlng,
        'key': _UploadPageState._googleApiKey,
        'language': 'en',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            final address = results.first['formatted_address'] as String? ?? '';
            if (address.isNotEmpty) {
              setState(() { _selectedAddress = address; _isGeocoding = false; });
              return;
            }
          }
        }
      }
    } catch (_) {}
    // Fallback: geocoding package
    try {
      final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() { _selectedAddress = _formatAddress(placemarks[0]); _isGeocoding = false; });
        return;
      }
    } catch (_) {}
    setState(() { _selectedAddress = 'Selected location'; _isGeocoding = false; });
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];
    String street = '';
    if (place.subThoroughfare?.isNotEmpty == true) {
      street = '${place.subThoroughfare} ${place.thoroughfare ?? ''}'.trim();
    } else if (place.thoroughfare?.isNotEmpty == true) {
      street = place.thoroughfare!;
    } else if (place.street?.isNotEmpty == true) {
      street = place.street!;
    }
    if (street.isNotEmpty) parts.add(street);
    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.postalCode?.isNotEmpty == true) parts.add(place.postalCode!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    if (place.country?.isNotEmpty == true) parts.add(place.country!);
    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    if (!_isMovingMap) setState(() => _isMovingMap = true);
    _selectedLocation = position.target;
  }

  void _onCameraIdle() async {
    if (_selectedLocation != null && _isMovingMap) {
      await _getAddressFromLatLng(_selectedLocation!);
      setState(() => _isMovingMap = false);
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null && _selectedAddress.isNotEmpty) {
      widget.onLocationSelected(_selectedLocation!, _selectedAddress);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location on the map')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF381932),
        foregroundColor: Colors.white,
        title: const Text('Select Location'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Stack(children: [
        if (_selectedLocation != null)
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
            CameraPosition(target: _selectedLocation!, zoom: 15),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: {
              if (_selectedLocation != null)
                Marker(
                    markerId: const MarkerId('selected'),
                    position: _selectedLocation!,
                    infoWindow: InfoWindow(title: _selectedAddress)),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
        if (_isLoading || _isGeocoding)
          const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(children: [
                  Icon(Icons.location_on, color: Color(0xFF381932)),
                  SizedBox(width: 8),
                  Text('Selected Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                Text(
                    _selectedAddress.isEmpty
                        ? 'Move map to select location'
                        : _selectedAddress,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _getCurrentUserLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('My Location'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: const Color(0xFF381932)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF381932),
                          foregroundColor: Colors.white),
                      child: const Text('Confirm Location'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}