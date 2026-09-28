import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'crypto_util.dart';

const demoEmail = 'demo@lumen.market';
const demoPassword = 'lumen123';
const demoName = 'Avery Chen';

abstract class UserStore {
  Map<String, dynamic>? readUser(String email);
  void writeUser(String email, Map<String, dynamic> json);
  Map<String, dynamic>? readSession();
  void writeSession(Map<String, dynamic>? json);
}

abstract class CartStore {
  List<CartLine> load();
  void save(List<CartLine> lines);
}

abstract class OrderStore {
  List<ShopOrder> load();
  void save(List<ShopOrder> orders);
}

abstract class MetaStore {
  T? get<T>(String key);
  void put(String key, Object? value);
}

class MemoryUserStore implements UserStore {
  final Map<String, Map<String, dynamic>> users = {};
  Map<String, dynamic>? session;

  @override
  Map<String, dynamic>? readUser(String email) => users[email.trim().toLowerCase()];

  @override
  void writeUser(String email, Map<String, dynamic> json) {
    users[email.trim().toLowerCase()] = json;
  }

  @override
  Map<String, dynamic>? readSession() => session;

  @override
  void writeSession(Map<String, dynamic>? json) => session = json;
}

class MemoryCartStore implements CartStore {
  List<CartLine> lines = [];

  @override
  List<CartLine> load() => List<CartLine>.from(lines);

  @override
  void save(List<CartLine> next) => lines = List<CartLine>.from(next);
}

class MemoryOrderStore implements OrderStore {
  List<ShopOrder> orders = [];

  @override
  List<ShopOrder> load() => List<ShopOrder>.from(orders);

  @override
  void save(List<ShopOrder> next) => orders = List<ShopOrder>.from(next);
}

class MemoryMetaStore implements MetaStore {
  final Map<String, Object?> values = {};

  @override
  T? get<T>(String key) => values[key] as T?;

  @override
  void put(String key, Object? value) => values[key] = value;
}

class HiveUserStore implements UserStore {
  HiveUserStore(this.users, this.session);

  final Box<dynamic> users;
  final Box<dynamic> session;

  @override
  Map<String, dynamic>? readUser(String email) {
    final raw = users.get(email.trim().toLowerCase());
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  @override
  void writeUser(String email, Map<String, dynamic> json) {
    users.put(email.trim().toLowerCase(), json);
  }

  @override
  Map<String, dynamic>? readSession() {
    final raw = session.get('user');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  @override
  void writeSession(Map<String, dynamic>? json) {
    if (json == null) {
      session.delete('user');
    } else {
      session.put('user', json);
    }
  }
}

class HiveCartStore implements CartStore {
  HiveCartStore(this.box);

  final Box<dynamic> box;

  @override
  List<CartLine> load() {
    final raw = box.get('lines');
    if (raw is! List) return [];
    return raw.whereType<Map>().map(CartLine.fromMap).toList();
  }

  @override
  void save(List<CartLine> lines) {
    box.put('lines', lines.map((line) => line.toMap()).toList());
  }
}

class HiveOrderStore implements OrderStore {
  HiveOrderStore(this.box);

  final Box<dynamic> box;

  @override
  List<ShopOrder> load() {
    final raw = box.get('orders');
    if (raw is! List) return [];
    return raw.whereType<Map>().map(ShopOrder.fromMap).toList();
  }

  @override
  void save(List<ShopOrder> orders) {
    box.put('orders', orders.map((order) => order.toMap()).toList());
  }
}

class HiveMetaStore implements MetaStore {
  HiveMetaStore(this.box);

  final Box<dynamic> box;

  @override
  T? get<T>(String key) => box.get(key) as T?;

  @override
  void put(String key, Object? value) {
    if (value == null) {
      box.delete(key);
    } else {
      box.put(key, value);
    }
  }
}

class HiveStore {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>('users'),
      Hive.openBox<dynamic>('session'),
      Hive.openBox<dynamic>('cart'),
      Hive.openBox<dynamic>('orders'),
      Hive.openBox<dynamic>('meta'),
    ]);
    ensureDemoUser(HiveUserStore(Hive.box('users'), Hive.box('session')));
  }
}

void ensureDemoUser(UserStore store) {
  if (store.readUser(demoEmail) != null) return;
  store.writeUser(demoEmail, {
    'id': 'user-demo',
    'name': demoName,
    'email': demoEmail,
    'passwordHash': hashPassword(demoPassword),
  });
}

String newId(String prefix) => '$prefix-${const Uuid().v4().substring(0, 8)}';
