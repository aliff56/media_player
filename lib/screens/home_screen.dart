import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/video_service.dart';
import '../services/permission_service.dart';
import 'video_player_screen/video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AssetEntity> _videoAssets = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late final Player player;
  late final VideoController videoController;
  String? _currentVideoName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    player = Player();
    videoController = VideoController(player);
    _fetchAllVideos();
    // The listener just triggers a rebuild.
    _searchController.addListener(() {
      setState(() {});
    });
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

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  void _playVideo(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null) {
      await player.open(Media(file.path), play: true);
      setState(() {
        _currentVideoName =
            asset.title ?? file.path.split(Platform.pathSeparator).last;
      });
    }
  }

  @override
  void dispose() {
    player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter the list directly inside the build method.
    final videosToShow = _isSearching
        ? _videoAssets.where((asset) {
            final title = asset.title?.toLowerCase() ?? '';
            final query = _searchController.text.toLowerCase();
            return title.contains(query);
          }).toList()
        : _videoAssets;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search videos...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: TextStyle(color: Colors.white),
              )
            : const Text('Video Browser'),
        leading:
            (player.state.playlist.medias.isNotEmpty ||
                _currentVideoName != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  player.stop();
                  setState(() {
                    _currentVideoName = null;
                  });
                },
              )
            : null,
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchAllVideos,
                  tooltip: 'Reload Videos',
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : videosToShow.isEmpty
          ? Center(
              child: Text(
                _isSearching
                    ? 'No results found.'
                    : 'No videos found on device.',
              ),
            )
          : Column(
              children: [
                if (player.state.playlist.medias.isNotEmpty)
                  Flexible(child: Video(controller: videoController)),
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
                    itemCount: videosToShow.length,
                    itemBuilder: (context, index) {
                      final asset = videosToShow[index];
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
                                  color: Colors
                                      .grey[850], // Changed from Colors.white
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        0.4,
                                      ), // Softened shadow
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ), // Changed text color
                                  ),
                                  onTap: () {
                                    // Always pass the full list of assets
                                    final fullList = _videoAssets;
                                    // Find the actual index in the full list
                                    final initialIndex = fullList.indexWhere(
                                      (a) => a.id == asset.id,
                                    );

                                    if (initialIndex != -1) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => VideoPlayerScreen(
                                            videoAssets: fullList,
                                            initialIndex: initialIndex,
                                          ),
                                        ),
                                      );
                                    }
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
