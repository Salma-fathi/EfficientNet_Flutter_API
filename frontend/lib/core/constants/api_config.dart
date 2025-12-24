import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  static const String predictEndpoint = '/predict';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration responseTimeout = Duration(seconds: 10);

  static Uri predictUri() => Uri.parse('$baseUrl$predictEndpoint');
}
