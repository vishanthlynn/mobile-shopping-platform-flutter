import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/firebase_gate.dart';
import 'data/stores.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveStore.init();
  await FirebaseGate.tryInit();
  runApp(
    ProviderScope(
      overrides: [
        userStoreProvider.overrideWithValue(
          HiveUserStore(Hive.box('users'), Hive.box('session')),
        ),
        cartStoreProvider.overrideWithValue(HiveCartStore(Hive.box('cart'))),
        orderStoreProvider.overrideWithValue(HiveOrderStore(Hive.box('orders'))),
        metaStoreProvider.overrideWithValue(HiveMetaStore(Hive.box('meta'))),
      ],
      child: const LumenApp(),
    ),
  );
}
