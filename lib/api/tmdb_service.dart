import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator/palette_generator.dart';
import '../models/local_movie.dart';

class TmdbService {
  static const String _apiKey = '930468fda014966745238047b14e0346'; 
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  // ==========================================================================
  // AUTOMATIC METADATA MATCHER
  // ==========================================================================
  Future<LocalMovie> fetchMetadata(LocalMovie movie) async {
    if (_apiKey == 'YOUR_TMDB_API_KEY') return movie;

    try {
      final titleParts = movie.parsedTitle.split(' ');
      
      List<String> queries = [movie.parsedTitle];
      if (titleParts.length > 1) {
        queries.add(titleParts.skip(1).join(' ')); 
      }
      if (titleParts.length > 2) {
        queries.add(titleParts.take(2).join(' ')); 
      }

      Set<int> candidateIds = {};

      for (String query in queries) {
        if (query.trim().isEmpty) continue;
        
        final searchUrl = Uri.parse('$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}');
        final response = await http.get(searchUrl);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['results'] != null) {
            for (var i = 0; i < data['results'].length && i < 3; i++) {
              candidateIds.add(data['results'][i]['id']);
            }
          }
        }
      }

      if (candidateIds.isEmpty) return movie;

      double bestScore = -9999.0;
      Map<String, dynamic>? bestMatch;

      for (int id in candidateIds) {
        final detailsUrl = Uri.parse('$_baseUrl/movie/$id?api_key=$_apiKey&append_to_response=credits,images&include_image_language=en,null');
        final detailsRes = await http.get(detailsUrl);
        
        if (detailsRes.statusCode == 200) {
          final tmdbData = json.decode(detailsRes.body);
          double score = _calculateScore(movie, tmdbData);

          if (score > bestScore) {
            bestScore = score;
            bestMatch = tmdbData;
          }
        }
      }

      if (bestMatch != null && bestScore > -500) { 
        return _extractAndEnrichMovie(movie, bestMatch);
      }
    } catch (e) {
      debugPrint('TMDB Fetch Error: $e');
    }
    
    return movie;
  }

  // ==========================================================================
  // MANUAL SEARCH TOOLS (FIX MATCH)
  // ==========================================================================
  Future<List<dynamic>> searchMovieManual(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse('$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        return json.decode(res.body)['results'];
      }
    } catch (e) {
      debugPrint('Manual Search Error: $e');
    }
    return [];
  }

  Future<LocalMovie> fetchMovieById(LocalMovie movie, int tmdbId) async {
    try {
      final detailsUrl = Uri.parse('$_baseUrl/movie/$tmdbId?api_key=$_apiKey&append_to_response=credits,images&include_image_language=en,null');
      final detailsRes = await http.get(detailsUrl);
      
      if (detailsRes.statusCode == 200) {
        final bestMatch = json.decode(detailsRes.body);
        return _extractAndEnrichMovie(movie, bestMatch);
      }
    } catch (e) {
      debugPrint('Force Fetch Error: $e');
    }
    return movie;
  }

  // ==========================================================================
  // ACTOR FILMOGRAPHY
  // ==========================================================================
  Future<List<Map<String, dynamic>>> fetchActorMovies(int personId) async {
    try {
      final url = Uri.parse('$_baseUrl/person/$personId/movie_credits?api_key=$_apiKey');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final castList = data['cast'] as List;
        
        final movies = castList
            .where((m) => m['release_date'] != null && m['release_date'].toString().isNotEmpty)
            .map((m) => {
                  'title': m['title'],
                  'year': m['release_date'].toString().split('-').first,
                  'poster': m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w200${m['poster_path']}' : null,
                  'character': m['character'],
                })
            .toList();
            
        movies.sort((a, b) => b['year'].compareTo(a['year']));
        return movies;
      }
    } catch (e) {
      debugPrint('Actor Fetch Error: $e');
    }
    return [];
  }

  // ==========================================================================
  // INTERNAL HELPERS
  // ==========================================================================
  Future<LocalMovie> _extractAndEnrichMovie(LocalMovie originalMovie, Map<String, dynamic> tmdbData) async {
    
    // 1. Extract Cast
    List<Map<String, String>> castList = [];
    if (tmdbData['credits'] != null && tmdbData['credits']['cast'] != null) {
      final cast = tmdbData['credits']['cast'] as List;
      for (var i = 0; i < cast.length && i < 15; i++) { // Increased to 15 actors
        castList.add({
          'id': cast[i]['id'].toString(),
          'name': cast[i]['name'],
          'role': cast[i]['character'],
          'profilePath': cast[i]['profile_path'] != null ? 'https://image.tmdb.org/t/p/w200${cast[i]['profile_path']}' : '',
        });
      }
    }

    // 2. Extract Logo
    String? fetchedLogo;
    if (tmdbData['images'] != null && tmdbData['images']['logos'] != null) {
      final logos = tmdbData['images']['logos'] as List;
      if (logos.isNotEmpty) {
        fetchedLogo = 'https://image.tmdb.org/t/p/w500${logos[0]['file_path']}';
      }
    }

    // 3. Extract Accent Color
    Color? accentColor;
    if (fetchedLogo != null) {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(fetchedLogo),
        maximumColorCount: 5,
      );
      accentColor = palette.vibrantColor?.color ?? const Color(0xFFE50914);
    }

    // 4. Extract Runtime
    Duration? tmdbDuration;
    if (tmdbData['runtime'] != null && tmdbData['runtime'] > 0) {
      tmdbDuration = Duration(minutes: tmdbData['runtime']);
    }

    // --- 5. NEW: EXTRACT MAXIMUM DATA ---
    
    // Genres (e.g., ["Action", "Sci-Fi"])
    List<String> genres = [];
    if (tmdbData['genres'] != null) {
      for (var g in tmdbData['genres']) {
        genres.add(g['name']);
      }
    }

    // Release Year (e.g., "2023")
    String? releaseYear;
    if (tmdbData['release_date'] != null && tmdbData['release_date'].toString().isNotEmpty) {
      releaseYear = tmdbData['release_date'].toString().split('-').first;
    }

    // Original Language (e.g., "en")
    String? originalLanguage = tmdbData['original_language'];

    // Production Countries (e.g., ["United States of America"])
    List<String> countries = [];
    if (tmdbData['production_countries'] != null) {
      for (var c in tmdbData['production_countries']) {
        countries.add(c['name']);
      }
    }

    // Tagline
    String? tagline;
    if (tmdbData['tagline'] != null && tmdbData['tagline'].toString().isNotEmpty) {
      tagline = tmdbData['tagline'];
    }

    return originalMovie.copyWithMetadata(
      tmdbTitle: tmdbData['title'],
      posterUrl: tmdbData['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${tmdbData['poster_path']}' : null,
      backdropUrl: tmdbData['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${tmdbData['backdrop_path']}' : null,
      logoUrl: fetchedLogo,
      overview: tmdbData['overview'],
      rating: (tmdbData['vote_average'] as num?)?.toDouble(),
      cast: castList,
      accentColor: accentColor,
      localDuration: originalMovie.localDuration ?? tmdbDuration,
      
      // Pass the new data!
      genres: genres,
      releaseYear: releaseYear,
      originalLanguage: originalLanguage,
      productionCountries: countries,
      tagline: tagline,
    );
  }

  double _calculateScore(LocalMovie local, Map<String, dynamic> tmdbData) {
    double score = 0;

    score += (tmdbData['popularity'] ?? 0).toDouble();

    String localTitleNorm = local.parsedTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    String tmdbTitleNorm = (tmdbData['title'] ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    String tmdbOrigTitleNorm = (tmdbData['original_title'] ?? tmdbTitleNorm).toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');

    int distTitle = _levenshtein(localTitleNorm, tmdbTitleNorm);
    int distOrig = _levenshtein(localTitleNorm, tmdbOrigTitleNorm);
    int bestDist = min(distTitle, distOrig);

    double maxLen = max(localTitleNorm.length, max(tmdbTitleNorm.length, tmdbOrigTitleNorm.length)).toDouble();
    if (maxLen == 0) maxLen = 1; 
    double normDist = bestDist / maxLen;
    score += 500 * (1 - normDist);

    if (normDist < 0.2) score += 200;

    Set<String> localWords = localTitleNorm.split(' ').where((w) => w.isNotEmpty).toSet();
    Set<String> tmdbWords = tmdbTitleNorm.split(' ').where((w) => w.isNotEmpty).toSet();
    if (localWords.isNotEmpty && tmdbWords.isNotEmpty) {
      int intersectionSize = localWords.intersection(tmdbWords).length;
      int unionSize = localWords.union(tmdbWords).length;
      double jaccard = intersectionSize / unionSize;
      score += 200 * jaccard;
    }

    int lenDiff = (localTitleNorm.length - tmdbTitleNorm.length).abs();
    if (lenDiff > 10) score -= 100;

    String? localYear = _extractYear(local.parsedTitle);
    String? tmdbYear = tmdbData['release_date']?.substring(0, 4);
    if (localYear != null && tmdbYear != null) {
      if (localYear == tmdbYear) {
        score += 400;
      } else {
        score -= 200;
      }
    }

    if (local.localDuration != null && local.localDuration!.inMinutes > 10 && tmdbData['runtime'] != null) {
      int localMins = local.localDuration!.inMinutes;
      int tmdbMins = tmdbData['runtime'];
      int diff = (localMins - tmdbMins).abs();

      if (diff <= 5) {
        score += 1000; 
      } else if (diff <= 15) {
        score += 300;  
      } else if (diff > 45) {
        score -= 1000; 
      }
    }

    return score;
  }

  int _levenshtein(String s, String t) {
    int n = s.length;
    int m = t.length;
    List<List<int>> dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (int i = 0; i <= n; i++) dp[i][0] = i;
    for (int j = 0; j <= m; j++) dp[0][j] = j;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        int cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j] + 1,
          min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost),
        );
      }
    }
    return dp[n][m];
  }

  String? _extractYear(String title) {
    RegExp yearReg = RegExp(r'\d{4}');
    Iterable<RegExpMatch> matches = yearReg.allMatches(title);
    if (matches.isNotEmpty) {
      String lastMatch = matches.last.group(0)!;
      int year = int.parse(lastMatch);
      if (year >= 1900 && year <= 2100) return lastMatch;
    }
    return null;
  }
}