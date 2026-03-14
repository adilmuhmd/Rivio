import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/local_movie.dart';
import '../providers/media_provider.dart';

class RivioPlayerScreen extends ConsumerStatefulWidget {
  final LocalMovie movie;
  const RivioPlayerScreen({super.key, required this.movie});

  @override
  ConsumerState<RivioPlayerScreen> createState() => _RivioPlayerScreenState();
}

class _RivioPlayerScreenState extends ConsumerState<RivioPlayerScreen> {
  // 1. Force hardware-accelerated GPU output to unlock HDR / Dolby Vision
  late final player = Player(
    configuration: const PlayerConfiguration(
      vo: 'gpu', // Forces best available GPU rendering pipeline
    ),
  );

  late final controller = VideoController(
    player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
    ),
  );

  // --- SUBTITLE CUSTOMIZATION STATE ---
  Color _subColor = Colors.white;
  Color _subBgColor = Colors.transparent;
  double _subSize = 24.0;

  // --- VIDEO METADATA STATE ---
  String? _videoQualityBadge;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializePlayer();

    // 2. Listen to the video tracks to extract HDR/10-bit data live
    player.stream.tracks.listen((tracks) {
      if (mounted && tracks.video.isNotEmpty) {
        _parseVideoQuality(tracks.video.first);
      }
    });
  }

  // --- ANALYZE CODEC & COLOR SPACE ---
  void _parseVideoQuality(VideoTrack track) {
    List<String> tags = [];

    // Resolution check
    if (track.h != null) {
      if (track.h! >= 2160)
        tags.add('4K');
      else if (track.h! >= 1080)
        tags.add('1080p');
    }

    // Codec and Color Space parsing (Depends on how mpv/media_kit exposes it)
    final codec = track.codec?.toLowerCase() ?? '';

    // Look for standard HDR/Dolby markers in codec strings
    if (codec.contains('dvhe') ||
        codec.contains('dovi') ||
        codec.contains('dolby')) {
      tags.add('Dolby Vision');
    } else if (codec.contains('hdr10plus') || codec.contains('hdr10+')) {
      tags.add('HDR10+');
    } else if (codec.contains('hdr')) {
      tags.add('HDR');
    }

    // Look for 10-bit depth
    if (codec.contains('10bit') || codec.contains('p10')) {
      if (!tags.contains('Dolby Vision') &&
          !tags.contains('HDR') &&
          !tags.contains('HDR10+')) {
        tags.add('10-Bit');
      }
    }

    if (tags.isNotEmpty) {
      setState(() {
        _videoQualityBadge = tags.join(' • ');
      });
    }
  }

  // --- THE BULLETPROOF FIX: POST-RENDER SEEK ---
  Future<void> _initializePlayer() async {
    debugPrint('⏳ [PLAYER] Loading video engine...');

    // Open the media and start it immediately to warm up the Android HW Codec
    await player.open(Media(widget.movie.filePath));

    if (widget.movie.resumePositionMs != null &&
        widget.movie.resumePositionMs! > 0) {
      debugPrint(
        '⏳ [PLAYER] Resume detected. Waiting for hardware codec stabilization...',
      );

      // WAIT for the player to report that it is actively playing frames
      await player.stream.playing.firstWhere((isPlaying) => isPlaying);

      // Give the "CCodec" time to finish its 'query failed' and 'BAD_INDEX' loops.
      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint(
        '⏩ [PLAYER] Codec stable. Seeking to: ${widget.movie.resumePositionMs} ms',
      );

      // Seek now that the pipeline is "Hot"
      await player.seek(Duration(milliseconds: widget.movie.resumePositionMs!));
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  // --- SAVE AND EXIT ROUTINE ---
  Future<void> _saveAndExit() async {
    debugPrint('\n==================================================');
    debugPrint('🛑 [PLAYER EXIT] Initiating _saveAndExit sequence');
    debugPrint('==================================================');

    final currentPosMs = player.state.position.inMilliseconds;
    final totalDurationMs = player.state.duration.inMilliseconds;

    int safeDurationMs = totalDurationMs;
    if (safeDurationMs <= 0) {
      if (widget.movie.localDuration != null) {
        safeDurationMs = widget.movie.localDuration!.inMilliseconds;
      }
    }

    int finalPositionToSave = currentPosMs;

    if (safeDurationMs > 0) {
      double percentage = currentPosMs / safeDurationMs;
      if (percentage > 0.95) {
        finalPositionToSave = 0;
      }
    }

    ref
        .read(localMoviesProvider.notifier)
        .saveWatchProgress(
          widget.movie,
          finalPositionToSave,
          playerDuration: Duration(milliseconds: safeDurationMs),
        );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ============================================================================
  // SCROLLABLE SUBTITLE CUSTOMIZER
  // ============================================================================
  void _showSubtitleCustomizer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtitle Style',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Text Color',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children:
                            [
                              Colors.white,
                              Colors.yellow,
                              Colors.cyanAccent,
                              Colors.greenAccent,
                              Colors.pinkAccent,
                            ].map((color) {
                              final isSelected = _subColor == color;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _subColor = color);
                                  setSheetState(() {});
                                },
                                child: AnimatedContainer(
                                  duration: 200.ms,
                                  margin: const EdgeInsets.only(right: 16),
                                  width: isSelected ? 48 : 40,
                                  height: isSelected ? 48 : 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 4.0,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withOpacity(0.5),
                                              blurRadius: 12.0,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Background',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children:
                          [
                            {'label': 'Clear', 'val': Colors.transparent},
                            {'label': 'Dim', 'val': Colors.black45},
                            {'label': 'Solid', 'val': Colors.black},
                          ].map((item) {
                            final color = item['val'] as Color;
                            final isSelected = _subBgColor == color;
                            return ChoiceChip(
                              label: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.white,
                              backgroundColor: Colors.white10,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              onSelected: (_) {
                                setState(() => _subBgColor = color);
                                setSheetState(() {});
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Size',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor:
                            widget.movie.accentColor ?? Colors.white,
                        thumbColor: widget.movie.accentColor ?? Colors.white,
                        trackHeight: 8.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12.0,
                        ),
                      ),
                      child: Slider(
                        value: _subSize,
                        min: 16.0,
                        max: 48.0,
                        onChanged: (val) {
                          setState(() => _subSize = val);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTrackSelector({required bool isAudio}) {
    final List<AudioTrack> audioTracks = player.state.tracks.audio;
    final List<SubtitleTrack> subtitleTracks = player.state.tracks.subtitle;
    final activeTrack = isAudio
        ? player.state.track.audio
        : player.state.track.subtitle;
    final accent = widget.movie.accentColor ?? Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAudio ? 'Audio' : 'Subtitles',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                    ),
                    if (!isAudio)
                      IconButton(
                        icon: const Icon(
                          Icons.palette_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showSubtitleCustomizer();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (!isAudio)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 4,
                        ),
                        leading: Icon(
                          activeTrack.id == 'no'
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: activeTrack.id == 'no'
                              ? accent
                              : Colors.white24,
                          size: 28,
                        ),
                        title: const Text(
                          'Off',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        onTap: () {
                          player.setSubtitleTrack(SubtitleTrack.no());
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ...(isAudio ? audioTracks : subtitleTracks).map((track) {
                      final isSelected = activeTrack == track;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 4,
                        ),
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected ? accent : Colors.white24,
                          size: 28,
                        ),
                        title: Text(
                          track.title ?? track.language ?? 'Track ${track.id}',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w500,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        onTap: () {
                          if (isAudio)
                            player.setAudioTrack(track as AudioTrack);
                          else
                            player.setSubtitleTrack(track as SubtitleTrack);
                          Navigator.pop(context);
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedSelector() {
    final currentSpeed = player.state.rate;
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final accent = widget.movie.accentColor ?? Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Playback Speed',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: speeds.map((speed) {
                    final isSelected = currentSpeed == speed;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 4,
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected ? accent : Colors.white24,
                        size: 28,
                      ),
                      title: Text(
                        speed == 1.0 ? 'Normal' : '${speed}x',
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w500,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      onTap: () {
                        player.setRate(speed);
                        Navigator.pop(context);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final isPortrait = size.height > size.width;

    final double horizontalPadding = isTablet
        ? 64.0
        : (isPortrait ? 16.0 : 48.0);
    final double bottomPadding = isTablet ? 80.0 : 56.0;
    final double iconScale = isTablet ? 1.3 : (isPortrait ? 0.9 : 1.0);

    final Color accent = widget.movie.accentColor ?? const Color(0xFFE50914);

    final controlsTheme = MaterialVideoControlsThemeData(
      seekBarHeight: 6.0 * iconScale,
      seekBarThumbSize: 18.0 * iconScale,
      seekBarThumbColor: accent,
      seekBarPositionColor: accent,
      seekBarBufferColor: Colors.white24,
      seekBarMargin: EdgeInsets.only(
        bottom: 24.0,
        left: horizontalPadding,
        right: horizontalPadding,
      ),

      topButtonBarMargin: EdgeInsets.only(
        top: bottomPadding,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      topButtonBar: [
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 40.0 * iconScale,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 10.0)],
          ),
          color: Colors.white,
          onPressed: _saveAndExit,
        ),
        const Spacer(),

        Flexible(
          flex: 4,
          child: widget.movie.logoUrl != null
              ? Image.network(
                  widget.movie.logoUrl!,
                  height: isTablet ? 60.0 : 45.0,
                  fit: BoxFit.contain,
                )
              : Text(
                  widget.movie.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 28.0 : 22.0,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 10.0),
                    ],
                  ),
                ),
        ),

        const Spacer(),
        SizedBox(width: 48.0 * iconScale),
      ],

      primaryButtonBar: [
        const Spacer(),
        IconButton(
          icon: Icon(
            Icons.replay_10_rounded,
            size: 56.0 * iconScale,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 12.0)],
          ),
          color: Colors.white,
          onPressed: () =>
              player.seek(player.state.position - const Duration(seconds: 10)),
        ),
        SizedBox(width: isTablet ? 80.0 : 40.0),

        Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              bottomLeft: Radius.circular(12),
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 20.0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: MaterialPlayOrPauseButton(
            iconSize: 72.0 * iconScale,
            iconColor: accent.computeLuminance() > 0.5
                ? Colors.black
                : Colors.white,
          ),
        ),

        SizedBox(width: isTablet ? 80.0 : 40.0),
        IconButton(
          icon: Icon(
            Icons.forward_10_rounded,
            size: 56.0 * iconScale,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 12.0)],
          ),
          color: Colors.white,
          onPressed: () =>
              player.seek(player.state.position + const Duration(seconds: 10)),
        ),
        const Spacer(),
      ],

      bottomButtonBarMargin: EdgeInsets.only(
        bottom: bottomPadding,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      bottomButtonBar: [
        Expanded(
          child: MaterialPositionIndicator(
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.0 * iconScale,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black, blurRadius: 5.0)],
            ),
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.speed_rounded, size: 28.0 * iconScale),
              color: Colors.white,
              onPressed: _showSpeedSelector,
            ),
            IconButton(
              icon: Icon(Icons.audiotrack_rounded, size: 28.0 * iconScale),
              color: Colors.white,
              onPressed: () => _showTrackSelector(isAudio: true),
            ),
            IconButton(
              icon: Icon(Icons.subtitles_rounded, size: 28.0 * iconScale),
              color: Colors.white,
              onPressed: () => _showTrackSelector(isAudio: false),
            ),
          ],
        ),

        MaterialFullscreenButton(iconSize: 32.0 * iconScale),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _saveAndExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // THE VIDEO PLAYER
            MaterialVideoControlsTheme(
              normal: controlsTheme,
              fullscreen: controlsTheme,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                clipBehavior: Clip.none,
                child: Video(
                  controller: controller,
                  controls: MaterialVideoControls,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(
                      color: _subColor,
                      backgroundColor: _subBgColor,
                      fontSize: _subSize * (isTablet ? 1.5 : 1.0),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        if (_subBgColor == Colors.transparent)
                          const Shadow(
                            color: Colors.black,
                            blurRadius: 4.0,
                            offset: Offset(2, 2),
                          ),
                      ],
                    ),
                    padding: EdgeInsets.all(horizontalPadding),
                  ),
                ),
              ),
            ),

            // THE HDR / QUALITY BADGE (Sits right above the seek bar)
            if (_videoQualityBadge != null)
              Positioned(
                bottom:
                    bottomPadding + (40 * iconScale), // Hover above controls
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child:
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                _videoQualityBadge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 800.ms)
                            .slideY(begin: 0.5, curve: Curves.easeOutBack),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
