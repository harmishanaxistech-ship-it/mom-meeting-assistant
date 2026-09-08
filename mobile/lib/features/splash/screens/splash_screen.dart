import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    // Smooth splash delay for branding presence
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final targetScreen = authState.isAuthenticated
        ? const DashboardScreen()
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 650;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate Navy
      body: SafeArea(
        child: Stack(
          children: [
            // Responsive ambient background glow orbs
            Positioned(
              top: -size.height * 0.08,
              right: -size.width * 0.15,
              child: Container(
                width: (size.width * 0.75).clamp(240.0, 420.0),
                height: (size.width * 0.75).clamp(240.0, 420.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.06,
              left: -size.width * 0.15,
              child: Container(
                width: (size.width * 0.7).clamp(220.0, 380.0),
                height: (size.width * 0.7).clamp(220.0, 380.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1E3A8A).withAlpha(70),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Responsive Layout with LayoutBuilder
            LayoutBuilder(
              builder: (context, constraints) {
                final iconSize = (constraints.maxHeight * 0.11).clamp(68.0, 96.0);
                final iconInnerSize = iconSize * 0.48;

                return SizedBox(
                  width: double.infinity,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top spacing / header anchor
                        const SizedBox(height: 10),

                        // Center Animated Branding
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Brand Icon Container
                                Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(iconSize * 0.28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withAlpha(90),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.mic_rounded,
                                        size: iconInnerSize,
                                        color: Colors.white,
                                      ),
                                      Positioned(
                                        top: iconSize * 0.18,
                                        right: iconSize * 0.18,
                                        child: Container(
                                          width: (iconSize * 0.1).clamp(7.0, 10.0),
                                          height: (iconSize * 0.1).clamp(7.0, 10.0),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFBBF24),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isCompact ? 16 : 22),

                                // App Title
                                Text(
                                  AppConstants.appName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: (constraints.maxHeight * 0.036).clamp(22.0, 30.0),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Subtitle Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withAlpha(28)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 13),
                                      SizedBox(width: 6),
                                      Text(
                                        AppConstants.appTagline,
                                        style: TextStyle(
                                          color: Color(0xFFE2E8F0),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom Footer & Progress (Never overflows)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF38BDF8).withAlpha(200),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              AppConstants.poweredBy,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
