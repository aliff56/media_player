import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/audio_service.dart';
import 'audio_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

class AudioHomeScreen extends StatefulWidget {
  const AudioHomeScreen({Key? key}) : super(key: key);

  @override
  State<AudioHomeScreen> createState() => _AudioHomeScreenState();
}

class _AudioHomeScreenState extends State<AudioHomeScreen> with RouteAware {
  List<AssetEntity> _audioAssets = [];
  bool _loading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showFolders = false;
  Map<String, List<AssetEntity>> _folderMap = {};
  List<String> _folderList = [];
  String? _selectedFolder;
  Set<String> _favourites = {};
  List<String> _playlists = [];
  String? _selectedPlaylist;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _fetchAllAudios();
    _searchController.addListener(() => setState(() {}));
  }

  void _deduplicateAllPlaylists() {
    for (final playlist in _playlists) {
      final ids = _prefs.getStringList('playlist_$playlist') ?? [];
      final uniqueIds = ids.toSet().toList();
      if (ids.length != uniqueIds.length) {
        _prefs.setStringList('playlist_$playlist', uniqueIds);
      }
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavourites();
    _loadPlaylists();
    _deduplicateAllPlaylists();
  }

  void _loadFavourites() {
    final favs = _prefs.getStringList('audio_favourites') ?? [];
    setState(() {
      _favourites = favs.toSet();
    });
  }

  void _loadPlaylists() {
    final keys = _prefs.getStringList('audio_playlists') ?? [];
    setState(() {
      _playlists = keys;
    });
  }

  List<AssetEntity> _getPlaylistAudios(String playlist) {
    final ids = _prefs.getStringList('playlist_$playlist') ?? [];
    final uniqueIds = ids.toSet().toList();
    // Clean up duplicates in storage
    if (ids.length != uniqueIds.length) {
      _prefs.setStringList('playlist_$playlist', uniqueIds);
    }
    // Only show each audio once
    final seen = <String>{};
    final uniqueAudios = <AssetEntity>[];
    for (final a in _audioAssets) {
      if (uniqueIds.contains(a.id) && !seen.contains(a.id)) {
        seen.add(a.id);
        uniqueAudios.add(a);
      }
    }
    return uniqueAudios;
  }

  void _showPlaylistSelectDialog() {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('All Audio'),
                onTap: () {
                  setState(() => _selectedPlaylist = null);
                  Navigator.pop(c);
                },
              ),
              for (final playlist in _playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(playlist),
                  onTap: () {
                    setState(() => _selectedPlaylist = playlist);
                    Navigator.pop(c);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchAllAudios() async {
    setState(() => _loading = true);
    final result = await AudioService.fetchAllAudios();
    if (result.permissionState == PermissionState.authorized ||
        result.permissionState == PermissionState.limited) {
      // Ensure unique audio IDs
      final seen = <String>{};
      final uniqueAudios = <AssetEntity>[];
      for (final a in result.audios) {
        if (!seen.contains(a.id)) {
          seen.add(a.id);
          uniqueAudios.add(a);
        }
      }
      setState(() {
        _audioAssets = uniqueAudios;
        _loading = false;
      });
      _buildFolderMap(result.audios);
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required.')),
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
    setState(() {
      _folderMap = folderMap;
      _folderList = folderMap.keys.toList();
    });
  }

  void _startSearch() => setState(() => _isSearching = true);
  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
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
    _loadFavourites();
    _loadPlaylists();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<AssetEntity> audiosToShow = _isSearching
        ? _audioAssets.where((asset) {
            final title = asset.title?.toLowerCase() ?? '';
            final q = _searchController.text.toLowerCase();
            return title.contains(q);
          }).toList()
        : _audioAssets;
    if (_selectedPlaylist != null) {
      audiosToShow = _getPlaylistAudios(_selectedPlaylist!);
    }
    final List<AssetEntity> folderAudios =
        _selectedFolder != null && _folderMap[_selectedFolder!] != null
        ? List<AssetEntity>.from(_folderMap[_selectedFolder!]!)
        : <AssetEntity>[];
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search audio...',
                  border: InputBorder.none,
                ),
              )
            : const Text('Audio Browser'),
        actions: [
          IconButton(
            icon: Icon(_showFolders ? Icons.list : Icons.folder),
            tooltip: _showFolders ? 'Show All Audio' : 'Browse by Folder',
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
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.queue_music),
                        label: const Text('Playlist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        onPressed: _showPlaylistSelectDialog,
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        onPressed: _fetchAllAudios,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _showFolders
                      ? _selectedFolder == null
                            ? ListView.builder(
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '$count audio file${count == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedFolder = folder;
                                      });
                                    },
                                  );
                                },
                              )
                            : Column(
                                children: [
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
                                      itemCount: folderAudios.length,
                                      itemBuilder: (context, index) {
                                        final asset = folderAudios[index];
                                        return FutureBuilder<File?>(
                                          future: asset.file,
                                          builder: (context, snap) {
                                            if (!snap.hasData) {
                                              return const ListTile(
                                                title: Text('Loading...'),
                                              );
                                            }
                                            final file = snap.data!;
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.music_note,
                                              ),
                                              title: Text(
                                                asset.title ??
                                                    file.path.split('/').last,
                                              ),
                                              trailing:
                                                  _favourites.contains(asset.id)
                                                  ? const Icon(
                                                      Icons.star,
                                                      color: Colors.amber,
                                                    )
                                                  : null,
                                              onTap: () {
                                                final fullList = folderAudios;
                                                final initialIndex = fullList
                                                    .indexWhere(
                                                      (a) => a.id == asset.id,
                                                    );
                                                if (initialIndex != -1) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AudioPlayerScreen(
                                                            audios: fullList,
                                                            initialIndex:
                                                                initialIndex,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                      : audiosToShow.isEmpty
                      ? Center(
                          child: Text(
                            _isSearching ? 'No results.' : 'No audio found.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: audiosToShow.length,
                          itemBuilder: (context, index) {
                            final asset = audiosToShow[index];
                            return FutureBuilder<File?>(
                              future: asset.file,
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return const ListTile(
                                    title: Text('Loading...'),
                                  );
                                }
                                final file = snap.data!;
                                return ListTile(
                                  leading: const Icon(Icons.music_note),
                                  title: Text(
                                    asset.title ?? file.path.split('/').last,
                                  ),
                                  trailing: _favourites.contains(asset.id)
                                      ? const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        )
                                      : null,
                                  onTap: () {
                                    final fullList = audiosToShow;
                                    final initialIndex = fullList.indexWhere(
                                      (a) => a.id == asset.id,
                                    );
                                    if (initialIndex != -1) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AudioPlayerScreen(
                                            audios: fullList,
                                            initialIndex: initialIndex,
                                          ),
                                        ),
                                      );
                                    }
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
