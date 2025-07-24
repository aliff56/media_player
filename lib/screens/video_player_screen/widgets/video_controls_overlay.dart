import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'top_controls.dart';
import 'bottom_controls.dart';
import 'status_overlays.dart';

class VideoControlsOverlay extends StatelessWidget {
  final Player player;
  final bool isPlayerInitialized;
  final bool showControls;
  final bool isLocked;
  final VoidCallback toggleLock;
  final VoidCallback onMoreOptions;
  final VoidCallback toggleOrientation;
  final bool isLandscape;
  final VoidCallback onEnablePiP;
  final VoidCallback onSwitchToAudio;
  final VoidCallback onCaptureScreenshot;
  final VoidCallback onMute;
  final bool isMuted;
  final VoidCallback onPlayPrevious;
  final bool canPlayPrevious;
  final VoidCallback onPlayNext;
  final bool canPlayNext;
  final VoidCallback cycleAspectMode;
  final VoidCallback startHideTimer;

  final double seekOffsetSeconds;
  final double currentVolume;
  final double currentBrightness;
  final bool showSeekOverlay;
  final bool showVolumeOverlay;
  final bool showBrightnessOverlay;
  final String? aspectModeOverlayText;

  final String Function(Duration) formatDuration;
  final List<int> bookmarks;
  final void Function(int ms) onBookmarkTap;

  const VideoControlsOverlay({
    Key? key,
    required this.player,
    required this.isPlayerInitialized,
    required this.showControls,
    required this.isLocked,
    required this.toggleLock,
    required this.onMoreOptions,
    required this.toggleOrientation,
    required this.isLandscape,
    required this.onEnablePiP,
    required this.onSwitchToAudio,
    required this.onCaptureScreenshot,
    required this.onMute,
    required this.isMuted,
    required this.onPlayPrevious,
    required this.canPlayPrevious,
    required this.onPlayNext,
    required this.canPlayNext,
    required this.cycleAspectMode,
    required this.seekOffsetSeconds,
    required this.currentVolume,
    required this.currentBrightness,
    required this.showSeekOverlay,
    required this.showVolumeOverlay,
    required this.showBrightnessOverlay,
    required this.formatDuration,
    required this.startHideTimer,
    required this.bookmarks,
    required this.onBookmarkTap,
    this.aspectModeOverlayText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showSeekOverlay && isPlayerInitialized)
          StatusOverlays.seek(offset: seekOffsetSeconds),
        if (showVolumeOverlay) StatusOverlays.volume(volume: currentVolume),
        if (showBrightnessOverlay) StatusOverlays.brightness(currentBrightness),
        if (aspectModeOverlayText != null)
          StatusOverlays.aspectRatio(aspectModeOverlayText!),

        if (isLocked)
          Positioned(
            top: 32,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.lock, color: Colors.white),
              onPressed: toggleLock,
              tooltip: 'Unlock',
            ),
          ),

        if (showControls && !isLocked) ...[
          TopControls(
            onMoreOptions: onMoreOptions,
            toggleOrientation: toggleOrientation,
            isLandscape: isLandscape,
            onEnablePiP: onEnablePiP,
            onSwitchToAudio: onSwitchToAudio,
            toggleLock: toggleLock,
            cycleAspectMode: cycleAspectMode,
          ),
          BottomControls(
            player: player,
            isPlayerInitialized: isPlayerInitialized,
            onCaptureScreenshot: onCaptureScreenshot,
            onMute: onMute,
            isMuted: isMuted,
            onPlayPrevious: onPlayPrevious,
            canPlayPrevious: canPlayPrevious,
            onPlayNext: onPlayNext,
            canPlayNext: canPlayNext,
            formatDuration: formatDuration,
            startHideTimer: startHideTimer,
            bookmarks: bookmarks,
            onBookmarkTap: onBookmarkTap,
          ),
        ],
      ],
    );
  }
}
