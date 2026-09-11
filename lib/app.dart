import 'package:flutter/material.dart';

import 'data/local_store.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/home_shell.dart';

class Jx3TasksApp extends StatefulWidget {
  const Jx3TasksApp({required this.store, super.key});

  final LocalStore store;

  @override
  State<Jx3TasksApp> createState() => _Jx3TasksAppState();
}

class _Jx3TasksAppState extends State<Jx3TasksApp> {
  late final AppState state = AppState(widget.store);
  late final _AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _AppLifecycleObserver(state);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, child) => MaterialApp(
        title: 'JX3 Tasks',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomeShell(state: state),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    state.dispose();
    super.dispose();
  }
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this.appState);

  final AppState appState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appState.checkAutoSync();
    }
  }
}
