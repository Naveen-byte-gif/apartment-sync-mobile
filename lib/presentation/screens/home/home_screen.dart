import '../../../core/imports/app_imports.dart';
import '../profile/profile_screen.dart';
import 'resident_home_screen.dart';
import 'tabs/news_tab_screen.dart';
import 'tabs/payments_tab_screen.dart';
import '../../widgets/app_sidebar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

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
        return const ProfileScreen();
      default:
        return const ResidentHomeScreen();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppSidebarBuilder.buildResidentSidebar(context: context),
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
