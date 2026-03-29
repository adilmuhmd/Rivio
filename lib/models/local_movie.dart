import 'dart:ui';

class LocalMovie {
  final String filePath;
  final String filename;
  final String parsedTitle;
  final Duration? localDuration;
  final int? resumePositionMs;

  final String? tmdbTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final String? overview;
  final double? rating;
  final List<Map<String, String>>? cast;
  final Color? accentColor;

  final List<String>? genres;
  final String? releaseYear;
  final String? originalLanguage;
  final List<String>? productionCountries;
  final String? tagline;

  // --- USER STATE MANAGEMENT ---
  final bool isWatchlist;
  final bool isWatched;
  final double? userRating;

  LocalMovie({
    required this.filePath,
    required this.filename,
    required this.parsedTitle,
    this.localDuration,
    this.resumePositionMs,
    this.tmdbTitle,
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.overview,
    this.rating,
    this.cast,
    this.accentColor,
    this.genres,
    this.releaseYear,
    this.originalLanguage,
    this.productionCountries,
    this.tagline,
    this.isWatchlist = false,
    this.isWatched = false,
    this.userRating,
  });

  String get displayTitle => tmdbTitle ?? parsedTitle;

  double get watchProgress {
    if (resumePositionMs == null ||
        localDuration == null ||
        localDuration!.inMilliseconds == 0)
      return 0.0;
    return resumePositionMs!.toDouble() /
        localDuration!.inMilliseconds.toDouble();
  }

  // STANDARD PUBLIC COPYWITH METHOD
  LocalMovie copyWith({
    Duration? localDuration,
    int? resumePositionMs,
    String? tmdbTitle,
    String? posterUrl,
    String? backdropUrl,
    String? logoUrl,
    String? overview,
    double? rating,
    List<Map<String, String>>? cast,
    Color? accentColor,
    List<String>? genres,
    String? releaseYear,
    String? originalLanguage,
    List<String>? productionCountries,
    String? tagline,
    bool? isWatchlist,
    bool? isWatched,
    double? userRating,
  }) {
    return LocalMovie(
      filePath: filePath,
      filename: filename,
      parsedTitle: parsedTitle,
      localDuration: localDuration ?? this.localDuration,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      tmdbTitle: tmdbTitle ?? this.tmdbTitle,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      overview: overview ?? this.overview,
      rating: rating ?? this.rating,
      cast: cast ?? this.cast,
      accentColor: accentColor ?? this.accentColor,
      genres: genres ?? this.genres,
      releaseYear: releaseYear ?? this.releaseYear,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      productionCountries: productionCountries ?? this.productionCountries,
      tagline: tagline ?? this.tagline,
      isWatchlist: isWatchlist ?? this.isWatchlist,
      isWatched: isWatched ?? this.isWatched,
      userRating: userRating ?? this.userRating,
    );
  }

  LocalMovie copyWithPosition(int newPositionMs, {Duration? newDuration}) {
    return copyWith(
      localDuration: newDuration ?? localDuration,
      resumePositionMs: newPositionMs,
      // If we finish the movie (progress > 95% which we reset to 0), mark it watched automatically
      isWatched: newPositionMs == 0 && (newDuration != null) ? true : isWatched,
    );
  }

  LocalMovie copyWithMetadata({
    String? tmdbTitle,
    String? posterUrl,
    String? backdropUrl,
    String? logoUrl,
    String? overview,
    double? rating,
    List<Map<String, String>>? cast,
    Color? accentColor,
    Duration? localDuration,
    List<String>? genres,
    String? releaseYear,
    String? originalLanguage,
    List<String>? productionCountries,
    String? tagline,
  }) {
    return copyWith(
      tmdbTitle: tmdbTitle,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      logoUrl: logoUrl,
      overview: overview,
      rating: rating,
      cast: cast,
      accentColor: accentColor,
      localDuration: localDuration,
      genres: genres,
      releaseYear: releaseYear,
      originalLanguage: originalLanguage,
      productionCountries: productionCountries,
      tagline: tagline,
    );
  }

  // --- USER ACTION TOGGLES ---
  LocalMovie copyWithToggleWatchlist() => copyWith(isWatchlist: !isWatchlist);
  LocalMovie copyWithRating(double newRating) =>
      copyWith(userRating: newRating);

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'filename': filename,
      'parsedTitle': parsedTitle,
      'localDurationMs': localDuration?.inMilliseconds,
      'resumePositionMs': resumePositionMs,
      'tmdbTitle': tmdbTitle,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'logoUrl': logoUrl,
      'overview': overview,
      'rating': rating,
      'cast': cast,
      'accentColor': accentColor?.value,
      'genres': genres,
      'releaseYear': releaseYear,
      'originalLanguage': originalLanguage,
      'productionCountries': productionCountries,
      'tagline': tagline,
      'isWatchlist': isWatchlist,
      'isWatched': isWatched,
      'userRating': userRating,
    };
  }

  factory LocalMovie.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>>? parsedCast;
    if (json['cast'] != null) {
      parsedCast = (json['cast'] as List)
          .map((e) => Map<String, String>.from(e))
          .toList();
    }
    return LocalMovie(
      filePath: json['filePath'] ?? '',
      filename: json['filename'] ?? '',
      parsedTitle: json['parsedTitle'] ?? '',
      localDuration: json['localDurationMs'] != null
          ? Duration(milliseconds: json['localDurationMs'])
          : null,
      resumePositionMs: json['resumePositionMs'],
      tmdbTitle: json['tmdbTitle'],
      posterUrl: json['posterUrl'],
      backdropUrl: json['backdropUrl'],
      logoUrl: json['logoUrl'],
      overview: json['overview'],
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      cast: parsedCast,
      accentColor: json['accentColor'] != null
          ? Color(json['accentColor'] as int)
          : null,
      genres: (json['genres'] as List?)?.map((e) => e as String).toList(),
      releaseYear: json['releaseYear'],
      originalLanguage: json['originalLanguage'],
      productionCountries: (json['productionCountries'] as List?)
          ?.map((e) => e as String)
          .toList(),
      tagline: json['tagline'],
      isWatchlist: json['isWatchlist'] ?? false,
      isWatched: json['isWatched'] ?? false,
      userRating: json['userRating'] != null
          ? (json['userRating'] as num).toDouble()
          : null,
    );
  }
}
