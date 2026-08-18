import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/auth/auth_service.dart';
import 'core/crypto/crypto_service.dart';
import 'core/crypto/key_manager.dart';
import 'core/sync/sync_provider.dart';
import 'features/settings/application/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  final authService = FirebaseAuthService();
  await authService.initialize();

  final cryptoService = DefaultCryptoService();
  final keyManager = SecureKeyManager(cryptoService: cryptoService);
  await keyManager.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(authService),
        cryptoServiceProvider.overrideWithValue(cryptoService),
        keyManagerProvider.overrideWithValue(keyManager),
      ],
      child: const QuietPaperApp(),
    ),
  );
}
