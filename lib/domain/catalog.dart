import 'models.dart';

enum SortOption { featured, priceLow, priceHigh, rating }

class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating = 0,
    this.sort = SortOption.featured,
  });

  final String text;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final double minRating;
  final SortOption sort;

  int get activeFilterCount {
    var count = 0;
    if (category != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minRating > 0) count++;
    if (sort != SortOption.featured) count++;
    return count;
  }

  CatalogQuery copyWith({
    String? text,
    String? category,
    bool clearCategory = false,
    double? minPrice,
    double? maxPrice,
    bool clearPrice = false,
    double? minRating,
    SortOption? sort,
  }) {
    return CatalogQuery(
      text: text ?? this.text,
      category: clearCategory ? null : (category ?? this.category),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
    );
  }
}

class PageSlice<T> {
  const PageSlice({
    required this.items,
    required this.hasMore,
    required this.nextPage,
  });

  final List<T> items;
  final bool hasMore;
  final int nextPage;
}

PageSlice<T> slicePage<T>(List<T> all, int page, int pageSize) {
  if (page < 0 || pageSize <= 0) {
    return const PageSlice(items: [], hasMore: false, nextPage: 0);
  }
  final start = page * pageSize;
  if (start >= all.length) {
    return PageSlice(items: const [], hasMore: false, nextPage: page);
  }
  final end = start + pageSize > all.length ? all.length : start + pageSize;
  return PageSlice(
    items: all.sublist(start, end),
    hasMore: end < all.length,
    nextPage: page + 1,
  );
}

List<Product> applyCatalogQuery(List<Product> source, CatalogQuery query) {
  final needle = query.text.trim().toLowerCase();
  final filtered = source.where((product) {
    if (needle.isNotEmpty) {
      final haystack =
          '${product.name} ${product.brand} ${product.category} ${product.description}'
              .toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    if (query.category != null && product.category != query.category) {
      return false;
    }
    if (query.minPrice != null && product.price < query.minPrice!) return false;
    if (query.maxPrice != null && product.price > query.maxPrice!) return false;
    if (product.rating < query.minRating) return false;
    return true;
  }).toList();

  switch (query.sort) {
    case SortOption.priceLow:
      filtered.sort((a, b) => a.price.compareTo(b.price));
    case SortOption.priceHigh:
      filtered.sort((a, b) => b.price.compareTo(a.price));
    case SortOption.rating:
      filtered.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    case SortOption.featured:
      filtered.sort((a, b) {
        final byFeature = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
        if (byFeature != 0) return byFeature;
        return b.rating.compareTo(a.rating);
      });
  }
  return filtered;
}

List<Product> mergeCatalog(List<Product> local, List<Product> remote) {
  if (remote.isEmpty) return List<Product>.from(local);
  final merged = {for (final product in local) product.id: product};
  for (final product in remote) {
    merged[product.id] = product;
  }
  return merged.values.toList();
}

List<CartLine> upsertLine(List<CartLine> lines, Product product, int quantity) {
  if (quantity <= 0) return List<CartLine>.from(lines);
  final next = List<CartLine>.from(lines);
  final index = next.indexWhere((line) => line.productId == product.id);
  if (index == -1) {
    next.add(CartLine.fromProduct(product, quantity: quantity));
    return next;
  }
  next[index] = next[index].copyWith(quantity: next[index].quantity + quantity);
  return next;
}

List<CartLine> setQuantity(List<CartLine> lines, String productId, int quantity) {
  if (quantity <= 0) {
    return lines.where((line) => line.productId != productId).toList();
  }
  return lines
      .map((line) => line.productId == productId
          ? line.copyWith(quantity: quantity)
          : line)
      .toList();
}

int reservedQuantity(List<CartLine> lines, String productId) {
  return lines
      .where((line) => line.productId == productId)
      .fold(0, (sum, line) => sum + line.quantity);
}

PriceBreakdown priceLines(
  List<CartLine> lines, {
  double freeShippingAt = 75,
  double shippingFee = 6.5,
  double taxRate = 0.08,
}) {
  final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
  final shipping =
      subtotal == 0 || subtotal >= freeShippingAt ? 0.0 : shippingFee;
  final tax = _roundMoney(subtotal * taxRate);
  return PriceBreakdown(
    subtotal: _roundMoney(subtotal),
    shipping: shipping,
    tax: tax,
  );
}

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

String money(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2).split('.');
  final whole = fixed[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${negative ? '-' : ''}\$${buffer.toString()}.${fixed[1]}';
}
