import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';

class MapView extends StatelessWidget {
  // LocationService 인스턴스 가져오기
  final LocationService locationService = Get.find<LocationService>();

  // 검색창 컨트롤러
  final TextEditingController searchController = TextEditingController();

  // 검색 모드 상태 관리
  final RxBool isSearchMode = false.obs;

  MapView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withOpacity(0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Obx(() => isSearchMode.value
            ? _buildSearchField(context)
            : Text('위치 지도',
                style: TextStyle(
                    color: colorScheme.primary, fontWeight: FontWeight.bold))),
        leading: Obx(() {
          if (isSearchMode.value) {
            return IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.primary),
              onPressed: () {
                isSearchMode.value = false;
                searchController.clear();
              },
            );
          } else {
            return IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.primary),
              onPressed: () => Get.back(),
              tooltip: '이전 화면으로 돌아가기',
            );
          }
        }),
        actions: [
          Obx(() {
            if (isSearchMode.value) {
              return IconButton(
                icon: Icon(Icons.search, color: colorScheme.primary),
                onPressed: () => _searchPlace(searchController.text),
              );
            } else {
              return IconButton(
                icon: Icon(Icons.search, color: colorScheme.primary),
                onPressed: () => isSearchMode.value = true,
                tooltip: '주소 검색',
              );
            }
          }),
          // 경로가 있을 때만 취소 버튼 표시
          Obx(() {
            if (locationService.polylineCoordinates.isNotEmpty) {
              return IconButton(
                icon: Icon(Icons.close, color: colorScheme.error),
                onPressed: () {
                  locationService.cancelDirections();
                  Get.snackbar(
                    '안내',
                    '경로가 취소되었습니다',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                tooltip: '경로 취소',
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.primary),
            onPressed: () => locationService.resetMap(),
            tooltip: '지도 초기화',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 지도 표시
          Obx(() {
            if (locationService.currentLocation.value == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '위치 정보를 로드하는 중입니다...',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
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
                myLocationButtonEnabled: false, // 커스텀 버튼 사용
                onTap: _onMapTap,
                compassEnabled: true,
                zoomControlsEnabled: false, // 커스텀 컨트롤 사용
                minMaxZoomPreference:
                    const MinMaxZoomPreference(9, 19), // 줌 레벨 제한 완화
                onCameraMove: (CameraPosition position) {
                  // 카메라 이동 시 호출
                },
                onCameraIdle: () {
                  // 카메라 이동 완료 시 호출
                },
                onMapCreated: (GoogleMapController controller) {
                  // 지도 컨트롤러 설정
                  locationService.setMapController(controller);
                },
              );
            }
          }),

          // 상태 정보 및 경로 정보 표시
          Obx(() {
            if (locationService.isLoading.value) {
              return Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    color: colorScheme.surface.withOpacity(0.9),
                    elevation: 4,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 16),
                          Text('검색 중...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else if (locationService.errorMsg.value.isNotEmpty) {
              return Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    color: colorScheme.errorContainer,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              locationService.errorMsg.value,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),

          // 경로 정보 카드
          Obx(() {
            if (locationService.destinationAddress.value.isNotEmpty &&
                !locationService.isLoading.value) {
              return Positioned(
                bottom: 66,
                left: 0,
                right: 72,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: colorScheme.surface.withOpacity(0.95),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: colorScheme.primary.withOpacity(0.2), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationService.destinationAddress.value,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (locationService.routeDistance.value > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.straighten,
                                    color: colorScheme.secondary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '거리: ${(locationService.routeDistance.value / 1000).toStringAsFixed(2)} km',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        if (locationService.routeDuration.value > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.access_time,
                                    color: colorScheme.secondary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '예상 소요 시간: ${locationService.routeDuration.value} 분',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            children: [
                              // 추적 중이 아닐 때만 경로 안내 시작 버튼 표시
                              if (!locationService.isTracking.value)
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.navigation),
                                    label: const Text('경로 안내 시작',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      // 경로 안내 시작 기능 구현
                                      Get.snackbar(
                                        '안내',
                                        '경로 안내를 시작합니다',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                      locationService.startTracking();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              // 추적 중일 때는 추적 중지 버튼 표시
                              if (locationService.isTracking.value)
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.stop_circle),
                                    label: const Text('추적 중지',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      locationService.stopTracking();
                                      Get.snackbar(
                                        '안내',
                                        '추적이 중지되었습니다',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          colorScheme.primaryContainer,
                                      foregroundColor:
                                          colorScheme.onPrimaryContainer,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              // 경로가 있을 때 취소 버튼 표시
                              if (locationService.routeDistance.value > 0) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: ElevatedButton(
                                    child: const Text('취소',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      // 경로 안내 취소 - 완전히 초기화하도록 수정
                                      locationService.cancelDirections();
                                      Get.snackbar(
                                        '안내',
                                        '경로가 취소되었습니다',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                      foregroundColor: colorScheme.onError,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),

      // 하단 컨트롤 버튼 그룹
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, right: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 확대/축소 버튼 그룹
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 확대 버튼
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'zoomInButton',
                    mini: true,
                    onPressed: () {
                      if (locationService.mapController.value != null) {
                        locationService.mapController.value!.animateCamera(
                          CameraUpdate.zoomIn(),
                        );
                      }
                    },
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 22,
                    ),
                    tooltip: '지도 확대',
                  ),
                ),
                // 축소 버튼
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'zoomOutButton',
                    mini: true,
                    onPressed: () {
                      if (locationService.mapController.value != null) {
                        locationService.mapController.value!.animateCamera(
                          CameraUpdate.zoomOut(),
                        );
                      }
                    },
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 22,
                    ),
                    tooltip: '지도 축소',
                  ),
                ),
              ],
            ),
            // 현재 위치 이동 버튼
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'locationButton',
                onPressed: () => locationService.getCurrentLocation(),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.my_location,
                  size: 26,
                ),
                tooltip: '현재 위치로 이동',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 검색 필드 위젯
  Widget _buildSearchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: '목적지 주소 검색',
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: searchController.clear,
        ),
      ),
      style: TextStyle(color: colorScheme.onSurface),
      textInputAction: TextInputAction.search,
      onSubmitted: _searchPlace,
    );
  }

  // 주소로 장소 검색
  void _searchPlace(String address) async {
    if (address.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    try {
      Get.snackbar(
        '검색 중',
        '$address 검색 중입니다...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );

      List<LatLng> results =
          await locationService.searchPlacesByAddress(address);

      if (results.isNotEmpty) {
        locationService.setDestination(results.first, address);
        isSearchMode.value = false;
        debugPrint('✅ 검색 결과: ${results.first}, 주소: $address');
      } else {
        Get.snackbar(
          '검색 실패',
          '검색 결과가 없습니다. 다른 주소를 시도해보세요.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        '검색 오류',
        '검색 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      debugPrint('❌ 검색 오류: $e');
    }
  }

  // 지도 탭했을 때 해당 위치 목적지로 설정
  void _onMapTap(LatLng position) async {
    try {
      // 좌표로부터 주소 가져오기 기능 추가
      Get.snackbar(
        '위치 설정 중',
        '선택한 위치로 설정 중입니다...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );

      locationService.setDestination(position, '선택한 위치');
      debugPrint('✅ 지도 탭 위치: $position');
    } catch (e) {
      Get.snackbar(
        '위치 설정 오류',
        '위치 설정 중 오류가 발생했습니다',
        snackPosition: SnackPosition.BOTTOM,
      );
      debugPrint('❌ 지도 탭 오류: $e');
    }
  }
}
