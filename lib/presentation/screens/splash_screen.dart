import '../../core/imports/app_imports.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/user_data.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'staff/staff_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('🚀 [SPLASH] initState called - starting navigation check');
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) {
        print('⚠️ [SPLASH] Widget not mounted, skipping navigation');
        return;
      }

      print('🔍 [SPLASH] Checking first launch and authentication...');
      final isFirstLaunch =
          StorageService.getBool(AppConstants.isFirstLaunchKey) ?? true;
      final token = StorageService.getString(AppConstants.tokenKey);

      print(
        '📊 [SPLASH] isFirstLaunch: $isFirstLaunch, hasToken: ${token != null && token.isNotEmpty}',
      );

      if (isFirstLaunch) {
        print('📱 [SPLASH] First launch - navigating to onboarding');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
        return;
      }

      if (token != null && token.isNotEmpty) {
        print('🔑 [SPLASH] Token found, validating...');
        // Load app state snapshot
        try {
          ApiService.setToken(token);

          // Try to load from storage first (snapshot)
          final userJson = StorageService.getString(AppConstants.userKey);
          if (userJson != null) {
            try {
              final user = UserData.fromJson(jsonDecode(userJson));
              print('👤 [SPLASH] User loaded from snapshot: ${user.role}');

              // Navigate based on role from snapshot
              if (!mounted) return;

              if (user.role == AppConstants.roleAdmin) {
                print('👑 [SPLASH] Navigating to Admin Dashboard');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
                return;
              } else if (user.role == 'staff') {
                print('👔 [SPLASH] Navigating to Staff Dashboard');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffDashboardScreen(),
                  ),
                );
                return;
              } else {
                print('🏠 [SPLASH] Navigating to Home Screen');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
                return;
              }
            } catch (e) {
              print('❌ [SPLASH] Error parsing snapshot user: $e');
              // If snapshot parsing fails, continue to API validation
            }
          }

          // If snapshot fails, try API with timeout
          print('🌐 [SPLASH] Validating token with API...');
          try {
            final response = await ApiService.get('/auth/me')
                .timeout(const Duration(seconds: 5))
                .catchError((error) {
                  print('⏱️ [SPLASH] API call error: $error');
                  return {'success': false, 'message': 'Request failed'};
                });

            if (response['success'] == true &&
                response['data']?['user'] != null) {
              final user = UserData.fromJson(response['data']['user']);
              print('✅ [SPLASH] User validated: ${user.role}');

              // Save snapshot
              await StorageService.setString(
                AppConstants.userKey,
                jsonEncode(user.toJson()),
              );

              if (!mounted) return;

              if (user.role == AppConstants.roleAdmin) {
                print('👑 [SPLASH] Navigating to Admin Dashboard');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
              } else if (user.role == 'staff') {
                print('👔 [SPLASH] Navigating to Staff Dashboard');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffDashboardScreen(),
                  ),
                );
              } else {
                print('🏠 [SPLASH] Navigating to Home Screen');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
              return;
            } else {
              print(
                '⚠️ [SPLASH] Token validation failed: ${response['message']}',
              );
              // Clear invalid token
              await StorageService.remove(AppConstants.tokenKey);
              await StorageService.remove(AppConstants.userKey);
              ApiService.setToken(null);
            }
          } catch (e) {
            print('❌ [SPLASH] API validation error: $e');
            // Clear invalid token on error
            await StorageService.remove(AppConstants.tokenKey);
            await StorageService.remove(AppConstants.userKey);
            ApiService.setToken(null);
          }
        } catch (e) {
          print('❌ [SPLASH] Error loading user: $e');
          // Clear invalid token on error
          await StorageService.remove(AppConstants.tokenKey);
          await StorageService.remove(AppConstants.userKey);
          ApiService.setToken(null);
        }
      }

      // Default to login if no token or validation failed
      print('🔐 [SPLASH] Navigating to Login Screen');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e, stackTrace) {
      print('❌ [SPLASH] Fatal error in _checkFirstLaunch: $e');
      print('❌ [SPLASH] Stack trace: $stackTrace');
      // Always navigate to login on fatal error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 [SPLASH] BUILD called - rendering splash screen UI');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.apartment,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ApartmentSync',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Community, Connected',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
