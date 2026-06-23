import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../lib/firebase_options.dart';
import '../lib/shared/data/datasources/firestore/firestore_datasource.dart';

/// Firestore menü/şube katalogunu MockData ile doldurur (ürün yoksa).
/// flutter run -t tool/reseed_firestore_catalog.dart -d windows --dart-define=USE_MOCK_API=false
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirestoreDataSource();
  await firestore.ensureSeeded();
  final products = await firestore.getProducts();
  final branches = await firestore.getBranches();
  // ignore: avoid_print
  print('Katalog yenilendi: ${products.length} ürün, ${branches.length} şube.');
}
