import 'package:photo_manager/photo_manager.dart';

class VideoFetchResult {
  final List<AssetEntity> videos;
  final PermissionState permissionState;
  VideoFetchResult({required this.videos, required this.permissionState});
}

class VideoService {
  static Future<VideoFetchResult> fetchAllVideos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    List<AssetEntity> videos = [];
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        filterOption: FilterOptionGroup(
          videoOption: const FilterOption(needTitle: true),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      for (final album in albums) {
        final List<AssetEntity> albumVideos = await album.getAssetListPaged(
          page: 0,
          size: 1000,
        );
        videos.addAll(albumVideos);
      }
    }
    return VideoFetchResult(videos: videos, permissionState: ps);
  }
}
