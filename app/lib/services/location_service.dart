import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Lấy vị trí GPS hiện tại của thiết bị
  Future<Position?> getCurrentLocation({bool requestIfNeeded = true}) async {
    try {
      // 1. Kiểm tra xem thiết bị đã bật định vị GPS chưa
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS Service chưa được bật trên thiết bị');
        return null;
      }

      // 2. Kiểm tra quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestIfNeeded) return null;
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Người dùng từ chối cấp quyền vị trí');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Quyền vị trí bị từ chối vĩnh viễn trong Cài đặt');
        return null;
      }

      // 3. Lấy toạ độ GPS chính xác (dùng LocationAccuracy.medium để tương thích tốt với Android Emulator)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _lastKnownPosition = position;
      debugPrint('[LocationService] -> GPS tọa độ thực tế: Lat=${position.latitude}, Lng=${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('[LocationService Error]: $e');
      return _lastKnownPosition;
    }
  }

  /// Tính khoảng cách giữa 2 điểm GPS (đơn vị: mét)
  double distanceBetween(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Định dạng khoảng cách sang chuỗi thân thiện (ví dụ: '350 m' hoặc '2.4 km')
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}
