import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rivio/api/tmdb_service.dart';
import '../models/local_movie.dart';

// ============================================================================
// DYNAMIC ACCENT PROVIDER
// ============================================================================
final accentColorProvider = StateProvider<Color>(
  (ref) => const Color(0xFFE50914),
);

// ============================================================================
// FOLDER MANAGEMENT STATE
// ============================================================================
class MediaFolder {
  final String path;
  final bool isEnabled;

  MediaFolder({required this.path, required this.isEnabled});

  Map<String, dynamic> toJson() => {'path': path, 'isEnabled': isEnabled};

  factory MediaFolder.fromJson(Map<String, dynamic> json) => MediaFolder(
    path: json['path'] as String,
    isEnabled: json['isEnabled'] as bool,
  );

  MediaFolder copyWith({bool? isEnabled}) =>
      MediaFolder(path: path, isEnabled: isEnabled ?? this.isEnabled);
}

class DirectoryNotifier extends StateNotifier<List<MediaFolder>> {
  DirectoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('rivio_folders');
    if (data != null) {
      final List decoded = json.decode(data);
      state = decoded.map((e) => MediaFolder.fromJson(e)).toList();
    } else {
      // Default Android Media Folders
      state = [
        MediaFolder(path: '/storage/emulated/0/Movies', isEnabled: true),
        MediaFolder(path: '/storage/emulated/0/Download', isEnabled: true),
        MediaFolder(path: '/storage/emulated/0/Video', isEnabled: true),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'rivio_folders',
      json.encode(state.map((e) => e.toJson()).toList()),
    );
  }

  void toggleFolder(String path) {
    state = state
        .map((f) => f.path == path ? f.copyWith(isEnabled: !f.isEnabled) : f)
        .toList();
    _save();
  }

  void addFolder(String path) {
    if (!state.any((f) => f.path == path)) {
      state = [...state, MediaFolder(path: path, isEnabled: true)];
      _save();
    }
  }

  void removeFolder(String path) {
    state = state.where((f) => f.path != path).toList();
    _save();
  }
}

final directoryProvider =
    StateNotifierProvider<DirectoryNotifier, List<MediaFolder>>(
      (ref) => DirectoryNotifier(),
    );

// ============================================================================
// PERMISSION STATE & NOTIFIER
// ============================================================================
enum AppPermissionState { checking, granted, denied, permanentlyDenied }

class PermissionNotifier extends StateNotifier<AppPermissionState> {
  PermissionNotifier() : super(AppPermissionState.checking) {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    final videoStatus = await Permission.videos.status;
    final storageStatus = await Permission.storage.status;
    if (videoStatus.isGranted ||
        videoStatus.isLimited ||
        storageStatus.isGranted) {
      state = AppPermissionState.granted;
    } else if (videoStatus.isPermanentlyDenied ||
        storageStatus.isPermanentlyDenied) {
      state = AppPermissionState.permanentlyDenied;
    } else {
      state = AppPermissionState.denied;
    }
  }

  Future<void> requestPermissions() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth)
      state = AppPermissionState.granted;
    else
      await checkPermissions();
  }

  // 👇 ADD THIS METHOD BACK IN 👇
  void openSettings() {
    openAppSettings(); // Opens the Android app settings using the permission_handler package
  }
}

final permissionProvider =
    StateNotifierProvider<PermissionNotifier, AppPermissionState>((ref) {
      return PermissionNotifier();
    });

// ============================================================================
// HELPER: MOVIE TITLE CLEANER
// ============================================================================
String _cleanMovieTitle(String filename) {
  String cleaned = filename.replaceAll(
    RegExp(r'\.(mp4|mkv|avi|webm)$', caseSensitive: false),
    '',
  );
  final tagsToStrip = [
    r'1080p',
    r'720p',
    r'480p',
    r'2160p',
    r'4k',
    r'8k',
    r'bluray',
    r'blu-ray',
    r'brrip',
    r'bdrip',
    r'webrip',
    r'web-dl',
    r'hdrip',
    r'hdtv',
    r'dvdrip',
    r'x264',
    r'h264',
    r'x265',
    r'hevc',
    r'10bit',
    r'aac',
    r'dts',
    r'ac3',
    r'5\.1',
    r'7\.1',
    r'dual[- ]audio',
    r'yts(\.[a-z]+)?',
    r'yify',
    r'psa',
    r'rarbg',
    r'tgx',
    r'ets',
    r'etrg',
    r'vostfr',
    r'subbed',
    r'dubbed',
    r'multi',
    'www',
    'diy',
    'DVDplay',
  ];
  for (var tag in tagsToStrip) {
    cleaned = cleaned.replaceAll(RegExp(tag, caseSensitive: false), ' ');
  }
  final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(cleaned);
  if (yearMatch != null) cleaned = cleaned.substring(0, yearMatch.start);
  cleaned = cleaned.replaceAll(RegExp(r'[\._\-]'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]|\(.*?\)?|\{.*?\}?'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'[()\[\]{}]'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return filename.split('.').first;
  return cleaned;
}

// ============================================================================
// MEDIA SCANNER (RESPECTS FOLDER TOGGLES)
// ============================================================================
class MediaLibraryNotifier extends StateNotifier<AsyncValue<List<LocalMovie>>> {
  MediaLibraryNotifier() : super(const AsyncValue.loading()) {
    scanAndLoadLibrary();
  }

  Future<void> scanAndLoadLibrary() async {
    state = const AsyncValue.loading();
    try {
      List<LocalMovie> rawMovies = [];
      final validExtensions = ['.mp4', '.mkv', '.avi', '.webm'];

      debugPrint('🚀 [SCANNER] Starting Scan based on selected folders...');

      // Get strictly allowed directories
      final prefs = await SharedPreferences.getInstance();
      final folderData = prefs.getString('rivio_folders');
      List<String> allowedDirs = [];
      if (folderData != null) {
        final List decoded = json.decode(folderData);
        for (var f in decoded) {
          if (f['isEnabled'] == true) allowedDirs.add(f['path']);
        }
      } else {
        allowedDirs = [
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Video',
        ];
      }

      bool isAllowed(String filePath) {
        if (allowedDirs.isEmpty) return false;
        final normalizedFile = filePath.replaceAll('\\', '/');
        for (var dir in allowedDirs) {
          final normalizedDir = dir
              .replaceAll('\\', '/')
              .replaceAll(RegExp(r'/$'), '');
          if (normalizedFile.startsWith(normalizedDir + '/') ||
              normalizedFile == normalizedDir) {
            return true;
          }
        }
        return false;
      }

      // 1. Scan device files via PhotoManager (Filtered by allowed dirs)
      try {
        final ps = await PhotoManager.requestPermissionExtend();
        if (ps.isAuth) {
          List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
            type: RequestType.video,
            onlyAll: true,
          );
          if (albums.isNotEmpty) {
            List<AssetEntity> media = await albums.first.getAssetListPaged(
              page: 0,
              size: 100,
            );
            for (var asset in media) {
              final file = await asset.file;
              // STRICT CHECK: Only add if the file lives in an enabled folder!
              if (file != null && isAllowed(file.path)) {
                final filename = asset.title ?? file.path.split('/').last;
                rawMovies.add(
                  LocalMovie(
                    filePath: file.path,
                    filename: filename,
                    parsedTitle: _cleanMovieTitle(filename),
                    localDuration: asset.videoDuration,
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ [SCANNER] PhotoManager error: $e');
      }

      // 2. Fallback Direct Folder Scan (Iterates strictly through allowed folders)
      if (rawMovies.isEmpty && allowedDirs.isNotEmpty) {
        final directories = allowedDirs.map((p) => Directory(p)).toList();
        for (var dir in directories) {
          if (await dir.exists()) {
            try {
              final files = dir.listSync(recursive: true, followLinks: false);
              for (var file in files) {
                if (file is File &&
                    validExtensions.any(
                      (ext) => file.path.toLowerCase().endsWith(ext),
                    )) {
                  if (!rawMovies.any((m) => m.filePath == file.path)) {
                    final filename = file.path.split('/').last;
                    rawMovies.add(
                      LocalMovie(
                        filePath: file.path,
                        filename: filename,
                        parsedTitle: _cleanMovieTitle(filename),
                      ),
                    );
                  }
                }
              }
            } catch (e) {}
          }
        }
      }

      if (rawMovies.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      // 3. Load Persistent Cache safely
      final String? cachedData = prefs.getString('rivio_movie_cache');
      Map<String, LocalMovie> cacheMap = {};
      if (cachedData != null) {
        try {
          final List<dynamic> decoded = json.decode(cachedData);
          for (var item in decoded) {
            try {
              final movie = LocalMovie.fromJson(item);
              cacheMap[movie.filePath] = movie;
            } catch (_) {}
          }
        } catch (_) {}
      }

      // 4. Compare files and update missing metadata
      List<LocalMovie> finalMovies = [];
      List<LocalMovie> moviesNeedingTMDB = [];
      bool cacheNeedsUpdate = false;

      for (var m in rawMovies) {
        if (cacheMap.containsKey(m.filePath)) {
          finalMovies.add(cacheMap[m.filePath]!);
        } else {
          moviesNeedingTMDB.add(m);
          cacheNeedsUpdate = true;
        }
      }

      if (finalMovies.length != cacheMap.length) cacheNeedsUpdate = true;

      if (moviesNeedingTMDB.isNotEmpty) {
        final tmdb = TmdbService();
        for (var m in moviesNeedingTMDB) {
          final enriched = await tmdb.fetchMetadata(m);
          finalMovies.add(enriched);
        }
      }

      if (cacheNeedsUpdate) await _saveCache(finalMovies);

      state = AsyncValue.data(finalMovies);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // --- NEW: USER ACTIONS ---
  Future<void> toggleWatchlist(LocalMovie movie) async {
    state.whenData((movies) async {
      final newList = List<LocalMovie>.from(movies);
      final index = newList.indexWhere((m) => m.filePath == movie.filePath);
      if (index != -1) {
        newList[index] = movie.copyWithToggleWatchlist();
        state = AsyncValue.data(newList);
        await _saveCache(newList);
      }
    });
  }

  Future<void> toggleWatched(LocalMovie movie) async {
    state.whenData((movies) async {
      final newList = List<LocalMovie>.from(movies);
      final index = newList.indexWhere((m) => m.filePath == movie.filePath);
      if (index != -1) {
        // If we are marking it AS watched, remove it from the watchlist too.
        final bool isNowWatched = !movie.isWatched;
        newList[index] = movie.copyWith(
          isWatched: isNowWatched,
          resumePositionMs: isNowWatched ? 0 : movie.resumePositionMs,
          isWatchlist: isNowWatched
              ? false
              : movie.isWatchlist, // Auto-remove from watchlist
        );
        state = AsyncValue.data(newList);
        await _saveCache(newList);
      }
    });
  }

  Future<void> rateMovie(LocalMovie movie, double rating) async {
    state.whenData((movies) async {
      final newList = List<LocalMovie>.from(movies);
      final index = newList.indexWhere((m) => m.filePath == movie.filePath);
      if (index != -1) {
        newList[index] = movie.copyWithRating(rating);
        state = AsyncValue.data(newList);
        await _saveCache(newList);
      }
    });
  }

  Future<void> updateMovieMatch(
    LocalMovie oldMovie,
    LocalMovie updatedMovie,
  ) async {
    state.whenData((movies) async {
      final List<LocalMovie> newList = List.from(movies);
      final index = newList.indexWhere((m) => m.filePath == oldMovie.filePath);
      if (index != -1) {
        newList[index] = updatedMovie;
        state = AsyncValue.data(newList);
        await _saveCache(newList);
      }
    });
  }

  Future<void> saveWatchProgress(
    LocalMovie movie,
    int positionMs, {
    Duration? playerDuration,
  }) async {
    state.whenData((movies) async {
      final List<LocalMovie> newList = List.from(movies);
      final index = newList.indexWhere((m) => m.filePath == movie.filePath);
      if (index != -1) {
        newList[index] = movie.copyWithPosition(
          positionMs,
          newDuration: playerDuration,
        );
        state = AsyncValue.data(newList);
        await _saveCache(newList);
      }
    });
  }

  Future<void> _saveCache(List<LocalMovie> movies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String newCacheData = json.encode(
        movies.map((m) => m.toJson()).toList(),
      );
      await prefs.setString('rivio_movie_cache', newCacheData);
    } catch (_) {}
  }
}

final localMoviesProvider =
    StateNotifierProvider<MediaLibraryNotifier, AsyncValue<List<LocalMovie>>>((
      ref,
    ) {
      return MediaLibraryNotifier();
    });
