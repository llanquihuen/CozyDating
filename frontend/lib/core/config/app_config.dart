import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Configuración centralizada de entornos (Local vs Producción)
class AppConfig {
  // URLs del Servidor de Producción (AWS Lightsail)
  static const String prodBaseUrl = 'https://dating.llanq.cl';
  static const String prodWsUrl = 'wss://dating.llanq.cl/game';

  /// URL Base HTTP (REST API)
  /// - En Release (APK generado): https://dating.llanq.cl
  /// - En Debug (Pruebas locales): http://10.0.2.2:8080 (Emulador Android) o http://localhost:8080 (Web/PC)
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kReleaseMode) {
      return prodBaseUrl;
    }

    if (kIsWeb) return 'http://localhost:8080';
    return Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }

  /// URL WebSocket
  /// - En Release (APK generado): wss://dating.llanq.cl/game
  /// - En Debug (Pruebas locales): ws://10.0.2.2:8080/game o ws://localhost:8080/game
  static String get wsUrl {
    const envWs = String.fromEnvironment('WS_URL');
    if (envWs.isNotEmpty) return envWs;

    if (kReleaseMode) {
      return prodWsUrl;
    }

    if (kIsWeb) return 'ws://localhost:8080/game';
    return Platform.isAndroid ? 'ws://10.0.2.2:8080/game' : 'ws://localhost:8080/game';
  }
}
