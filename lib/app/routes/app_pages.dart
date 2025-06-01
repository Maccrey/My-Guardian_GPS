import 'package:get/get.dart';
import 'package:watch_over/views/sos/sos_location_map_view.dart';
import 'package:watch_over/views/location_sharing/location_sharing_list_view.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: '/sos-location-map',
      page: () => const SOSLocationMapView(),
    ),
    GetPage(
      name: '/location-sharing-list',
      page: () => LocationSharingListView(),
    ),
    // 다른 라우트는 여기에 추가
  ];
}
