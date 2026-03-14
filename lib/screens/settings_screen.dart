import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/media_provider.dart';

// Uniform Brand Color for Settings
const Color _brandAccent = Color(0xFFE50914);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- HIGH PERFORMANCE SLIVER APP BAR ---
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            // Replaced FlexibleSpaceBar with a simple LayoutBuilder for safe, crash-free scrolling
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Calculate how expanded the app bar is
                final double percent =
                    (constraints.maxHeight - kToolbarHeight) /
                    (160.0 - kToolbarHeight);
                final double opacity = percent.clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fading background gradient
                    Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _brandAccent.withOpacity(
                                0.15,
                              ), // Subtle brand glow at top
                              Theme.of(context).colorScheme.background,
                            ],
                            stops: const [0.0, 0.8],
                          ),
                        ),
                      ),
                    ),
                    // Animated Title Position
                    Positioned(
                      left: Tween<double>(
                        begin: 72.0,
                        end: 24.0,
                      ).transform(opacity),
                      bottom: Tween<double>(
                        begin: 16.0,
                        end: 24.0,
                      ).transform(opacity),
                      child: Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: Colors.white,
                              fontSize: Tween<double>(
                                begin: 22.0,
                                end: 36.0,
                              ).transform(opacity),
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant, // M3 Expressive solid color
                          borderRadius: BorderRadius.circular(
                            32,
                          ), // M3 Soft roundness
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _brandAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.folder_shared_rounded,
                                  color: _brandAccent,
                                ),
                              ),
                              title: const Text(
                                'Manage Folders',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: const Text(
                                'Select which directories to scan.',
                                style: TextStyle(color: Colors.white54),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white54,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ManageFoldersScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(
                              height: 1,
                              color: Colors.white10,
                              indent: 80,
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                              title: const Text(
                                'Force Rescan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: const Text(
                                'Manually rebuild your media library.',
                                style: TextStyle(color: Colors.white54),
                              ),
                              onTap: () {
                                ref
                                    .read(localMoviesProvider.notifier)
                                    .scanAndLoadLibrary();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Library scan initiated.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: _brandAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutQuart),

                  const SizedBox(height: 48),

                  const Text(
                    'About',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 64,
                              color: _brandAccent.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Rivio',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Version 1.0.0',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideY(begin: 0.1, curve: Curves.easeOutQuart),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MANAGE FOLDERS SCREEN
// ============================================================================
class ManageFoldersScreen extends ConsumerWidget {
  const ManageFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(directoryProvider);

    return PopScope(
      onPopInvoked: (didPop) {
        ref.read(localMoviesProvider.notifier).scanAndLoadLibrary();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Manage Folders',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            final isDefault =
                folder.path.contains('/emulated/0/Movies') ||
                folder.path.contains('/emulated/0/Download') ||
                folder.path.contains('/emulated/0/Video');

            return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: folder.isEnabled
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: folder.isEnabled
                          ? _brandAccent.withOpacity(0.3)
                          : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Icon(
                      Icons.folder_rounded,
                      color: folder.isEnabled ? _brandAccent : Colors.white24,
                      size: 32,
                    ),
                    title: Text(
                      folder.path.split('/').last,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: folder.isEnabled ? Colors.white : Colors.white38,
                        decoration: folder.isEnabled
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      folder.path,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDefault)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => ref
                                .read(directoryProvider.notifier)
                                .removeFolder(folder.path),
                          ),
                        Switch(
                          value: folder.isEnabled,
                          activeColor: _brandAccent,
                          onChanged: (_) => ref
                              .read(directoryProvider.notifier)
                              .toggleFolder(folder.path),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: (index * 40).ms)
                .slideX(begin: 0.05, curve: Curves.easeOutQuart);
          },
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _brandAccent,
          foregroundColor: Colors.white,
          elevation: 0, // Flat M3 look
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text(
            'Add Directory',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          onPressed: () async {
            String? selectedDirectory = await FilePicker.platform
                .getDirectoryPath(dialogTitle: 'Select Media Folder');

            if (selectedDirectory != null) {
              ref.read(directoryProvider.notifier).addFolder(selectedDirectory);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added $selectedDirectory',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: _brandAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }
            }
          },
        ).animate().scale(curve: Curves.elasticOut, duration: 1.seconds),
      ),
    );
  }
}
