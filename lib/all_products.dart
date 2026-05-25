import 'package:flutter/material.dart';
import 'models.dart';
import 'homepage.dart'; // for ProductGridCard

class AllProductsPage extends StatelessWidget {
  final List<Product> products;
  const AllProductsPage({super.key, required this.products});

  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('All Products'),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => ProductGridCard(product: products[index]),
      ),
    );
  }
}