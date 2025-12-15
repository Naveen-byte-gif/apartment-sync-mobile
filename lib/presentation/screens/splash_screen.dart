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
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final isFirstLaunch = StorageService.getBool(AppConstants.isFirstLaunchKey) ?? true;
    final token = StorageService.getString(AppConstants.tokenKey);
    
    if (isFirstLaunch) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (token != null && token.isNotEmpty) {
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
            if (user.role == AppConstants.roleAdmin) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
              return;
            } else if (user.role == 'staff') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
              );
              return;
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
              return;
            }
          } catch (e) {
            print('❌ [SPLASH] Error parsing snapshot user: $e');
          }
        }
        
        // If snapshot fails, try API
        final response = await ApiService.get('/auth/me');
        if (response['success'] == true && response['data']?['user'] != null) {
          final user = UserData.fromJson(response['data']['user']);
          
          // Save snapshot
          await StorageService.setString(
            AppConstants.userKey,
            jsonEncode(user.toJson()),
          );
          
          if (user.role == AppConstants.roleAdmin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            );
          } else if (user.role == 'staff') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const StaffDashboardScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          return;
        }
      } catch (e) {
        print('❌ [SPLASH] Error loading user: $e');
        // If error, go to login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      
      // Default to login if everything fails
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

