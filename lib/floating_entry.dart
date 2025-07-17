import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FloatingVideoPlayer extends StatefulWidget {
  final String videoPath;
  const FloatingVideoPlayer({Key? key, required this.videoPath})
    : super(key: key);

  @override
  State<FloatingVideoPlayer> createState() => _FloatingVideoPlayerState();
}

class _FloatingVideoPlayerState extends State<FloatingVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _initialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

// This is the entry point for the floating window
void main(List<String> args) {
  final videoPath = args.isNotEmpty ? args[0] : '';
  runApp(FloatingVideoPlayer(videoPath: videoPath));
}
