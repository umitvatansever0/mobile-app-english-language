import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

/// İlk karede hemen bir yükleme ekranı gösterir; başlatma hata verirse
/// hatayı ekranda gösterir (sessizce takılı kalmak yerine).
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  AppState? _state;
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) {
      setState(() {
        _error = null;
        _stack = null;
      });
    }
    try {
      final s = await AppState.load().timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _state = s);
    } catch (e, st) {
      debugPrint('Başlatma hatası: $e\n$st');
      if (mounted) {
        setState(() {
          _error = e;
          _stack = st;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s != null) return ChangeNotifierProvider.value(value: s, child: const KartlarApp());
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.danger),
                      const SizedBox(height: 12),
                      const Text('Uygulama başlatılamadı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: SelectableText('$_error\n\n${_stack ?? ''}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Tekrar dene')),
                    ]),
                  ),
          ),
        ),
      ),
    );
  }
}

class KartlarApp extends StatelessWidget {
  const KartlarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: app.themeMode,
      home: app.onboardingDone ? const ShellScreen() : const OnboardingScreen(),
    );
  }
}
