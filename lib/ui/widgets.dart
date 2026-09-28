import 'package:flutter/material.dart';

import '../domain/catalog.dart';
import '../domain/models.dart';
import 'theme.dart';

IconData glyphFor(String category) {
  return switch (category) {
    'Apparel' => Icons.checkroom,
    'Home' => Icons.chair_outlined,
    'Beauty' => Icons.spa_outlined,
    'Electronics' => Icons.watch_outlined,
    'Outdoor' => Icons.park_outlined,
    'Pantry' => Icons.restaurant_outlined,
    _ => Icons.shopping_bag_outlined,
  };
}

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    super.key,
    required this.product,
    this.radius = 18,
  });

  final Product product;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, product.hue.toDouble(), 0.42, 0.38).toColor();
    final lift = HSLColor.fromAHSL(1, (product.hue + 18).toDouble(), 0.35, 0.62).toColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lift, base],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(
                glyphFor(product.category),
                size: 120,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            Center(
              child: Icon(
                glyphFor(product.category),
                size: 42,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.heroPrefix = 'card',
  });

  final Product product;
  final VoidCallback onTap;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Hero(
                  tag: '$heroPrefix-${product.id}',
                  child: ProductArtwork(product: product, radius: 14),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.brand.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A7268),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      money(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                  const Icon(Icons.star, size: 14, color: Color(0xFFC6A15B)),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7D7A4)),
      ),
      child: const Text(
        'Offline. Browsing the catalog saved on this device. Cart and orders stay in Hive.',
        style: TextStyle(color: ink, fontSize: 13),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ink,
        ),
      ),
    );
  }
}
