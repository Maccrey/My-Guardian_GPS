import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';

class MapView extends StatelessWidget {
  // LocationService 인스턴스 가져오기
  final LocationService locationService = Get.find<LocationService>();

  // 검색창 컨트롤러
  final TextEditingController searchController = TextEditingController();

  MapView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 지도'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => locationService.resetMap(),
            tooltip: '지도 초기화',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: '목적지 주소 검색',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchPlace(searchController.text),
                ),
              ],
            ),
          ),

          // 현재 상태 정보 표시 (로딩, 오류, 경로 정보)
          Obx(() {
            if (locationService.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (locationService.errorMsg.value.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  locationService.errorMsg.value,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            } else if (locationService.destinationAddress.value.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('목적지: ${locationService.destinationAddress.value}'),
                    if (locationService.routeDistance.value > 0)
                      Text(
                          '거리: ${(locationService.routeDistance.value / 1000).toStringAsFixed(2)} km'),
                    if (locationService.routeDuration.value > 0)
                      Text(
                          '예상 소요 시간: ${locationService.routeDuration.value} 분'),
                  ],
                ),
              );
            } else {
              return const SizedBox(height: 8);
            }
          }),

          // 지도 표시
          Expanded(
            child: Obx(() {
              if (locationService.currentLocation.value == null) {
                return const Center(
                  child: Text('위치 정보를 로드하는 중입니다...'),
                );
              } else {
                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: locationService.currentLocation.value!,
                    zoom: 15,
                  ),
                  markers: locationService.markers,
                  polylines: locationService.polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: _onMapTap,
                );
              }
            }),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        return FloatingActionButton(
          onPressed: () {
            if (locationService.isTracking.value) {
              locationService.stopTracking();
            } else {
              locationService.startTracking();
            }
          },
          child: Icon(
            locationService.isTracking.value
                ? Icons.stop_circle
                : Icons.play_circle,
          ),
          tooltip: locationService.isTracking.value ? '추적 중지' : '추적 시작',
        );
      }),
    );
  }

  // 주소로 장소 검색
  void _searchPlace(String address) async {
    if (address.isEmpty) return;

    List<LatLng> results = await locationService.searchPlacesByAddress(address);

    if (results.isNotEmpty) {
      locationService.setDestination(results.first, address);
    }
  }

  // 지도 탭했을 때 해당 위치 목적지로 설정
  void _onMapTap(LatLng position) async {
    // 좌표로부터 주소 가져오기 기능 추가 가능
    locationService.setDestination(position, '선택한 위치');
  }
}
