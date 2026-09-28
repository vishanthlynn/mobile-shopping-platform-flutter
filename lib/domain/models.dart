class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.description,
    required this.hue,
    this.compareAt,
    this.stock = 18,
    this.featured = false,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final double price;
  final double? compareAt;
  final double rating;
  final int reviewCount;
  final String description;
  final int hue;
  final int stock;
  final bool featured;

  bool get onSale => compareAt != null && compareAt! > price;

  Product copyWithPrice(double nextPrice) {
    return Product(
      id: id,
      name: name,
      brand: brand,
      category: category,
      price: nextPrice,
      compareAt: compareAt,
      rating: rating,
      reviewCount: reviewCount,
      description: description,
      hue: hue,
      stock: stock,
      featured: featured,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'price': price,
        'compareAt': compareAt,
        'rating': rating,
        'reviewCount': reviewCount,
        'description': description,
        'hue': hue,
        'stock': stock,
        'featured': featured,
      };

  factory Product.fromMap(Map<dynamic, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      price: (map['price'] as num).toDouble(),
      compareAt: (map['compareAt'] as num?)?.toDouble(),
      rating: (map['rating'] as num).toDouble(),
      reviewCount: (map['reviewCount'] as num).toInt(),
      description: map['description'] as String,
      hue: (map['hue'] as num).toInt(),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      featured: map['featured'] == true,
    );
  }
}

class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.brand,
    required this.category,
    required this.unitPrice,
    required this.hue,
    required this.quantity,
  });

  final String productId;
  final String name;
  final String brand;
  final String category;
  final double unitPrice;
  final int hue;
  final int quantity;

  double get lineTotal => unitPrice * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      productId: productId,
      name: name,
      brand: brand,
      category: category,
      unitPrice: unitPrice,
      hue: hue,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartLine.fromProduct(Product product, {int quantity = 1}) {
    return CartLine(
      productId: product.id,
      name: product.name,
      brand: product.brand,
      category: product.category,
      unitPrice: product.price,
      hue: product.hue,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'brand': brand,
        'category': category,
        'unitPrice': unitPrice,
        'hue': hue,
        'quantity': quantity,
      };

  factory CartLine.fromMap(Map<dynamic, dynamic> map) {
    return CartLine(
      productId: map['productId'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      hue: (map['hue'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
    );
  }
}

class Address {
  const Address({
    required this.fullName,
    required this.line1,
    required this.city,
    required this.region,
    required this.postalCode,
  });

  final String fullName;
  final String line1;
  final String city;
  final String region;
  final String postalCode;

  String get summary => '$line1, $city, $region $postalCode';

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'line1': line1,
        'city': city,
        'region': region,
        'postalCode': postalCode,
      };

  factory Address.fromMap(Map<dynamic, dynamic> map) {
    return Address(
      fullName: map['fullName'] as String,
      line1: map['line1'] as String,
      city: map['city'] as String,
      region: map['region'] as String,
      postalCode: map['postalCode'] as String,
    );
  }
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    required this.shipping,
    required this.tax,
  });

  final double subtotal;
  final double shipping;
  final double tax;

  double get total => subtotal + shipping + tax;

  Map<String, dynamic> toMap() => {
        'subtotal': subtotal,
        'shipping': shipping,
        'tax': tax,
      };

  factory PriceBreakdown.fromMap(Map<dynamic, dynamic> map) {
    return PriceBreakdown(
      subtotal: (map['subtotal'] as num).toDouble(),
      shipping: (map['shipping'] as num).toDouble(),
      tax: (map['tax'] as num).toDouble(),
    );
  }
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.createdAt,
    required this.lines,
    required this.pricing,
    required this.paymentMethod,
    required this.paymentReference,
    required this.address,
    required this.synced,
  });

  final String id;
  final DateTime createdAt;
  final List<CartLine> lines;
  final PriceBreakdown pricing;
  final String paymentMethod;
  final String paymentReference;
  final Address address;
  final bool synced;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  ShopOrder copyWith({bool? synced}) {
    return ShopOrder(
      id: id,
      createdAt: createdAt,
      lines: lines,
      pricing: pricing,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      address: address,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((line) => line.toMap()).toList(),
        'pricing': pricing.toMap(),
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'address': address.toMap(),
        'synced': synced,
      };

  factory ShopOrder.fromMap(Map<dynamic, dynamic> map) {
    return ShopOrder(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lines: (map['lines'] as List)
          .map((line) => CartLine.fromMap(line as Map))
          .toList(),
      pricing: PriceBreakdown.fromMap(map['pricing'] as Map),
      paymentMethod: map['paymentMethod'] as String,
      paymentReference: map['paymentReference'] as String,
      address: Address.fromMap(map['address'] as Map),
      synced: map['synced'] == true,
    );
  }
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'L';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
      };

  factory UserAccount.fromMap(Map<dynamic, dynamic> map) {
    return UserAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
    );
  }
}

class AuthResult {
  const AuthResult.success(this.user) : message = null;
  const AuthResult.failure(this.message) : user = null;

  final UserAccount? user;
  final String? message;

  bool get ok => user != null;
}
