import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth.dart';

// ===================================================
// 1️⃣  Base URL Configuration
// ===================================================

String apiBaseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://snapfix-backend.onrender.com',
);

// Optional cache for faster reconnects
class ApiCache {
  static const String _cacheKey = 'cached_api_url';
  static Future<String?> getCachedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, url);
    } catch (_) {}
  }
}

// ===================================================
// 2️⃣  Backend health check
// ===================================================

Future<bool> checkBackendHealth({int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      final resp = await http
          .get(Uri.parse('$apiBaseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        return true;
      }
    } catch (_) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }
  return false;
}

// ===================================================
// 3️⃣  Global API client with retry logic
// ===================================================

class ApiClient {
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  static Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFn, {
    int retry = 0,
  }) async {
    try {
      return await requestFn().timeout(_timeout);
    } catch (e) {
      if (retry < _maxRetries) {
        debugPrint('🔁 Retrying request (${retry + 1})...');
        await Future.delayed(const Duration(milliseconds: 500));
        return _makeRequest(requestFn, retry: retry + 1);
      }
      rethrow;
    }
  }

  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    return _makeRequest(() => http.get(uri, headers: headers));
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    return _makeRequest(() => http.post(uri, headers: headers, body: body));
  }
}

// ===================================================
// 4️⃣  App Entry
// ===================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    apiBaseUrl = dotenv.env['API_BASE_URL'] ?? apiBaseUrl;
  } catch (e) {
    debugPrint('⚠️ .env not found, using default API base.');
  }

  runApp(const MyApp());
}

// ===================================================
// 5️⃣  Root App
// ===================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapFix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const SplashScreen(),
    );
  }
}

// ===================================================
// 6️⃣  Splash Screen (server check + transition)
// ===================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _status = 'Starting...';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _status = 'Connecting to server...');
    final isHealthy = await checkBackendHealth();

    if (isHealthy) {
      setState(() => _status = 'Connected ✓');
      await ApiCache.setCachedUrl(apiBaseUrl);
    } else {
      setState(() => _status = 'Server unreachable ⚠️');
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'SNAPFIX',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your trusted repair companion',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                _statusWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusWidget() {
    final color = _status.contains('✓')
        ? Colors.greenAccent
        : _status.contains('⚠️')
        ? Colors.amberAccent
        : Colors.white;

    return Column(
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(color),
          strokeWidth: 2,
        ),
        const SizedBox(height: 16),
        Text(
          _status,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
