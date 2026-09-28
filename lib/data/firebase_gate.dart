import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import 'catalog_seed.dart';

class SyncReport {
  const SyncReport({
    required this.firebaseReady,
    required this.syncedIds,
    required this.remoteProducts,
  });

  final bool firebaseReady;
  final List<String> syncedIds;
  final List<Product> remoteProducts;
}

class FirebaseGate {
  static bool ready = false;

  static Future<void> tryInit() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      ready = true;
    } catch (error) {
      ready = false;
      debugPrint('Firebase is not configured. Lumen is using Hive on this device. $error');
    }
  }

  static Future<void> mirrorSignIn({
    required String email,
    required String password,
  }) async {
    if (!ready) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'invalid-credential') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (createError) {
          debugPrint('Firebase auth mirror skipped: $createError');
        }
      }
    } catch (error) {
      debugPrint('Firebase auth mirror skipped: $error');
    }
  }

  static void signOut() {
    if (!ready) return;
    FirebaseAuth.instance.signOut();
  }

  static Future<SyncReport> pushOrders(List<ShopOrder> pending) async {
    if (!ready) {
      return const SyncReport(
        firebaseReady: false,
        syncedIds: [],
        remoteProducts: [],
      );
    }
    final firestore = FirebaseFirestore.instance;
    final synced = <String>[];
    for (final order in pending) {
      await firestore.collection('orders').doc(order.id).set(order.toMap());
      synced.add(order.id);
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseStorage.instance
          .ref('avatars/${user.uid}.json')
          .putString('{"email":"${user.email}"}');
    }
    final snapshot = await firestore.collection('products').get();
    if (snapshot.docs.isEmpty) {
      final batch = firestore.batch();
      for (final product in seedProducts) {
        batch.set(firestore.collection('products').doc(product.id), product.toMap());
      }
      await batch.commit();
      return SyncReport(
        firebaseReady: true,
        syncedIds: synced,
        remoteProducts: seedProducts,
      );
    }
    final remote = snapshot.docs
        .map((doc) => Product.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    return SyncReport(
      firebaseReady: true,
      syncedIds: synced,
      remoteProducts: remote,
    );
  }
}
