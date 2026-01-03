import 'dart:io' show Platform;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'register.dart';
import 'Home.dart';
import 'init_locations.dart';
import 'init_hotels.dart';
import 'user_session.dart';
import 'forgotpw.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for web and mobile platforms
  try {
    if (kIsWeb) {
      // For web, Firebase is initialized via index.html scripts
      // Just call initializeApp() - it will use the config from index.html
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCcgpc2gS2ggoc2W2fCXqAQQPX49BgloYo',
          appId: '1:818221643846:web', // Simplified - Firebase will work with this
          messagingSenderId: '818221643846',
          projectId: 'david-523db',
          authDomain: 'david-523db.firebaseapp.com',
          storageBucket: 'david-523db.firebasestorage.app',
        ),
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms (Android/iOS)
      // Firebase will automatically read configuration from:
      // - android/app/google-services.json (for Android)
      // - ios/Runner/GoogleService-Info.plist (for iOS)
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully for ${Platform.isAndroid ? "Android" : "iOS"}');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue running even if Firebase fails to initialize
  }
  
  // Khởi tạo dữ liệu địa điểm nếu chưa có
  try {
    await initializeLocations();
  } catch (e) {
    debugPrint('Error initializing locations: $e');
  }
  
  // Khởi tạo dữ liệu Hotels và Rooms nếu chưa có
  try {
    await initializeHotelsAndRooms();
  } catch (e) {
    debugPrint('Error initializing hotels and rooms: $e');
  }
  
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Room Booking App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Handle sign in
  Future<void> _handleSignIn() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Vui lòng nhập email');
      return;
    }
    if (!_emailController.text.trim().contains('@')) {
      _showErrorSnackBar('Vui lòng nhập email hợp lệ');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('Vui lòng nhập mật khẩu');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if Firebase is initialized
      try {
        Firebase.app();
      } catch (e) {
        _showErrorSnackBar(
          'Firebase chưa được khởi tạo. Vui lòng kiểm tra cấu hình.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get Firestore instance
      final firestore = FirebaseFirestore.instance;

      // Hash the password
      final hashedPassword = _hashPassword(_passwordController.text);

      // Check if user exists with matching email and password
      final userQuery = await firestore
          .collection('Users')
          .where('email', isEqualTo: _emailController.text.trim().toLowerCase())
          .where('password', isEqualTo: hashedPassword)
          .get();

      if (userQuery.docs.isEmpty) {
        _showErrorSnackBar('Email hoặc mật khẩu không đúng');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Login successful - navigate to Home screen
      if (mounted) {
        // Save user email to session
        final userEmail = _emailController.text.trim().toLowerCase();
        UserSession.setUserEmail(userEmail);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi đăng nhập: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top blue section with back arrow
            Container(
              height: MediaQuery.of(context).size.height * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A), // Dark blue
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A8A),
                    const Color(0xFF3B82F6),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Diagonal pattern overlay
                  CustomPaint(
                    painter: DiagonalPatternPainter(),
                    child: Container(),
                  ),
                  // Back arrow
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        // Handle back button
                      },
                    ),
                  ),
                ],
              ),
            ),
            // White card section
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Welcome back title
                      const Text(
                        'App Booking Room ',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A8A),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A8A),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Remember me and Forgot password row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B59B6), // Light purple
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Sign up button
                      Center(
                        child: TextButton(

                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Không có tài khoản? Đăng ký ngay',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,

                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for diagonal pattern overlay
class DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2;

    const spacing = 20.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
