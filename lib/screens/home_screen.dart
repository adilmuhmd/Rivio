import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:rivio/api/tmdb_service.dart';
import 'package:rivio/screens/detailscreen.dart';
import 'package:rivio/screens/settings_screen.dart';
import 'package:rivio/screens/player_screen.dart';
import '../models/local_movie.dart';
import '../providers/media_provider.dart';

const Curve _springCurve = Curves.elasticOut;
const Duration _springDuration = Duration(milliseconds: 1200);
const Duration _fadeDuration = Duration(milliseconds: 600);

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
      ref.read(accentColorProvider.notifier).state = const Color(0xFFE50914);
    });
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(localMoviesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          moviesAsync.when(
            loading: () => const _ShimmerLoadingScreen(),
            error: (err, stack) => Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (movies) {
              if (movies.isEmpty) {
                return Center(
                  child:
                      Text(
                            'No media found.\nAdd folders in Settings.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white54,
                                ),
                          )
                          .animate()
                          .fadeIn(duration: _fadeDuration)
                          .scale(curve: Curves.easeOutBack),
                );
              }

              // --- HERO CAROUSEL LOGIC ---
              final heroPool = List<LocalMovie>.from(movies)..shuffle(Random());
              final heroMovies = heroPool
                  .take(min(5, heroPool.length))
                  .toList();

              // --- DATA GROUPING ---
              final recentlyAdded = movies.take(8).toList();

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
                (a, b) => (b.resumePositionMs ?? 0).compareTo(
                  a.resumePositionMs ?? 0,
                ),
              );

              // Don't show watched movies in the watchlist rail
              final watchlist = movies
                  .where((m) => m.isWatchlist && !m.isWatched)
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // --- SLICK SLIVER APP BAR ---
                  SliverAppBar(
                    toolbarHeight: 70,
                    pinned: true,
                    floating: true,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.background.withOpacity(0.85),
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.movie_filter_rounded,
                          color: Color(0xFFE50914),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'RIVIO',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),

                  // --- 1. HERO CAROUSEL ---
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                    sliver: SliverToBoxAdapter(
                      child: _HeroCarousel(movies: heroMovies)
                          .animate()
                          .scale(curve: _springCurve, duration: _springDuration)
                          .fadeIn(duration: _fadeDuration),
                    ),
                  ),

                  // --- 2. CONTINUE WATCHING ---
                  if (continueWatching.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Continue Watching'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 250,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: continueWatching.length,
                          itemBuilder: (context, index) {
                            final m = continueWatching[index];
                            return _ContinueWatchingCard(
                                  key: ValueKey(
                                    'continue_${m.tmdbTitle ?? m.parsedTitle}',
                                  ),
                                  movie: m,
                                )
                                .animate()
                                .fadeIn(
                                  delay: (index * 60).ms,
                                  duration: _fadeDuration,
                                )
                                .slideX(
                                  begin: 0.1,
                                  curve: _springCurve,
                                  duration: _springDuration,
                                );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // --- WATCHLIST ---
                  if (watchlist.isNotEmpty) ...[
                    _buildSectionHeader(context, 'My Watchlist'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 280,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: watchlist.length,
                          itemBuilder: (context, index) {
                            final m = watchlist[index];
                            return _ExpressiveTallCard(
                                  key: ValueKey(
                                    'wl_${m.tmdbTitle ?? m.parsedTitle}',
                                  ),
                                  movie: m,
                                )
                                .animate()
                                .fadeIn(
                                  delay: (index * 60).ms,
                                  duration: _fadeDuration,
                                )
                                .slideX(
                                  begin: 0.1,
                                  curve: _springCurve,
                                  duration: _springDuration,
                                );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // --- 3. WATCH NEXT ---
                  if (watchNext.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Watch Next'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: min(10, watchNext.length),
                          itemBuilder: (context, index) {
                            final m = watchNext[index];
                            return _ExpressiveWideCard(
                                  key: ValueKey(
                                    'wide_${m.tmdbTitle ?? m.parsedTitle}',
                                  ),
                                  movie: m,
                                )
                                .animate()
                                .fadeIn(
                                  delay: (index * 60).ms,
                                  duration: _fadeDuration,
                                )
                                .slideX(
                                  begin: 0.1,
                                  curve: _springCurve,
                                  duration: _springDuration,
                                );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],

                  // --- 4. ALL MEDIA (Grid) ---
                  _buildSectionHeader(context, 'All Media'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = (constraints.crossAxisExtent / 120)
                            .floor();
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final m = movies[index];
                            return _ExpressiveGridCard(
                              key: ValueKey(
                                'grid_${m.tmdbTitle ?? m.parsedTitle}',
                              ),
                              movie: m,
                            );
                          }, childCount: movies.length),
                        );
                      },
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, top: 48, bottom: 20, right: 24),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CACHED IMAGE LOADER
// ============================================================================
Widget _buildSafeImage(
  BuildContext context,
  String? url, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
}) {
  if (url == null || url.isEmpty) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.movie_creation_rounded,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
  return RepaintBoundary(
    child: Image.network(
      url,
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: Colors.white24,
              size: 48,
            ),
          ),
        );
      },
    ),
  );
}

// ============================================================================
// UI COMPONENTS
// ============================================================================

// --- UNIFIED CLEAN BADGE DESIGN ---
Widget _buildWatchedBadge(LocalMovie movie) {
  if (movie.isWatched) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.black, size: 18),
      ),
    );
  } else if (movie.isWatchlist) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.bookmark_rounded,
          color: Colors.black,
          size: 18,
        ),
      ),
    );
  }
  return const SizedBox.shrink();
}

// --- HERO CAROUSEL ---
class _HeroCarousel extends StatefulWidget {
  final List<LocalMovie> movies;
  const _HeroCarousel({required this.movies});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.movies.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 8), (Timer timer) {
        if (_currentPage < widget.movies.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
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
      height: 480,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.movies.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          return _HeroMovieCard(movie: widget.movies[index]);
        },
      ),
    );
  }
}

class _HeroMovieCard extends StatelessWidget {
  final LocalMovie movie;
  const _HeroMovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildSafeImage(
                context,
                movie.posterUrl,
                alignment: Alignment.topCenter,
              ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.alphaBlend(accent.withOpacity(0.6), Colors.black),
                      Colors.black87,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.8],
                  ),
                ),
              ),

              Positioned(
                bottom: 40,
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
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(fontSize: 48, color: Colors.white),
                      ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: accent,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Play Movie',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5,
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

class _ContinueWatchingCard extends ConsumerWidget {
  final LocalMovie movie;
  const _ContinueWatchingCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = movie.accentColor ?? const Color(0xFFE50914);

    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(32),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSafeImage(
                        context,
                        movie.backdropUrl ?? movie.posterUrl,
                      ),
                      Container(color: Colors.black45),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: movie.watchProgress,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 8),
              child: Text(
                movie.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: -0.5,
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
  const _ExpressiveWideCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(24),
                ),
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
              padding: const EdgeInsets.only(top: 16, left: 8),
              child: Text(
                movie.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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

class _ExpressiveTallCard extends StatelessWidget {
  final LocalMovie movie;
  const _ExpressiveTallCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
              padding: const EdgeInsets.only(top: 16, left: 4),
              child: Text(
                movie.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
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
  const _ExpressiveGridCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return _ActionableMovieCard(
      movie: movie,
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
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              movie.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                fontSize: 12,
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
  const _ActionableMovieCard({
    super.key,
    required this.movie,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)),
        );
        ref.read(accentColorProvider.notifier).state = const Color(0xFFE50914);
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showActionMenu(context, ref);
      },
      child: child,
    );
  }

  void _showActionMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionMenuSheet(movie: movie),
    );
  }
}

// --- LONG PRESS ACTION MENU ---
class _ActionMenuSheet extends ConsumerWidget {
  final LocalMovie movie;
  const _ActionMenuSheet({required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = movie.accentColor ?? Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
          padding: const EdgeInsets.only(top: 32, bottom: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 60,
                        height: 90,
                        child: _buildSafeImage(context, movie.posterUrl),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.displayTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (movie.releaseYear != null)
                            Text(
                              movie.releaseYear!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (movie.userRating != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: accent,
                                  size: 16,
                                ),
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
              const SizedBox(height: 24),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),

              // Actions
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        movie.isWatchlist
                            ? 'Removed from Watchlist'
                            : 'Added to Watchlist',
                      ),
                    ),
                  );
                },
              ),
              _buildActionTile(
                context,
                icon: movie.isWatched
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                title: movie.isWatched
                    ? 'Mark as Unwatched'
                    : 'Mark as Watched',
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
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
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
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      leading: Icon(icon, color: color, size: 28),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
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

// --- MANUAL TMDB SEARCH SHEET ---
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
        SnackBar(content: Text('Matched to ${updatedMovie.displayTitle}')),
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
          color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
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
                        child: SizedBox(
                          child: Lottie.asset(
                            'assets/loading.json',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const CircularProgressIndicator(),
                          ),
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
                                            child: const Icon(
                                              Icons.broken_image,
                                              size: 20,
                                            ),
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
                              .slideY(begin: 0.1, curve: _springCurve);
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
// SKELETON SHIMMER LOADING SCREEN
// ============================================================================
class _ShimmerLoadingScreen extends StatelessWidget {
  const _ShimmerLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child:
                Container(
                      height: 480,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(40),
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .fade(
                      begin: 0.3,
                      end: 0.7,
                      duration: 1.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 24),
            child:
                Container(
                      width: 180,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .fade(begin: 0.3, end: 0.7, duration: 1.seconds),
          ),
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemBuilder: (context, index) =>
                  Container(
                        width: 320,
                        margin: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .fade(
                        begin: 0.3,
                        end: 0.7,
                        duration: 1.seconds,
                        delay: (index * 200).ms,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
