import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:rivio/providers/media_provider.dart';
import 'home_screen.dart';

class RivioGateway extends ConsumerStatefulWidget {
  const RivioGateway({super.key});

  @override
  ConsumerState<RivioGateway> createState() => _RivioGatewayState();
}

class _RivioGatewayState extends ConsumerState<RivioGateway>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _lottieController;
  bool _isAnimationFinished = false;
  bool _showAppName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the controller
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionProvider.notifier).checkPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(permissionProvider);

    // The app is ONLY ready if both the animation is done AND permissions are checked
    final isReadyToProceed =
        _isAnimationFinished && permState != AppPermissionState.checking;

    if (!isReadyToProceed) {
      // --- SEAMLESS CINEMATIC SPLASH SCREEN ---
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. The Lottie Animation
              SizedBox(
                child: Lottie.asset(
                  'assets/loading.json',
                  controller: _lottieController,
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('🚨 LOTTIE ERROR: $error');
                    return const CircularProgressIndicator(
                      color: Color(0xFFE50914),
                    );
                  },
                  onLoaded: (composition) {
                    _lottieController.duration = composition.duration;

                    // Play the animation to 100%
                    _lottieController.forward().whenComplete(() async {
                      // Trigger text exactly when the animation hits its final pose
                      if (mounted) setState(() => _showAppName = true);

                      // Hold BOTH the end pose and the text on screen for 1.5 seconds
                      await Future.delayed(const Duration(milliseconds: 1500));

                      if (!mounted) return;
                      setState(() => _isAnimationFinished = true);
                    });
                  },
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // 2. The App Name
              SizedBox(
                height: 80,
                child: _showAppName
                    ? Text(
                            'RIVIO',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 12.0,
                                  color: Colors.white,
                                ),
                          )
                          .animate()
                          // Expressive elastic spring entrance
                          .slideY(
                            begin: 0.5,
                            end: 0,
                            duration: 1000.ms,
                            curve: Curves.elasticOut,
                          )
                          .fadeIn(duration: 600.ms)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    } else if (permState == AppPermissionState.granted) {
      // Fade into the home screen smoothly
      return const HomeScreen().animate().fadeIn(duration: 800.ms);
    } else {
      // Fade into the permission screen
      return const PermissionScreen().animate().fadeIn(duration: 800.ms);
    }
  }
}

// ============================================================================
// M3 EXPRESSIVE PERMISSION SCREEN
// ============================================================================
class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permState = ref.watch(permissionProvider);
    final isBlocked = permState == AppPermissionState.permanentlyDenied;

    // Using the global accent (defaults to red)
    final accent = ref.watch(accentColorProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expressive Icon Container (Asymmetrical Tension)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(32),
                  ),
                  border: Border.all(color: accent.withOpacity(0.3), width: 2),
                ),
                child: Icon(
                  isBlocked ? Icons.block_rounded : Icons.movie_filter_rounded,
                  size: 64,
                  color: accent,
                ),
              ).animate().scale(curve: Curves.elasticOut, duration: 1200.ms),

              const SizedBox(height: 48),

              // Heavy Editorial Typography
              Text(
                    isBlocked ? 'Access\nBlocked.' : 'Find your\nmovies.',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1.5,
                      color: Colors.white,
                    ),
                  )
                  .animate()
                  .slideY(
                    begin: 0.2,
                    duration: 800.ms,
                    curve: Curves.easeOutQuart,
                  )
                  .fadeIn(),

              const SizedBox(height: 24),

              Text(
                    isBlocked
                        ? 'Rivio requires video permissions to function automatically. Please enable them in your Android settings.'
                        : 'To build your local library automatically, Rivio needs permission to scan your device for video files.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                  .animate()
                  .slideY(
                    begin: 0.2,
                    delay: 100.ms,
                    duration: 800.ms,
                    curve: Curves.easeOutQuart,
                  )
                  .fadeIn(),

              const SizedBox(height: 48),

              // Primary Action Button
              SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isBlocked) {
                          ref.read(permissionProvider.notifier).openSettings();
                        } else {
                          ref
                              .read(permissionProvider.notifier)
                              .requestPermissions();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        elevation: 12,
                        shadowColor: accent.withOpacity(0.4),
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
                        isBlocked ? 'Open Settings' : 'Grant Auto-Scan Access',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .slideY(
                    begin: 0.2,
                    delay: 200.ms,
                    duration: 800.ms,
                    curve: Curves.easeOutQuart,
                  )
                  .fadeIn(),

              const SizedBox(height: 16),

              // Secondary Action: Manual Folder Selection via Settings
              if (!isBlocked)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      // Bypass permissions and go straight to Home Screen.
                      // From Home, they can use the Settings UI to pick specific folders.
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text(
                      'I\'ll select folders manually later',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
