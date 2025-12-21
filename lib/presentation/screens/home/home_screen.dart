import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';
import '../complaints/complaints_screen.dart';
import '../notices/notices_screen.dart';
import '../profile/profile_screen.dart';
import 'resident_home_screen.dart';
import '../auth/login_screen.dart';
import 'tabs/news_tab_screen.dart';
import 'tabs/payments_tab_screen.dart';
import 'tabs/chat_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserData? _user;
  bool _isLoggedIn = false;

  // Helper method to build screens without their own AppBars
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const ResidentHomeScreen();
      case 1:
        return const NewsTabScreen();
      case 2:
        return const PaymentsTabScreen();
      case 3:
        return const ChatTabScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const ResidentHomeScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    final token = StorageService.getString(AppConstants.tokenKey);
    final userJson = StorageService.getString(AppConstants.userKey);

    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      if (userJson != null) {
        try {
          _user = UserData.fromJson(jsonDecode(userJson));
        } catch (e) {
          print('Error parsing user data: $e');
        }
      }
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      (_user?.fullName != null && _user!.fullName!.isNotEmpty)
                          ? _user!.fullName!.substring(0, 1).toUpperCase()
                          : 'R',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _user?.fullName ?? 'Resident',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_user?.email != null)
                  Text(
                    _user!.email!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description, color: AppColors.primary),
            title: const Text('Complaints'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications, color: AppColors.primary),
            title: const Text('Notices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoticesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.primary),
            title: const Text('History'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to history screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.primary),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: AppColors.primary),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to help screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await StorageService.remove(AppConstants.tokenKey);
              await StorageService.remove(AppConstants.userKey);
              ApiService.setToken(null);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: _buildScreen(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'News',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payment'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'CHATs',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
