import 'package:photo_manager/photo_manager.dart';

class AudioFetchResult {
  final List<AssetEntity> audios;
  final PermissionState permissionState;
  AudioFetchResult({required this.audios, required this.permissionState});
}

class AudioService {
  static Future<AudioFetchResult> fetchAllAudios() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    List<AssetEntity> audios = [];
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.audio,
        filterOption: FilterOptionGroup(
          audioOption: const FilterOption(needTitle: true),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      for (final album in albums) {
        final List<AssetEntity> albumAudios = await album.getAssetListPaged(
          page: 0,
          size: 1000,
        );
        audios.addAll(albumAudios);
      }
    }
    return AudioFetchResult(audios: audios, permissionState: ps);
  }
}
