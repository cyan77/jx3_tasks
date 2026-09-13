import 'dart:async';

import 'package:flutter/gestures.dart';
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
        scrollBehavior: const _DesktopScrollBehavior(),
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

class _DesktopScrollBehavior extends MaterialScrollBehavior {
  const _DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this.appState);

  final AppState appState;

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await appState.backupBeforeExit();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appState.checkForNewerBackupWithRetry();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(appState.backupBeforeExit());
    }
  }
}
