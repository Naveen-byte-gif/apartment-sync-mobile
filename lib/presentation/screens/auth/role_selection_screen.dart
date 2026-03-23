import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/constants/app_constants.dart';
import 'admin_login_screen.dart';
import 'resident_login_screen.dart';
import 'staff_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          /// 🔹 HEADER
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo_circle_apartmentsync.png',
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    AppConstants.appTagline,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 🔹 BOTTOM SHEET CONTENT
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Your Role',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how you want to access the system',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 30),

                    /// ADMIN
                    _RoleCard(
                      icon: FontAwesomeIcons.userTie,
                      title: 'Admin',
                      subtitle:
                          'Full owner-level access to all buildings and management features.',
                      color: const Color(0xFFE11D48),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminLoginScreen(
                              roleContext: AppConstants.roleAdmin,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    /// STAFF
                    _RoleCard(
                      icon: FontAwesomeIcons.userTie,
                      title: 'Staff',
                      subtitle:
                         'Access to assigned buildings and operational features',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffLoginScreen(
                              roleContext: AppConstants.roleStaff,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    /// RESIDENT
                    _RoleCard(
                      icon: FontAwesomeIcons.userTie,
                      title: 'Resident',
                      subtitle:
                           'Access to your building, flat details, and community features',
                           
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResidentLoginScreen(
                              roleContext: AppConstants.roleResident,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [

                /// SOFT TOP-RIGHT COLOR FADE
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.centerLeft,
                        colors: [
                          color.withOpacity(0.30),
                          color.withOpacity(0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                /// TEXT CONTENT
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 110, top: 18, bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔻 BOOKMARK SHAPE WITH ICON
                Positioned(
                  right: -1,
                  top: 0,
                  bottom: 0,
                  width: 85,
                  child: ClipPath(
                    clipper: BookmarkClipper(),
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: FaIcon(
                          icon,
                          color: color,
                          size: 28,
                        ),
                      ),
                    ),
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

///  BOOKMARK CLIPPER
class BookmarkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.moveTo(0, size.height * 0.5);
    path.lineTo(size.width * 0.28, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width * 0.28, size.height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}