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
                    '경로 안내가 취소되었습니다',
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
                bottom: 130,
                left: 0,
                right: 0,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: colorScheme.surface.withOpacity(0.9),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.directions),
                                  label: const Text('경로 안내 시작'),
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
                                  ),
                                ),
                              ),
                              // 경로가 있을 때만 취소 버튼 표시
                              if (locationService.routeDistance.value > 0) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: ElevatedButton.icon(
                                    label: const Text('취소'),
                                    onPressed: () {
                                      // 경로 안내 취소
                                      locationService.cancelDirections();
                                      Get.snackbar(
                                        '안내',
                                        '경로 안내가 취소되었습니다',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.error,
                                      foregroundColor: colorScheme.onError,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 현재 위치 이동 버튼
            FloatingActionButton(
              heroTag: 'locationButton',
              mini: true,
              onPressed: () => locationService.getCurrentLocation(),
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.my_location,
                color: colorScheme.onPrimaryContainer,
              ),
              tooltip: '현재 위치로 이동',
            ),
            const SizedBox(width: 16),
            // 추적 시작/중지 버튼
            Obx(() {
              return FloatingActionButton(
                heroTag: 'trackingButton',
                onPressed: () {
                  if (locationService.isTracking.value) {
                    locationService.stopTracking();
                  } else {
                    locationService.startTracking();
                  }
                },
                backgroundColor: locationService.isTracking.value
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                child: Icon(
                  locationService.isTracking.value
                      ? Icons.stop_circle
                      : Icons.play_circle,
                  color: locationService.isTracking.value
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                ),
                tooltip: locationService.isTracking.value ? '추적 중지' : '추적 시작',
              );
            }),
            const SizedBox(width: 16),
            // 확대/축소 버튼
            FloatingActionButton(
              heroTag: 'zoomButton',
              mini: true,
              onPressed: () {
                // 확대/축소 컨트롤 표시 기능 구현
                Get.bottomSheet(
                  Container(
                    color: colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.add, color: colorScheme.primary),
                          title: Text('확대', style: theme.textTheme.titleMedium),
                          onTap: () {
                            // 확대 기능 구현
                            Get.back();
                          },
                        ),
                        ListTile(
                          leading:
                              Icon(Icons.remove, color: colorScheme.primary),
                          title: Text('축소', style: theme.textTheme.titleMedium),
                          onTap: () {
                            // 축소 기능 구현
                            Get.back();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.zoom_in_map,
                color: colorScheme.onPrimaryContainer,
              ),
              tooltip: '지도 확대/축소',
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

    List<LatLng> results = await locationService.searchPlacesByAddress(address);

    if (results.isNotEmpty) {
      locationService.setDestination(results.first, address);
      isSearchMode.value = false;
    }
  }

  // 지도 탭했을 때 해당 위치 목적지로 설정
  void _onMapTap(LatLng position) async {
    // 좌표로부터 주소 가져오기 기능 추가 가능
    locationService.setDestination(position, '선택한 위치');
  }
}
