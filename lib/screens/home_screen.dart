import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/video_service.dart';
import '../services/permission_service.dart';
import 'video_player_screen/video_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<AssetEntity> _videoAssets = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late final Player player;
  late final VideoController videoController;
  String? _currentVideoName;
  bool _loading = true;
  bool _showFolders = false;
  Map<String, List<AssetEntity>> _folderMap = {};
  List<String> _folderList = [];
  String? _selectedFolder;
  Set<String> _favourites = {};
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    player = Player();
    videoController = VideoController(player);
    _initPrefs();
    _fetchAllVideos();
    // The listener just triggers a rebuild.
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen
    _fetchAllVideos();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavourites();
  }

  void _loadFavourites() {
    final favs = _prefs.getStringList('favourites') ?? [];
    setState(() {
      _favourites = favs.toSet();
    });
  }

  Future<void> _fetchAllVideos() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }
    final result = await VideoService.fetchAllVideos();
    if (result.permissionState == PermissionState.authorized ||
        result.permissionState == PermissionState.limited) {
      if (mounted) {
        setState(() {
          _videoAssets = result.videos;
          _loading = false;
        });
      }
      _buildFolderMap(result.videos);
      _loadFavourites();
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

  void _buildFolderMap(List<AssetEntity> assets) async {
    final Map<String, List<AssetEntity>> folderMap = {};
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) {
        final dir = file.parent.path;
        folderMap.putIfAbsent(dir, () => []).add(asset);
      }
    }
    if (mounted) {
      setState(() {
        _folderMap = folderMap;
        _folderList = folderMap.keys.toList();
      });
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
  Widget build(BuildContext context) {
    // Filter the list directly inside the build method.
    final videosToShow = _isSearching
        ? _videoAssets.where((asset) {
            final title = asset.title?.toLowerCase() ?? '';
            final query = _searchController.text.toLowerCase();
            return title.contains(query);
          }).toList()
        : _videoAssets;
    final List<AssetEntity> folderVideos =
        _selectedFolder != null && _folderMap[_selectedFolder!] != null
        ? List<AssetEntity>.from(_folderMap[_selectedFolder!]!)
        : <AssetEntity>[];

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
        actions: [
          IconButton(
            icon: Icon(_showFolders ? Icons.list : Icons.folder),
            tooltip: _showFolders ? 'Show All Videos' : 'Browse by Folder',
            onPressed: () {
              setState(() {
                _showFolders = !_showFolders;
                _selectedFolder = null;
              });
            },
          ),
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAllVideos,
              tooltip: 'Reload Videos',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showFolders)
                  if (_selectedFolder == null)
                    // Folders list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _folderList.length,
                        itemBuilder: (context, index) {
                          final folder = _folderList[index];
                          final count = _folderMap[folder]?.length ?? 0;
                          return ListTile(
                            leading: const Icon(
                              Icons.folder,
                              color: Colors.amber,
                            ),
                            title: Text(
                              folder.split(Platform.pathSeparator).last,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '$count video${count == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedFolder = folder;
                              });
                            },
                          );
                        },
                      ),
                    )
                  else ...[
                    ListTile(
                      leading: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Back to Folders',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedFolder = null;
                        });
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: folderVideos.length,
                        itemBuilder: (context, index) {
                          final asset = folderVideos[index];
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
                                  return ListTile(
                                    leading: leadingWidget,
                                    title: Text(
                                      asset.title ??
                                          file.path
                                              .split(Platform.pathSeparator)
                                              .last,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () async {
                                      final fullList = folderVideos;
                                      final initialIndex = fullList.indexWhere(
                                        (a) => a.id == asset.id,
                                      );
                                      if (initialIndex != -1) {
                                        final result =
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    VideoPlayerScreen(
                                                      videoAssets: fullList,
                                                      initialIndex:
                                                          initialIndex,
                                                    ),
                                              ),
                                            );
                                        if (result == true) {
                                          _loadFavourites();
                                          setState(() {});
                                        }
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ]
                else if (videosToShow.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No videos found.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                else
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
                                  leadingWidget = Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            thumbSnapshot.data!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      if (_favourites.contains(asset.id))
                                        const Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 24,
                                          ),
                                        ),
                                    ],
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
                                return ListTile(
                                  leading: leadingWidget,
                                  title: Text(
                                    asset.title ??
                                        file.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () async {
                                    final fullList = _videoAssets;
                                    final initialIndex = fullList.indexWhere(
                                      (a) => a.id == asset.id,
                                    );
                                    if (initialIndex != -1) {
                                      final result = await Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (_) => VideoPlayerScreen(
                                                videoAssets: fullList,
                                                initialIndex: initialIndex,
                                              ),
                                            ),
                                          );
                                      if (result == true) {
                                        _loadFavourites();
                                        setState(() {});
                                      }
                                    }
                                  },
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
