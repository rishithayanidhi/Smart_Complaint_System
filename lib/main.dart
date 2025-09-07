import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      'http://10.0.2.2:8000', // Android emulator
      'http://localhost:8000',
      'http://127.0.0.1:8000',
    ];
  } else if (Platform.isIOS) {
    // iOS simulator vs real device
    deviceUrls = [
      'http://localhost:8000', // iOS simulator
      'http://127.0.0.1:8000',
    ];
  } else {
    // Desktop platforms
    deviceUrls = ['http://localhost:8000', 'http://127.0.0.1:8000'];
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
  return ['192.168.1', '192.168.0', '192.168.2', '10.0.0', '10.0.1'];
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
        return;
      }

      setState(() {
        _connectionStatus = 'Scanning network...';
      });

      // Smart network scan
      await _smartNetworkScan();

      setState(() {
        _connectionStatus = 'Connection established ✓';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Using fallback connection';
      });
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

class CustomTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController controller;
  final Widget? suffix;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscure = false,
    required this.controller,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $hint';
        }
        return null;
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool isLoading = false;

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (!mounted) return; // Check if widget is still mounted

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Debug: Print the response data to understand the structure
        debugPrint('Login response: ${response.body}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${data['user']['full_name']}!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(userData: data['user'])),
        );
      } else {
        // Debug: Print the error response
        debugPrint('Login error response: ${response.body}');
        final errorData = json.decode(response.body);

        // Handle both single string and array of error messages
        String errorMessage = 'Login failed';
        if (errorData['detail'] != null) {
          if (errorData['detail'] is String) {
            errorMessage = errorData['detail'];
          } else if (errorData['detail'] is List) {
            errorMessage = (errorData['detail'] as List).join(', ');
          } else {
            errorMessage = errorData['detail'].toString();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted
      debugPrint('Login error: $e');
      debugPrint('Login error details: ${e.toString()}');

      String errorMessage;
      if (e.toString().contains('is not a subtype of type')) {
        errorMessage =
            'Server response format error. Please try again or contact support.';
      } else {
        errorMessage = getErrorMessage(e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Welcome Back 👋",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          CustomTextField(
                            hint: "Email",
                            icon: Icons.email,
                            controller: _emailController,
                          ),
                          const SizedBox(height: 15),
                          CustomTextField(
                            hint: "Password",
                            icon: Icons.lock,
                            controller: _passwordController,
                            obscure: _obscureText,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: isLoading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator()
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account?",
                                style: TextStyle(color: Colors.white70),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> signUp() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.post(
        Uri.parse('$apiBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
        }),
      );

      if (!mounted) return; // Check if widget is still mounted

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Welcome!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to HomePage with user data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(userData: data['user'])),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return; // Check if widget is still mounted
      debugPrint('Signup error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_add,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          hint: "Full Name",
                          icon: Icons.person,
                          controller: nameController,
                        ),
                        const SizedBox(height: 15),
                        CustomTextField(
                          hint: "Email",
                          icon: Icons.email,
                          controller: emailController,
                        ),
                        const SizedBox(height: 15),
                        CustomTextField(
                          hint: "Password",
                          icon: Icons.lock,
                          controller: passwordController,
                          obscure: true,
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: isLoading ? null : signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurple,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account?",
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNAPFIX'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Text(
                              userData['full_name']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                Text(
                                  userData['full_name'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  userData['email'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      _buildActionCard(
                        context,
                        icon: Icons.person,
                        title: 'Profile',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile page coming soon!'),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        context,
                        icon: Icons.settings,
                        title: 'Settings',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings page coming soon!'),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        context,
                        icon: Icons.help,
                        title: 'Help',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Help page coming soon!'),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        context,
                        icon: Icons.info,
                        title: 'About',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('About page coming soon!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
