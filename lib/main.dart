import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  LocalStore? store;
  Object? loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loadError = null);
    final nextStore = LocalStore();
    try {
      await nextStore.load();
      if (mounted) setState(() => store = nextStore);
    } catch (error) {
      if (mounted) setState(() => loadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadedStore = store;
    if (loadedStore != null) return Jx3TasksApp(store: loadedStore);
    return MaterialApp(
      title: '角色日程',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _LaunchScreen(
        error: loadError,
        onRetry: _load,
      ),
    );
  }
}

class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> scale = Tween(begin: 0.96, end: 1.0).animate(
    CurvedAnimation(parent: controller, curve: Curves.easeInOut),
  );
  late final Animation<double> opacity = Tween(begin: 0.78, end: 1.0).animate(
    CurvedAnimation(parent: controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = Color.lerp(
      scheme.surface,
      scheme.primaryContainer,
      dark ? 0.24 : 0.42,
    )!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: dark ? 0.86 : 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: scheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/icon/jx3_tasks_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '角色日程',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    widget.error == null
                        ? '正在整理角色与任务…'
                        : '加载数据时遇到问题',
                    key: ValueKey(widget.error == null),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.error == null)
                  SizedBox(
                    width: 88,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: scheme.primaryContainer,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新加载'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
