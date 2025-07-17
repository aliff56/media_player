import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../services/video_service.dart';
import '../services/permission_service.dart';
import 'video_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AssetEntity> _videoAssets = [];
  VideoPlayerController? _controller;
  String? _currentVideoName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllVideos();
  }

  Future<void> _fetchAllVideos() async {
    setState(() {
      _loading = true;
    });
    final result = await VideoService.fetchAllVideos();
    if (result.permissionState == PermissionState.authorized ||
        result.permissionState == PermissionState.limited) {
      setState(() {
        _videoAssets = result.videos;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to access videos.'),
          ),
        );
      }
      if (result.permissionState == PermissionState.denied) {
        PhotoManager.openSetting();
      }
    }
  }

  void _playVideo(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null) {
      _controller?.dispose();
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {
            _currentVideoName =
                asset.title ?? file.path.split(Platform.pathSeparator).last;
          });
          _controller!.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Browser'),
        leading: (_controller != null || _currentVideoName != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _controller?.pause();
                    _controller = null;
                    _currentVideoName = null;
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllVideos,
            tooltip: 'Reload Videos',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videoAssets.isEmpty
          ? const Center(child: Text('No videos found on device.'))
          : Column(
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                if (_currentVideoName != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _currentVideoName!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _videoAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _videoAssets[index];
                      return FutureBuilder<File?>(
                        future: asset.file,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ListTile(
                              leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              title: Text('Loading...'),
                            );
                          }
                          final file = snapshot.data!;
                          return FutureBuilder<Uint8List?>(
                            future: asset.thumbnailDataWithSize(
                              ThumbnailSize(80, 80),
                            ),
                            builder: (context, thumbSnapshot) {
                              Widget leadingWidget;
                              if (thumbSnapshot.connectionState ==
                                      ConnectionState.done &&
                                  thumbSnapshot.hasData &&
                                  thumbSnapshot.data != null) {
                                leadingWidget = Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    // No boxShadow here
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      thumbSnapshot.data!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              } else {
                                leadingWidget = const SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0x000000,
                                      ).withOpacity(1),
                                      offset: const Offset(0, 11),
                                      blurRadius: 13,
                                      spreadRadius: -3,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: leadingWidget,
                                  title: Text(
                                    asset.title ??
                                        file.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                  ),
                                  onTap: () async {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VideoScreen(
                                          videoAssets: _videoAssets,
                                          initialIndex: index,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
