import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/audio_service.dart';
import 'audio_player_screen.dart';

class AudioHomeScreen extends StatefulWidget {
  const AudioHomeScreen({Key? key}) : super(key: key);

  @override
  State<AudioHomeScreen> createState() => _AudioHomeScreenState();
}

class _AudioHomeScreenState extends State<AudioHomeScreen> {
  List<AssetEntity> _audioAssets = [];
  bool _loading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showFolders = false;
  Map<String, List<AssetEntity>> _folderMap = {};
  List<String> _folderList = [];
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _fetchAllAudios();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _fetchAllAudios() async {
    setState(() => _loading = true);
    final result = await AudioService.fetchAllAudios();
    if (result.permissionState == PermissionState.authorized ||
        result.permissionState == PermissionState.limited) {
      setState(() {
        _audioAssets = result.audios;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audiosToShow = _isSearching
        ? _audioAssets.where((asset) {
            final title = asset.title?.toLowerCase() ?? '';
            final q = _searchController.text.toLowerCase();
            return title.contains(q);
          }).toList()
        : _audioAssets;
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
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAllAudios,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showFolders
          ? _selectedFolder == null
                ? ListView.builder(
                    itemCount: _folderList.length,
                    itemBuilder: (context, index) {
                      final folder = _folderList[index];
                      final count = _folderMap[folder]?.length ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.amber),
                        title: Text(
                          folder.split(Platform.pathSeparator).last,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '$count audio file${count == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white70),
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
                                  leading: const Icon(Icons.music_note),
                                  title: Text(
                                    asset.title ?? file.path.split('/').last,
                                  ),
                                  onTap: () {
                                    final fullList = folderAudios;
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
                  )
          : audiosToShow.isEmpty
          ? Center(
              child: Text(_isSearching ? 'No results.' : 'No audio found.'),
            )
          : ListView.builder(
              itemCount: audiosToShow.length,
              itemBuilder: (context, index) {
                final asset = audiosToShow[index];
                return FutureBuilder<File?>(
                  future: asset.file,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const ListTile(title: Text('Loading...'));
                    }
                    final file = snap.data!;
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(asset.title ?? file.path.split('/').last),
                      onTap: () {
                        final fullList = _audioAssets;
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
    );
  }
}
