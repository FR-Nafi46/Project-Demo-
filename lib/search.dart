import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'supabase_service.dart';
import 'product_detail.dart';

class SearchPage extends StatefulWidget {
  final String? query;
  const SearchPage({super.key, this.query});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);
  static const int _maxHistory = 5; // Maximum search history entries

  final TextEditingController _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _searching = false;
  String _lastQuery = '';
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.query != null) {
      _ctrl.text = widget.query!;
      _search(widget.query!);
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = List<String>.from(_searchHistory);
    list.removeWhere((e) => e == query);
    list.insert(0, query);
    // Keep only the last _maxHistory items
    if (list.length > _maxHistory) {
      list.removeRange(_maxHistory, list.length);
    }
    await prefs.setStringList('search_history', list);
    setState(() => _searchHistory = list);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }
    await _saveHistory(query);
    setState(() {
      _searching = true;
      _lastQuery = query;
    });
    try {
      final data = await SupabaseService.fetchProducts();
      final q = query.toLowerCase();
      final filtered = data
          .map((m) => Product.fromMap(m))
          .where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q) ||
          (p.category?.toLowerCase().contains(q) ?? false) ||
          (p.description?.toLowerCase().contains(q) ?? false))
          .toList();
      setState(() {
        _results = filtered;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> newList = List<String>.from(_searchHistory)
      ..removeWhere((e) => e == query);
    await prefs.setStringList('search_history', newList);
    setState(() => _searchHistory = newList);
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', []);
    setState(() => _searchHistory = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search items, categories, locations…',
            hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (_lastQuery.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ctrl.clear();
                  _search('');
                }),
        ],
      ),
      body: _lastQuery.isEmpty
          ? _searchHistory.isEmpty
          ? Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Search for products',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text('Try "bike", "camera", "Dhaka"…',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500)),
            ]),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent searches (${_searchHistory.length}/$_maxHistory)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                TextButton(
                  onPressed: _clearAllHistory,
                  child: Text('Clear all',
                      style: TextStyle(
                          fontSize: 12,
                          color: primaryColor)),
                ),
              ],
            ),
          ),
          // Show max _maxHistory items
          ..._searchHistory.take(_maxHistory).map((q) => ListTile(
            leading: const Icon(Icons.history, size: 20),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _removeFromHistory(q),
            ),
            onTap: () {
              _ctrl.text = q;
              _search(q);
            },
          )),
        ],
      )
          : _searching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('No results for "$_lastQuery"',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600)),
            ]),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12),
        itemCount: _results.length,
        itemBuilder: (_, i) =>
            _SearchCard(product: _results[i]),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final Product product;

  const _SearchCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    product.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.grey.shade300,
                        child:
                        const Icon(Icons.broken_image, size: 30)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('৳${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                if (product.listingType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        product.listingType == 'rent' ? 'Rent' : 'Buy',
                        style: const TextStyle(
                            fontSize: 10,
                            color: primaryColor,
                            fontWeight: FontWeight.w500)),
                  ),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.location_on,
                      size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 2),
                  Expanded(
                      child: Text(product.shortLocation,   // <-- CHANGED to shortLocation
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis)),
                ]),
              ]),
        ),
      ),
    );
  }
}