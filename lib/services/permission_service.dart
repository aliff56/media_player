import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  static Future<PermissionState> requestVideoPermission() async {
    return await PhotoManager.requestPermissionExtend();
  }
}
