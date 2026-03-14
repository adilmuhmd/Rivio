import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/local_movie.dart';
import '../providers/media_provider.dart';
import '../api/tmdb_service.dart';
import 'player_screen.dart';

// ============================================================================
// EXPRESSIVE SPRING PHYSICS
// ============================================================================
// Mirroring the physics of how objects actually move.
const SpringDescription _expressiveSpring = SpringDescription(
  mass: 1.0,
  stiffness: 250.0,
  damping: 20.0,
);

// ============================================================================
// CACHED IMAGE LOADER (Optimized with Disk Caching)
// ============================================================================
Widget _buildSafeImage(
  BuildContext context,
  String? url, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
}) {
  if (url == null || url.isEmpty) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.movie_creation_rounded,
        color: Colors.white24,
        size: (width != null && width < 50) ? 20 : 48,
      ),
    );
  }

  return RepaintBoundary(
    child: CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      // What to show while it's loading from the network or disk
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      // What to show if the URL is broken
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white24,
          size: (width != null && width < 50) ? 20 : 48,
        ),
      ),
    ),
  );
}

class DetailScreen extends ConsumerStatefulWidget {
  final LocalMovie movie;
  const DetailScreen({super.key, required this.movie});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  Color? _accentColor;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _extractAccentColor();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _extractAccentColor() async {
    final imageProvider = widget.movie.logoUrl != null
        ? NetworkImage(widget.movie.logoUrl!)
        : (widget.movie.posterUrl != null
              ? NetworkImage(widget.movie.posterUrl!)
              : null);

    if (imageProvider != null) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          maximumColorCount: 5,
        );
        if (mounted) {
          final newColor =
              palette.vibrantColor?.color ??
              palette.dominantColor?.color ??
              const Color(0xFFE50914);
          setState(() {
            _accentColor = newColor;
          });
          ref.read(accentColorProvider.notifier).state = newColor;
        }
      } catch (_) {}
    }
  }

  // --- MOVIE INFO BOTTOM SHEET (With Fade-In Blur Gradient) ---
  void _showInfoSheet(
    BuildContext context,
    LocalMovie activeMovie,
    Color themeAccent,
  ) {
    final genres = activeMovie.genres?.join(', ') ?? '—';
    final countries = activeMovie.productionCountries?.join(', ') ?? '—';

    const map = {
      'en': 'English',
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
      'it': 'Italian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'ml': 'Malayalam',
    };
    final origLang = activeMovie.originalLanguage != null
        ? (map[activeMovie.originalLanguage!] ??
              activeMovie.originalLanguage!.toUpperCase())
        : '—';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Required for custom backgrounds
      builder: (context) => RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height *
                0.8, // Take up 80% of screen
            child: Stack(
              children: [
                // 1. The Faded Blur Layer
                Positioned.fill(
                  child: ShaderMask(
                    // Fades the blur effect out at the very top
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.0, 0.15], // Transition to full blur quickly
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // 2. The Content Layer with Faded Surface Color
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          // Fully transparent at top edge
                          Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.0),
                          // Transition to solid surface color
                          Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.95),
                          Theme.of(context).colorScheme.surface,
                        ],
                        stops: const [0.0, 0.15, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            'Movie Info',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                ),
                          ),
                          const SizedBox(height: 32),
                          if (activeMovie.tagline != null &&
                              activeMovie.tagline!.isNotEmpty) ...[
                            Text(
                              '"${activeMovie.tagline!}"',
                              style: TextStyle(
                                color:
                                    themeAccent, // Emphasize tagline with movie accent
                                fontStyle: FontStyle.italic,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                          _buildInfoRow('Genres', genres),
                          _buildInfoRow('Language', origLang),
                          _buildInfoRow('Production', countries),
                          _buildInfoRow('File Path', activeMovie.filePath),
                          const SizedBox(height: 120), // Padding for scrolling
                        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActorDetails(
    BuildContext context,
    Map<String, String> actor,
    Color themeAccent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ActorDetailsSheet(actor: actor, themeAccent: themeAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(localMoviesProvider);
    final size = MediaQuery.of(context).size;

    final LocalMovie activeMovie = moviesAsync.maybeWhen(
      data: (movies) {
        try {
          return movies.firstWhere((m) => m.filePath == widget.movie.filePath);
        } catch (_) {
          return widget.movie;
        }
      },
      orElse: () => widget.movie,
    );

    final Color themeAccent =
        _accentColor ?? Theme.of(context).colorScheme.primary;
    final Color bgColor = Color.alphaBlend(
      themeAccent.withOpacity(0.12),
      const Color(0xFF0F0F13),
    );
    final bool isDarkText = themeAccent.computeLuminance() > 0.5;
    final Color textColor = isDarkText ? Colors.black : Colors.white;

    final double imageHeight = size.height * 0.65;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. PINNED BACKGROUND IMAGE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildSafeImage(
                    context,
                    activeMovie.backdropUrl,
                    alignment: Alignment.topCenter,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.2, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. SCROLLING CONTENT OVERLAY
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: imageHeight - 250)),

              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        bgColor.withOpacity(0.9),
                        bgColor,
                      ],
                      stops: const [0.0, 0.15, 0.3],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==============================================================
                        // UNIFIED IMPACT ANIMATION BLOCK
                        // Groups Logo, Metadata, and Buttons so they spring together
                        // ==============================================================
                        Column(
                              children: [
                                // --- HERO LOGO ---
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                      maxHeight: 120,
                                    ),
                                    child: activeMovie.logoUrl != null
                                        ? _buildSafeImage(
                                            context,
                                            activeMovie.logoUrl,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.bottomCenter,
                                          )
                                        : Text(
                                            activeMovie.displayTitle,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayLarge
                                                ?.copyWith(
                                                  fontSize: 42,
                                                  color: Colors.white,
                                                ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Center(
                                  child: _buildCleanMetadataRow(
                                    activeMovie,
                                    themeAccent,
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // --- PLAY / RESUME & INFO ROW ---
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPlayButton(
                                        context,
                                        activeMovie,
                                        themeAccent,
                                        textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // INFO BUTTON
                                    Container(
                                      height: 64,
                                      width: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        onPressed: () => _showInfoSheet(
                                          context,
                                          activeMovie,
                                          themeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                            // This applies the elastic "Impact" animation to the whole block
                            .animate()
                            .scale(
                              delay: 150.ms,
                              begin: const Offset(0.9, 0.9),
                              curve: Curves.elasticOut,
                              duration: 1000.ms,
                            )
                            .fadeIn(duration: 400.ms),

                        // ==============================================================
                        if (activeMovie.watchProgress > 0.01) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: activeMovie.watchProgress,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                final fresh = activeMovie.copyWithPosition(0);
                                await ref
                                    .read(localMoviesProvider.notifier)
                                    .saveWatchProgress(fresh, 0);
                                if (context.mounted)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RivioPlayerScreen(movie: fresh),
                                    ),
                                  );
                              },
                              icon: const Icon(
                                Icons.replay_rounded,
                                color: Colors.white70,
                              ),
                              label: const Text(
                                'Start Over',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                        ],

                        const SizedBox(height: 48),

                        // --- SYNOPSIS ---
                        Text(
                          'Synopsis',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                        ).animate().fadeIn(delay: 350.ms),
                        const SizedBox(height: 12),
                        Text(
                          activeMovie.overview ?? 'No synopsis available.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 48),

                        // --- CAST LIST (OPTIMIZED) ---
                        if (activeMovie.cast != null &&
                            activeMovie.cast!.isNotEmpty) ...[
                          Text(
                            'Cast',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                          ).animate().fadeIn(delay: 450.ms),
                          const SizedBox(height: 16),

                          SizedBox(
                                height: 160,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  clipBehavior: Clip.none,
                                  itemCount: activeMovie.cast!.length,
                                  itemBuilder: (context, i) {
                                    final actor = activeMovie.cast![i];
                                    return GestureDetector(
                                      onTap: () {
                                        if (actor['id'] != null &&
                                            actor['id']!.isNotEmpty) {
                                          _showActorDetails(
                                            context,
                                            actor,
                                            themeAccent,
                                          );
                                        }
                                      },
                                      child: Container(
                                        width: 100,
                                        margin: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        child: Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: _buildSafeImage(
                                                  context,
                                                  actor['profilePath'],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              actor['name'] ?? '',
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                height: 1.2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                              // Single spring animation for the whole list
                              .animate()
                              .fadeIn(delay: 500.ms)
                              .slideX(
                                begin: 0.1,
                                curve: Curves.elasticOut,
                                duration: 1200.ms,
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3. FLOATING BACK BUTTON (Optimized)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: RepaintBoundary(
              // Cache the blur
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.black26,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanMetadataRow(LocalMovie movie, Color accent) {
    final year = movie.releaseYear ?? '—';
    final runtimeStr = movie.localDuration != null
        ? '${movie.localDuration!.inHours > 0 ? '${movie.localDuration!.inHours}h ' : ''}${movie.localDuration!.inMinutes.remainder(60).toString().padLeft(2, '0')}m'
        : '—';

    List<Widget> rowItems = [];

    if (year != '—')
      rowItems.add(
        Text(
          year,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );

    if (runtimeStr != '—') {
      if (rowItems.isNotEmpty)
        rowItems.add(
          const Text(
            '  •  ',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        );
      rowItems.add(
        Text(
          runtimeStr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    if (movie.rating != null && movie.rating! > 0) {
      if (rowItems.isNotEmpty)
        rowItems.add(
          const Text(
            '  •  ',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        );
      rowItems.add(Icon(Icons.star_rounded, color: Colors.white, size: 20));
      rowItems.add(const SizedBox(width: 4));
      rowItems.add(
        Text(
          movie.rating!.toStringAsFixed(1),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: rowItems);
  }

  Widget _buildPlayButton(
    BuildContext context,
    LocalMovie movie,
    Color themeAccent,
    Color textColor,
  ) {
    final bool isResuming = movie.watchProgress > 0.01;

    return ElevatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RivioPlayerScreen(movie: movie)),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeAccent,
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: 10,
        shadowColor: themeAccent.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isResuming
                ? Icons.play_circle_fill_rounded
                : Icons.play_arrow_rounded,
            color: textColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            isResuming ? 'Resume' : 'Play',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ); // Scale animation removed here since it's now wrapped in the parent Column animation
  }
}

// ============================================================================
// OPTIMIZED ACTOR SHEET (Editorial Typography & Spring Physics)
// ============================================================================
class _ActorDetailsSheet extends StatefulWidget {
  final Map<String, String> actor;
  final Color themeAccent;

  const _ActorDetailsSheet({required this.actor, required this.themeAccent});

  @override
  State<_ActorDetailsSheet> createState() => _ActorDetailsSheetState();
}

class _ActorDetailsSheetState extends State<_ActorDetailsSheet> {
  List<Map<String, dynamic>> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final idStr = widget.actor['id'];
    if (idStr == null || idStr.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final movies = await TmdbService().fetchActorMovies(
      int.tryParse(idStr) ?? 0,
    );
    if (mounted) {
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(48)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            height: MediaQuery.of(context).size.height * 0.88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
                  child: Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: _buildSafeImage(
                            context,
                            widget.actor['profilePath'],
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.actor['name'] ?? 'Unknown',
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Filmography',
                              style: TextStyle(
                                color: widget.themeAccent,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: widget.themeAccent,
                          ),
                        )
                      : _movies.isEmpty
                      ? const Center(
                          child: Text(
                            'No filmography found',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
                      : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _movies.length,
                              itemBuilder: (context, index) {
                                final m = _movies[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                    vertical: 10,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 56,
                                      height: 84,
                                      child: _buildSafeImage(
                                        context,
                                        m['poster'],
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    m['title'] ?? 'Unknown Title',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${m['year'] ?? '—'} • ${m['character'] ?? '—'}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                              begin: 0.05,
                              curve: Curves.elasticOut,
                              duration: 1000.ms,
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
