import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rivio/api/tmdb_service.dart';
import 'package:rivio/screens/detailscreen.dart';
import 'package:rivio/screens/settings_screen.dart';
import 'package:rivio/screens/player_screen.dart';
import '../models/local_movie.dart';
import '../providers/media_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ============================================================================
// M3 EXPRESSIVE MOTION SYSTEM
// ============================================================================
const Curve _m3Spring = Curves.easeOutQuart;
const Duration _m3Duration = Duration(milliseconds: 800);
const Duration _fadeDuration = Duration(milliseconds: 400);

const Color _brandColor = Color(0xFF6FAF4F);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accentColorProvider.notifier).state = _brandColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(localMoviesProvider);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: moviesAsync.when(
        loading: () => const _ShimmerLoadingScreen(),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (movies) {
          if (movies.isEmpty) return const _EmptyStateView();

          // --- EFFICIENT DATA PREP ---
          final heroPool = List<LocalMovie>.from(movies)..shuffle(Random(42));
          final heroMovies = heroPool.take(min(5, heroPool.length)).toList();

          final watchNext = List<LocalMovie>.from(movies);
          watchNext.sort((a, b) {
            if (a.isWatched && !b.isWatched) return 1;
            if (!a.isWatched && b.isWatched) return -1;
            return 0;
          });

          final continueWatching = movies
              .where(
                (m) =>
                    m.watchProgress > 0.01 &&
                    m.watchProgress < 0.95 &&
                    !m.isWatched,
              )
              .toList();
          continueWatching.sort(
            (a, b) =>
                (b.resumePositionMs ?? 0).compareTo(a.resumePositionMs ?? 0),
          );

          final watchlist = movies
              .where((m) => m.isWatchlist && !m.isWatched)
              .toList();

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),

              // 1. HERO CAROUSEL
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 32 : 16,
                  24,
                  isTablet ? 32 : 16,
                  48,
                ),
                sliver: SliverToBoxAdapter(
                  child: _HeroCarousel(movies: heroMovies, isTablet: isTablet)
                      .animate()
                      .scale(curve: _m3Spring, duration: _m3Duration)
                      .fadeIn(duration: _fadeDuration),
                ),
              ),

              // 2. CONTINUE WATCHING
              if (continueWatching.isNotEmpty) ...[
                _buildSectionHeader(context, 'Continue Watching', isTablet),
                SliverToBoxAdapter(
                  child:
                      _HorizontalMediaRail(
                            height: isTablet ? 320 : 250,
                            itemCount: continueWatching.length,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 16,
                            ),
                            builder: (context, index) => _ContinueWatchingCard(
                              movie: continueWatching[index],
                              isTablet: isTablet,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: _fadeDuration)
                          .slideX(
                            begin: 0.05,
                            curve: _m3Spring,
                            duration: _m3Duration,
                          ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 3. WATCHLIST
              if (watchlist.isNotEmpty) ...[
                _buildSectionHeader(context, 'My Watchlist', isTablet),
                SliverToBoxAdapter(
                  child:
                      _HorizontalMediaRail(
                            height: isTablet ? 340 : 280,
                            itemCount: watchlist.length,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 16,
                            ),
                            builder: (context, index) => _ExpressiveTallCard(
                              movie: watchlist[index],
                              isTablet: isTablet,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: _fadeDuration)
                          .slideX(
                            begin: 0.05,
                            curve: _m3Spring,
                            duration: _m3Duration,
                          ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 4. WATCH NEXT
              if (watchNext.isNotEmpty) ...[
                _buildSectionHeader(context, 'Watch Next', isTablet),
                SliverToBoxAdapter(
                  child:
                      _HorizontalMediaRail(
                            height: isTablet ? 280 : 220,
                            itemCount: min(10, watchNext.length),
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 16,
                            ),
                            builder: (context, index) => _ExpressiveWideCard(
                              movie: watchNext[index],
                              isTablet: isTablet,
                            ),
                          )
                          .animate()
                          .fadeIn(duration: _fadeDuration)
                          .slideX(
                            begin: 0.05,
                            curve: _m3Spring,
                            duration: _m3Duration,
                          ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              // 5. ALL MEDIA (Canonical Grid)
              _buildSectionHeader(context, 'All Media', isTablet),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount =
                        (constraints.crossAxisExtent / (isTablet ? 180 : 120))
                            .floor();
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: isTablet ? 24 : 16,
                        mainAxisSpacing: isTablet ? 24 : 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _ExpressiveGridCard(movie: movies[index]),
                        childCount: movies.length,
                      ),
                    );
                  },
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      toolbarHeight: 70,
      pinned: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.background.withOpacity(0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              cacheWidth: 312, // Performance optimization
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.movie_filter_rounded,
                color: _brandColor,
                size: 32,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isTablet,
  ) {
    return SliverPadding(
      padding: EdgeInsets.only(
        left: isTablet ? 32 : 24,
        top: 32,
        bottom: 16,
        right: 24,
      ),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PERFORMANCE UTILITIES
// ============================================================================

class _HorizontalMediaRail extends StatelessWidget {
  final double height;
  final int itemCount;
  final EdgeInsets padding;
  final IndexedWidgetBuilder builder;

  const _HorizontalMediaRail({
    required this.height,
    required this.itemCount,
    required this.padding,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: builder,
      ),
    );
  }
}

Widget _buildSafeImage(
  BuildContext context,
  String? url, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
}) {
  if (url == null || url.isEmpty) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.movie_creation_rounded,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }

  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    alignment: alignment,
    fadeInDuration: const Duration(milliseconds: 200),
    placeholder: (context, url) =>
        Container(color: Theme.of(context).colorScheme.surfaceVariant),
    errorWidget: (context, url, error) => Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white24,
          size: 48,
        ),
      ),
    ),
  );
}

// ============================================================================
// UI COMPONENTS
// ============================================================================

Widget _buildWatchedBadge(LocalMovie movie) {
  if (movie.isWatched) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
      ),
    );
  } else if (movie.isWatchlist) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.bookmark_rounded,
          color: Colors.black,
          size: 16,
        ),
      ),
    );
  }
  return const SizedBox.shrink();
}

class _HeroCarousel extends StatefulWidget {
  final List<LocalMovie> movies;
  final bool isTablet;
  const _HeroCarousel({required this.movies, required this.isTablet});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.movies.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
        if (_pageController.hasClients) {
          int next = (_currentPage < widget.movies.length - 1)
              ? _currentPage + 1
              : 0;
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutQuart,
          );
          _currentPage = next;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.isTablet ? 600 : 480,
      child: PageView.builder(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        itemCount: widget.movies.length,
        onPageChanged: (index) => _currentPage = index,
        itemBuilder: (context, index) =>
            _HeroMovieCard(movie: widget.movies[index]),
      ),
    );
  }
}

class _HeroMovieCard extends StatelessWidget {
  final LocalMovie movie;
  const _HeroMovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(32),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSafeImage(
                context,
                movie.backdropUrl,
                alignment: Alignment.topCenter,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 32,
                right: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (movie.logoUrl != null)
                      _buildSafeImage(
                        context,
                        movie.logoUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      )
                    else
                      Text(
                        movie.displayTitle,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                      ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: accent.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Play',
                            style: TextStyle(
                              color: accent.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildWatchedBadge(movie),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final LocalMovie movie;
  final bool isTablet;
  const _ContinueWatchingCard({required this.movie, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: isTablet ? 400 : 320,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildSafeImage(
                      context,
                      movie.backdropUrl ?? movie.posterUrl,
                    ),
                    Container(color: Colors.black38),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: movie.watchProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                movie.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressiveWideCard extends StatelessWidget {
  final LocalMovie movie;
  final bool isTablet;
  const _ExpressiveWideCard({required this.movie, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: isTablet ? 360 : 280,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildSafeImage(context, movie.backdropUrl),
                    _buildWatchedBadge(movie),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                movie.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressiveTallCard extends StatelessWidget {
  final LocalMovie movie;
  final bool isTablet;
  const _ExpressiveTallCard({required this.movie, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: isTablet ? 180 : 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildSafeImage(context, movie.posterUrl),
                    _buildWatchedBadge(movie),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                movie.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressiveGridCard extends StatelessWidget {
  final LocalMovie movie;
  const _ExpressiveGridCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildSafeImage(context, movie.posterUrl),
                  _buildWatchedBadge(movie),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              movie.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INTERACTION ROUTER & ACTION MENU
// ============================================================================
class _ActionableMovieCard extends ConsumerWidget {
  final LocalMovie movie;
  final Widget child;
  const _ActionableMovieCard({required this.movie, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)),
        );
        ref.read(accentColorProvider.notifier).state = _brandColor;
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (context) => _ActionMenuSheet(movie: movie),
        );
      },
      child: child,
    );
  }
}

//--- LONG PRESS ACTION MENU
class _ActionMenuSheet extends ConsumerWidget {
  final LocalMovie movie;
  const _ActionMenuSheet({required this.movie});

  // M3 Expressive Delete Confirmation
  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Delete File?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${movie.filename}" from your device? This cannot be undone.',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close Dialog
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Close Bottom Sheet
              await ref.read(localMoviesProvider.notifier).deleteMovie(movie);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'File deleted.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms).fadeIn(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 50,
                      height: 75,
                      child: _buildSafeImage(context, movie.posterUrl),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (movie.releaseYear != null)
                          Text(
                            movie.releaseYear!,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        if (movie.userRating != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, color: accent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'You rated: ${movie.userRating}',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            _buildActionTile(
              context,
              icon: Icons.play_arrow_rounded,
              title: 'Play',
              color: Colors.white,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RivioPlayerScreen(movie: movie),
                  ),
                );
              },
            ),
            _buildActionTile(
              context,
              icon: movie.isWatchlist
                  ? Icons.bookmark_remove_rounded
                  : Icons.bookmark_add_rounded,
              title: movie.isWatchlist
                  ? 'Remove from Watchlist'
                  : 'Add to Watchlist',
              color: Colors.white,
              onTap: () {
                ref.read(localMoviesProvider.notifier).toggleWatchlist(movie);
                Navigator.pop(context);
              },
            ),
            _buildActionTile(
              context,
              icon: movie.isWatched
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              title: movie.isWatched ? 'Mark as Unwatched' : 'Mark as Watched',
              color: Colors.white,
              onTap: () {
                ref.read(localMoviesProvider.notifier).toggleWatched(movie);
                Navigator.pop(context);
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.star_border_rounded,
              title: 'Rate Movie',
              color: Colors.white,
              onTap: () {
                Navigator.pop(context);
                _showRatingDialog(context, ref);
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(color: Colors.white10, height: 1),
            ),

            _buildActionTile(
              context,
              icon: Icons.edit_attributes_rounded,
              title: 'Fix Match',
              color: Colors.white54,
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _ManualSearchSheet(movie: movie),
                );
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.info_outline_rounded,
              title: 'File Info',
              color: Colors.white54,
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    title: const Text('File Information'),
                    content: Text(
                      'Path:\n${movie.filePath}\n\nFilename:\n${movie.filename}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: _brandColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // --- NEW: DELETE MEDIA ACTION ---
            _buildActionTile(
              context,
              icon: Icons.delete_outline_rounded,
              title: 'Delete File',
              color: Colors.redAccent,
              onTap: () {
                _showDeleteConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showRatingDialog(BuildContext context, WidgetRef ref) {
    double currentRating = movie.userRating ?? 5.0;
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            title: const Center(
              child: Text(
                'Rate Movie',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                Slider(
                  value: currentRating,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  activeColor: accent,
                  onChanged: (val) => setState(() => currentRating = val),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(localMoviesProvider.notifier)
                      .rateMovie(movie, currentRating);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Save Rating',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- RESTORED MANUAL TMDB SEARCH SHEET ---
class _ManualSearchSheet extends ConsumerStatefulWidget {
  final LocalMovie movie;
  const _ManualSearchSheet({required this.movie});

  @override
  ConsumerState<_ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends ConsumerState<_ManualSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.movie.parsedTitle;
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    final results = await TmdbService().searchMovieManual(_controller.text);
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  Future<void> _applyOverride(int tmdbId) async {
    setState(() => _isLoading = true);
    final updatedMovie = await TmdbService().fetchMovieById(
      widget.movie,
      tmdbId,
    );

    if (mounted) {
      ref
          .read(localMoviesProvider.notifier)
          .updateMovieMatch(widget.movie, updatedMovie);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Matched to ${updatedMovie.displayTitle}'),
          backgroundColor: _brandColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          padding: EdgeInsets.only(
            top: 40,
            left: 32,
            right: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fix Match',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'File: ${widget.movie.filename}',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _controller,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _performSearch,
                    ),
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: _brandColor,
                        ).animate().fadeIn(duration: 400.ms),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final res = _searchResults[index];
                          final year =
                              res['release_date']
                                  ?.toString()
                                  .split('-')
                                  .first ??
                              'Unknown Year';
                          return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: res['poster_path'] != null
                                      ? Image.network(
                                          'https://image.tmdb.org/t/p/w200${res['poster_path']}',
                                          width: 60,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 60,
                                            height: 90,
                                            color: Colors.white10,
                                          ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 90,
                                          color: Colors.white10,
                                        ),
                                ),
                                title: Text(
                                  res['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontSize: 18,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                subtitle: Text(
                                  year,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () => _applyOverride(res['id']),
                              )
                              .animate()
                              .fadeIn(delay: (index * 40).ms)
                              .slideY(begin: 0.1, curve: _m3Spring);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE / SHIMMER SCREENS
// ============================================================================

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 24),
          Text(
            'Your library is empty.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the gear icon to add media folders.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ShimmerLoadingScreen extends StatelessWidget {
  const _ShimmerLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: _brandColor));
  }
}
