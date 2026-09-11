import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore();
  await store.load();
  runApp(Jx3TasksApp(store: store));
}
