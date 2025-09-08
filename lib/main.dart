import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth.dart';

// Dynamic API Base URL - Will be auto-detected
String apiBaseUrl = 'http://localhost:8000'; // Default fallback

// Cache for discovered IP addresses
class ApiCache {
  static const String _cacheKey = 'cached_api_url';
  static const String _timestampKey = 'cache_timestamp';
  static const int _cacheValidityMinutes = 60; // Cache valid for 1 hour

  static Future<String?> getCachedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_timestampKey) ?? 0;

      if (cachedUrl != null && timestamp > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheAge = (now - timestamp) ~/ (1000 * 60); // minutes

        if (cacheAge < _cacheValidityMinutes) {
          debugPrint(
            '📋 Using cached API URL: $cachedUrl (age: ${cacheAge}min)',
          );
          return cachedUrl;
        }
      }
    } catch (e) {
      debugPrint('❌ Cache read error: $e');
    }
    return null;
  }

  static Future<void> setCachedUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, url);
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Cached API URL: $url');
    } catch (e) {
      debugPrint('❌ Cache write error: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
    }
  }
}

// Fast API URL detection with smart optimizations
Future<void> initializeApiUrl() async {
  debugPrint('🚀 Initializing API connection...');

  // Step 1: Try cached URL first
  final cachedUrl = await ApiCache.getCachedUrl();
  if (cachedUrl != null && await _testUrl(cachedUrl)) {
    apiBaseUrl = cachedUrl;
    debugPrint('✅ Using cached server: $apiBaseUrl');
    return;
  }

  // Step 2: Fast device-specific detection
  if (await _tryDeviceSpecificUrls()) return;

  // Step 3: Smart network scan (only if needed)
  await _smartNetworkScan();
}

// Test a single URL with optimized timeout
Future<bool> _testUrl(String url, {int timeoutMs = 500}) async {
  try {
    final response = await http
        .get(Uri.parse('$url/health'))
        .timeout(Duration(milliseconds: timeoutMs));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// Device-specific URL detection (emulator vs real device)
Future<bool> _tryDeviceSpecificUrls() async {
  debugPrint('🔍 Testing device-specific URLs...');

  List<String> deviceUrls;

  if (kIsWeb) {
    // Web platform
    deviceUrls = ['http://localhost:8000', 'http://127.0.0.1:8000'];
  } else if (Platform.isAndroid) {
    // Android - check if emulator or real device
    deviceUrls = [
      'http://172.16.126.109:8000', // Your specific computer IP
      'http://10.0.2.2:8000', // Android emulator
      'http://localhost:8000', // Local fallback
      'http://127.0.0.1:8000', // Localhost fallback
    ];
  } else if (Platform.isIOS) {
    // iOS simulator vs real device
    deviceUrls = [
      'http://172.16.126.109:8000', // Your specific computer IP
      'http://localhost:8000', // iOS simulator
      'http://127.0.0.1:8000', // Localhost fallback
    ];
  } else {
    // Desktop platforms
    deviceUrls = [
      'http://172.16.126.109:8000', // Your specific computer IP
      'http://localhost:8000',
      'http://127.0.0.1:8000',
    ];
  }

  // Test device-specific URLs concurrently
  final futures = deviceUrls.map((url) async {
    if (await _testUrl(url, timeoutMs: 300)) {
      return url;
    }
    return null;
  });

  final results = await Future.wait(futures);

  for (final url in results) {
    if (url != null) {
      apiBaseUrl = url;
      await ApiCache.setCachedUrl(url);
      debugPrint('✅ Found server via device-specific detection: $apiBaseUrl');
      return true;
    }
  }

  return false;
}

// Smart network scan with concurrent testing
Future<void> _smartNetworkScan() async {
  debugPrint('🔍 Starting smart network scan...');

  // Get device's network info for targeted scanning
  final targetRanges = await _getTargetIpRanges();

  // Test common IPs first (highest success probability)
  final commonIps = [
    '172.16.126.109', // Your specific IP address
    '192.168.1.1',
    '192.168.1.100',
    '192.168.1.101',
    '192.168.1.2',
    '192.168.0.1',
    '192.168.0.100',
    '192.168.0.101',
    '192.168.0.2',
    '10.0.0.1',
    '10.0.1.1',
    '172.16.0.1',
  ];

  if (await _testIpsCouncurrently(commonIps, 'common IPs')) return;

  // Scan target ranges concurrently (batches of 20)
  for (final range in targetRanges) {
    debugPrint('🔍 Scanning $range range...');
    if (await _scanRangeConcurrently(range)) return;
  }

  debugPrint('❌ Backend server not found. Using fallback: $apiBaseUrl');
}

// Get likely IP ranges based on device network
Future<List<String>> _getTargetIpRanges() async {
  // In a real implementation, you could get actual device network info
  // For now, return common ranges in order of likelihood
  return [
    '172.16.126',
    '192.168.1',
    '192.168.0',
    '192.168.2',
    '10.0.0',
    '10.0.1',
    '172.16.0',
  ];
}

// Test multiple IPs concurrently
Future<bool> _testIpsCouncurrently(List<String> ips, String description) async {
  debugPrint('🔍 Testing $description...');

  final futures = ips.map((ip) async {
    final url = 'http://$ip:8000';
    if (await _testUrl(url, timeoutMs: 200)) {
      return url;
    }
    return null;
  });

  final results = await Future.wait(futures);

  for (final url in results) {
    if (url != null) {
      apiBaseUrl = url;
      await ApiCache.setCachedUrl(url);
      debugPrint('✅ Found server in $description: $apiBaseUrl');
      return true;
    }
  }

  return false;
}

// Scan IP range concurrently in batches
Future<bool> _scanRangeConcurrently(String range) async {
  const batchSize = 20;

  for (int start = 2; start <= 254; start += batchSize) {
    final end = (start + batchSize - 1).clamp(0, 254);
    final batch = List.generate(end - start + 1, (i) => '$range.${start + i}');

    if (await _testIpsCouncurrently(batch, '$range.$start-$end')) {
      return true;
    }

    // Small delay between batches to prevent overwhelming the network
    await Future.delayed(const Duration(milliseconds: 50));
  }

  return false;
}

// Helper function to handle API errors with better messaging
String getErrorMessage(dynamic error) {
  if (error.toString().contains('Connection refused') ||
      error.toString().contains('Connection timed out')) {
    return 'Cannot connect to server.\n'
        'Current API: $apiBaseUrl\n\n'
        'Quick fixes:\n'
        '• Check if server is running\n'
        '• Ensure phone and computer are on same WiFi\n'
        '• Try restarting the app\n'
        '• Check network connection';
  } else if (error.toString().contains('SocketException')) {
    return 'Network error detected.\n'
        'API: $apiBaseUrl\n\n'
        'Please check:\n'
        '• WiFi connection is stable\n'
        '• Mobile data if needed\n'
        '• Network permissions';
  } else {
    return 'Connection error: $apiBaseUrl\n\n'
        'Details: ${error.toString().length > 100 ? "${error.toString().substring(0, 100)}..." : error.toString()}';
  }
}

// Enhanced HTTP client with retry logic and better error handling
class ApiClient {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  static Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFunction, {
    int retryCount = 0,
  }) async {
    try {
      return await requestFunction();
    } catch (e) {
      if (retryCount < _maxRetries) {
        debugPrint(
          '🔄 Request failed, retrying... (${retryCount + 1}/$_maxRetries)',
        );
        await Future.delayed(_retryDelay);
        return _makeRequest(requestFunction, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _makeRequest(() => http.post(url, headers: headers, body: body));
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return _makeRequest(() => http.get(url, headers: headers));
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SNAPFIX',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _connectionStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Auto-detect API URL during splash screen
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _connectionStatus = 'Connecting to server...';
    });

    // Start API detection in parallel with minimum splash duration
    final apiDetectionFuture = _detectApiWithStatus();
    final splashDelayFuture = Future.delayed(
      const Duration(seconds: 2),
    ); // Reduced from 3 to 2 seconds

    // Wait for both to complete (API detection should usually finish first)
    await Future.wait([apiDetectionFuture, splashDelayFuture]);

    setState(() {
      _connectionStatus = 'Ready!';
    });

    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Brief pause to show "Ready!"

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<void> _detectApiWithStatus() async {
    try {
      setState(() {
        _connectionStatus = 'Checking cached connection...';
      });

      // Try cached URL first
      final cachedUrl = await ApiCache.getCachedUrl();
      if (cachedUrl != null && await _testUrl(cachedUrl)) {
        apiBaseUrl = cachedUrl;
        setState(() {
          _connectionStatus = 'Connected to cached server ✓';
        });
        debugPrint('✅ Connected via cache: $apiBaseUrl');
        return;
      }

      setState(() {
        _connectionStatus = 'Detecting device type...';
      });

      // Try device-specific URLs
      if (await _tryDeviceSpecificUrls()) {
        setState(() {
          _connectionStatus = 'Connected via device detection ✓';
        });
        debugPrint('✅ Connected via device detection: $apiBaseUrl');
        return;
      }

      setState(() {
        _connectionStatus = 'Scanning network...';
      });

      // Smart network scan
      await _smartNetworkScan();

      if (apiBaseUrl.contains('172.16.126.109') ||
          apiBaseUrl.contains('localhost') ||
          apiBaseUrl.contains('127.0.0.1')) {
        setState(() {
          _connectionStatus = 'Connection established ✓';
        });
        debugPrint('✅ Connected to server: $apiBaseUrl');
      } else {
        setState(() {
          _connectionStatus = 'Using fallback connection';
        });
        debugPrint('⚠️ Using fallback: $apiBaseUrl');
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Using fallback connection';
      });
      debugPrint('❌ Connection error: $e');
    }
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
                // Connection status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _connectionStatus.contains('✓')
                                ? Colors.green
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _connectionStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Loading indicator for IP detection
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.0,
                ),
                SizedBox(height: 16),
                Text(
                  'Connecting to server...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
