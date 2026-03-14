import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/media_provider.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

// Use identical physics constants as HomeScreen
const Curve _m3Spring = Curves.easeOutQuart;
const Duration _m3Duration = Duration(milliseconds: 800);
const Duration _fadeDuration = Duration(milliseconds: 600);

// Rivio Brand Color
const Color _brandColor = Color(0xFF6FAF4F);

class RivioGateway extends ConsumerStatefulWidget {
  const RivioGateway({super.key});

  @override
  ConsumerState<RivioGateway> createState() => _RivioGatewayState();
}

class _RivioGatewayState extends ConsumerState<RivioGateway>
    with WidgetsBindingObserver {
  // Controls the transition from "Splash Mode" to "Permission Mode"
  bool _showPermissionContent = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionProvider.notifier).checkPermissions();
    }
  }

  Future<void> _initializeFlow() async {
    // 1. Wait a moment to show the standalone logo (Splash phase)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // 2. Check current permissions
    await ref.read(permissionProvider.notifier).checkPermissions();
    final permState = ref.read(permissionProvider);

    if (permState == AppPermissionState.granted) {
      _navigateToHome();
    } else {
      // If NOT granted, trigger the seamless animation to reveal permission UI
      setState(() {
        _isCheckingPermissions = false;
        _showPermissionContent = true;
      });
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: _m3Duration,
      ),
    );
  }

  // --- DEFAULT FOLDERS POPUP (With beautiful M3 styling) ---
  void _showDefaultFoldersPopup(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent, // Prevents unwanted tinting in M3
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        titlePadding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _brandColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_special_rounded,
                color: _brandColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Default Folders',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rivio will request storage access to automatically scan these default directories:',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '/storage/emulated/0/Movies',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '/storage/emulated/0/Download',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '/storage/emulated/0/Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can add or remove custom folders anytime in Settings.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor:
                  Colors.black, // Dark text on light brand color for contrast
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () async {
              // 1. Close the dialog
              Navigator.pop(context);
              // 2. Ask for system permissions
              await ref.read(permissionProvider.notifier).requestPermissions();
            },
            child: const Text(
              'Proceed',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms).fadeIn(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(permissionProvider);
    final isBlocked = permState == AppPermissionState.permanentlyDenied;

    // ==================================================================
    // THE FIX: Listen to the permission state dynamically!
    // As soon as the user hits "Proceed" and accepts the Android prompt,
    // this triggers and pushes them into the HomeScreen automatically.
    // ==================================================================
    ref.listen<AppPermissionState>(permissionProvider, (previous, next) {
      if (next == AppPermissionState.granted) {
        _navigateToHome();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Stack(
            children: [
              // =========================================================
              // THE LOGO (Animates from Center -> Top Left automatically)
              // =========================================================
              AnimatedAlign(
                alignment: _showPermissionContent
                    ? Alignment.topLeft
                    : Alignment.center,
                duration: _m3Duration,
                curve: _m3Spring,
                child: AnimatedContainer(
                  duration: _m3Duration,
                  curve: _m3Spring,

                  child: Image.asset(
                    'assets/logo.png',
                    // Starts large in center, shrinks when it moves up
                    width: _showPermissionContent ? 150 : 180,
                    height: _showPermissionContent ? 150 : 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // =========================================================
              // PERMISSION CONTENT (Fades and slides in below the logo)
              // =========================================================
              if (_showPermissionContent)
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Push content down slightly so it clears the top-left logo
                      const SizedBox(height: 100),

                      // Heavy Editorial Typography
                      Text(
                            isBlocked
                                ? 'Access\nBlocked.'
                                : 'Find your\nmovies.',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  letterSpacing: -1.5,
                                  color: Colors.white,
                                ),
                          )
                          .animate()
                          .slideY(
                            begin: 0.1,
                            duration: _m3Duration,
                            curve: _m3Spring,
                          )
                          .fadeIn(duration: _fadeDuration),

                      const SizedBox(height: 24),

                      Text(
                            isBlocked
                                ? 'Rivio requires video permissions to function automatically. Please enable them in your Android settings.'
                                : 'To build your local library automatically, Rivio needs permission to scan your device for video files.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white70,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                          )
                          .animate()
                          .slideY(
                            begin: 0.1,
                            delay: 100.ms,
                            duration: _m3Duration,
                            curve: _m3Spring,
                          )
                          .fadeIn(duration: _fadeDuration),

                      const SizedBox(height: 48),

                      // Primary Action Button
                      SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (isBlocked) {
                                  ref
                                      .read(permissionProvider.notifier)
                                      .openSettings();
                                } else {
                                  _showDefaultFoldersPopup(context, ref);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isBlocked
                                    ? Colors.redAccent
                                    : _brandColor,
                                foregroundColor: isBlocked
                                    ? Colors.white
                                    : Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                elevation: 0,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(24),
                                    bottomLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(24),
                                  ),
                                ),
                              ),
                              child: Text(
                                isBlocked ? 'Open Settings' : 'Grant Access',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .slideY(
                            begin: 0.1,
                            delay: 200.ms,
                            duration: _m3Duration,
                            curve: _m3Spring,
                          )
                          .fadeIn(duration: _fadeDuration),

                      const SizedBox(height: 16),

                      // Secondary Action: Manual Folder Selection
                      if (!isBlocked)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ManageFoldersScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text(
                              'I\'ll select folders manually',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          delay: 500.ms,
                          duration: _fadeDuration,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
