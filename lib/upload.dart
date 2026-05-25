import 'package:flutter/material.dart';
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
  final _imageUrlCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  String _listingType = 'rent';
  bool _freeDelivery = false;
  bool _loading = false;

  final List<String> _categories = ['Electronics', 'Furniture', 'Vehicles', 'Fashion', 'Sports', 'Books', 'Other'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _origPriceCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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

    setState(() => _loading = true);
    try {
      await SupabaseService.insertProduct({
        'owner_id': uid,
        'name': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'original_price': _origPriceCtrl.text.isNotEmpty ? double.parse(_origPriceCtrl.text) : double.parse(_priceCtrl.text),
        'location': _locationCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim().isEmpty
            ? 'https://images.unsplash.com/photo-1601784551446-20c9e07cdb9b?auto=format&fit=crop&w=800&q=80'
            : _imageUrlCtrl.text.trim(),
        'category': _selectedCategory,
        'listing_type': _listingType,
        'free_delivery': _freeDelivery,
        'coins_saved': 0.0,
        'coins_save': 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item listed successfully!'), backgroundColor: Color(0xFF381932)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('List New Item'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
              // Listing type toggle
              const Text('Listing Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _typeButton('rent', 'For Rent', Icons.loop)),
                  const SizedBox(width: 12),
                  Expanded(child: _typeButton('buy', 'For Sale', Icons.sell)),
                ],
              ),
              const SizedBox(height: 20),

              _label('Image URL (optional)'),
              _field(_imageUrlCtrl, 'https://... (leave blank for default)', Icons.image, required: false),
              const SizedBox(height: 16),

              _label('Title *'),
              _field(_titleCtrl, 'e.g. Canon EOS 80D DSLR Camera', Icons.title),
              const SizedBox(height: 16),

              _label('Category'),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDec('', Icons.category),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              _label('Description *'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: _inputDec('Describe the item, condition, any extras…', Icons.description),
                validator: (v) => (v == null || v.isEmpty) ? 'Description required' : null,
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Price (৳) *'),
                  _field(_priceCtrl, 'Per day/week', Icons.currency_exchange, isNumber: true),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Original Price (৳)'),
                  _field(_origPriceCtrl, 'Market price', Icons.money_off, required: false, isNumber: true),
                ])),
              ]),
              const SizedBox(height: 16),

              _label('Location *'),
              _field(_locationCtrl, 'e.g. Dhaka, Mirpur', Icons.location_on),
              const SizedBox(height: 16),

              // Free delivery toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      Text('Free Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Post Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          border: Border.all(color: sel ? primaryColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: sel ? Colors.white : Colors.grey, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
        if (isNumber && double.tryParse(v) == null) return 'Invalid number';
        return null;
      }
          : (v) {
        if (isNumber && v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Invalid number';
        return null;
      },
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
  );
}