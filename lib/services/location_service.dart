import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_location_model.dart'; // SharedLocation 모델
import '../constants/api_keys.dart';
import 'map_api_service.dart';

// 검색 결과 항목 클래스
class SearchResult {
  final LatLng location;
  final String address;

  SearchResult({required this.location, required this.address});
}

/// 위치 관련 서비스 클래스 - 위치 추적 및 경로 안내 기능 제공
/// IMPORTANT: 지도 기능의 핵심 클래스입니다. 무분별한 수정 시 앱 기능이 손상될 수 있습니다.
class LocationService extends GetxController {
  // 현재 위치
  final Rx<LatLng?> currentLocation = Rx<LatLng?>(null);

  // 목적지 위치
  final Rx<LatLng?> destinationLocation = Rx<LatLng?>(null);

  // 지도 컨트롤러
  final Rx<GoogleMapController?> mapController = Rx<GoogleMapController?>(null);

  // 경로 표시를 위한 폴리라인 좌표 목록
  final RxList<LatLng> polylineCoordinates = <LatLng>[].obs;

  // 지도에 표시할 마커 목록
  final RxSet<Marker> markers = <Marker>{}.obs;

  // 지도에 표시할 폴리라인 목록
  final RxSet<Polyline> polylines = <Polyline>{}.obs;

  // 사용자 위치 기록 (경로 추적용)
  final RxList<LatLng> locationHistory = <LatLng>[].obs;

  // 목적지 주소 텍스트
  final RxString destinationAddress = ''.obs;

  // 위치 추적 상태
  final RxBool isTracking = false.obs;

  // 위치 서비스 오류 메시지
  final RxString errorMsg = ''.obs;

  // 위치 서비스 로딩 상태
  final RxBool isLoading = false.obs;

  // 검색 결과 목록
  final RxList<SearchResult> searchResults = <SearchResult>[].obs;

  // 경로 거리 (미터)
  final RxDouble routeDistance = 0.0.obs;

  // 경로 예상 시간 (분)
  final RxInt routeDuration = 0.obs;

  // Google Maps API 키
  late final String _apiKey;

  // 정기적인 위치 업데이트를 위한 타이머
  Timer? _locationTimer;

  // 위치 스트림 구독
  StreamSubscription<Position>? _positionStream;

  // 폴리라인 색상 ID
  int _polylineIdCounter = 0;

  // 폴리라인 ID 생성
  String _getPolylineId() => 'polyline_${_polylineIdCounter++}';

  // 마커 ID 카운터
  int _markerIdCounter = 0;

  // 마커 ID 생성
  String _getMarkerId() => 'search_result_${_markerIdCounter++}';

  // 지도 경계 제한 설정
  LatLngBounds? _mapBounds;

  // 위치 서비스 활성화 상태 (설정 화면과 연동)
  final RxBool isLocationServiceEnabled = true.obs;

  // 메시지에서 공유된 위치 저장 목록
  final RxList<SharedLocation> sharedLocations = <SharedLocation>[].obs;

  // 공유된 위치를 표시할지 여부
  final RxBool showSharedLocations = true.obs;

  @override
  void onInit() {
    super.onInit();

    // .env 파일에서 API 키 로드
    try {
      final envApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (envApiKey == null || envApiKey.isEmpty) {
        // .env 파일에서 로드 실패 시 상수 파일의 기본값 사용
        _apiKey = ApiKeys.googleMapsApiKey;
        debugPrint('⚠️ 경고: .env 파일에서 API 키를 로드할 수 없어 기본값을 사용합니다.');
      } else {
        _apiKey = envApiKey;
        debugPrint('✅ Google Maps API 키 로드 성공 (.env 파일)');
      }

      // 플랫폼별 API 키 설정
      MapApiService.setGoogleMapsApiKeyForPlatform().then((success) {
        if (success) {
          debugPrint('✅ LocationService에서 플랫폼별 API 키 설정 성공');
        } else {
          debugPrint('⚠️ LocationService에서 플랫폼별 API 키 설정 실패');
        }
      }).catchError((e) {
        debugPrint('❌ LocationService에서 플랫폼별 API 키 설정 중 오류: $e');
      });
    } catch (e) {
      // 예외 발생 시 상수 파일의 기본값 사용
      _apiKey = ApiKeys.googleMapsApiKey;
      debugPrint('❌ Google Maps API 키 로드 실패: $e - 기본값을 사용합니다.');
    }

    // 초기 위치 서비스 상태 확인
    _checkInitialLocationServiceState();

    // 초기화 시 위치 권한 체크 및 현재 위치 가져오기
    if (isLocationServiceEnabled.value) {
      _checkLocationPermission();
    }

    // 저장된 공유 위치 불러오기
    _loadSharedLocations();
  }

  // 초기 위치 서비스 상태 확인
  Future<void> _checkInitialLocationServiceState() async {
    try {
      // SharedPreferences에서 위치 서비스 설정 확인
      final prefs = await SharedPreferences.getInstance();
      isLocationServiceEnabled.value =
          prefs.getBool('isLocationEnabled') ?? true;

      // 위치 서비스 상태에 따라 지도 기능 초기화
      debugPrint(
          '✅ 위치 서비스 초기 상태: ${isLocationServiceEnabled.value ? "활성화" : "비활성화"}');
    } catch (e) {
      debugPrint('⚠️ 위치 서비스 상태 확인 오류: $e');
      isLocationServiceEnabled.value = true; // 오류 시 기본적으로 활성화
    }
  }

  // 위치 서비스 활성화/비활성화 설정
  void setLocationServiceEnabled(bool enabled) {
    isLocationServiceEnabled.value = enabled;

    if (enabled) {
      // 위치 서비스 활성화 시 권한 확인 및 위치 가져오기
      _checkLocationPermission();
      getCurrentLocation();
      debugPrint('✅ 위치 서비스 활성화됨');
    } else {
      // 위치 서비스 비활성화 시 추적 중지 및 기존 데이터 정리
      stopTracking();
      errorMsg.value = '위치 서비스가 설정에서 비활성화되었습니다.';
      debugPrint('✅ 위치 서비스 비활성화됨');
    }
  }

  // 위치 권한 확인 및 요청
  Future<bool> _checkLocationPermission() async {
    // 앱 내 위치 서비스가 비활성화된 경우, 권한 확인 생략
    if (!isLocationServiceEnabled.value) {
      errorMsg.value = '위치 서비스가 설정에서 비활성화되었습니다.';
      return false;
    }

    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 위치 서비스가 활성화되어 있는지 확인
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        errorMsg.value = '위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해주세요.';
        return false;
      }

      // 위치 권한 확인
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 권한이 거부된 경우 권한 요청
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          errorMsg.value = '위치 권한이 거부되었습니다. 설정에서 위치 권한을 허용해주세요.';
          return false;
        }
      }

      // 권한이 영구적으로 거부된 경우
      if (permission == LocationPermission.deniedForever) {
        errorMsg.value = '위치 권한이 영구적으로 거부되었습니다. 설정에서 위치 권한을 허용해주세요.';
        return false;
      }

      // 현재 위치 가져오기
      await getCurrentLocation();
      return true;
    } catch (e) {
      errorMsg.value = '위치 권한 확인 중 오류가 발생했습니다: $e';
      return false;
    }
  }

  // 현재 위치 가져오기
  Future<void> getCurrentLocation() async {
    try {
      isLoading.value = true;
      errorMsg.value = '';

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng location = LatLng(position.latitude, position.longitude);
      currentLocation.value = location;

      // 현재 위치를 기록에 추가
      if (isTracking.value) {
        locationHistory.add(location);
      }

      // 현재 위치 마커 추가
      _updateCurrentLocationMarker();

      // 현재 위치로 지도 이동
      moveToLocation(location);

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMsg.value = '현재 위치를 가져오는 중 오류가 발생했습니다: $e';
    }
  }

  // 현재 위치 마커 업데이트
  void _updateCurrentLocationMarker() {
    if (currentLocation.value == null) return;

    // 기존 현재 위치 마커 제거
    markers
        .removeWhere((marker) => marker.markerId.value == 'current_location');

    // 현재 위치 마커 추가
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: currentLocation.value!,
        infoWindow: const InfoWindow(title: '현재 위치'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
  }

  // 위치 추적 시작
  void startTracking() {
    if (isTracking.value) return;

    isTracking.value = true;
    locationHistory.clear();

    if (currentLocation.value != null) {
      locationHistory.add(currentLocation.value!);
    }

    // 위치 변경 이벤트 구독
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10미터마다 업데이트
      ),
    ).listen((Position position) {
      // 새로운 위치 업데이트
      LatLng newLocation = LatLng(position.latitude, position.longitude);
      currentLocation.value = newLocation;
      locationHistory.add(newLocation);

      // 현재 위치 마커 업데이트
      _updateCurrentLocationMarker();

      // 이동 경로 폴리라인 업데이트
      _updateRoutePolyline();
    });
  }

  // 위치 추적 중지
  void stopTracking() {
    isTracking.value = false;
    _positionStream?.cancel();
    _positionStream = null;
  }

  // 이동 경로 폴리라인 업데이트
  void _updateRoutePolyline() {
    if (locationHistory.length < 2) return;

    // 기존 이동 경로 폴리라인 제거
    polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'route_history');

    // 이동 경로 폴리라인 추가
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route_history'),
        points: locationHistory.toList(),
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  // 주소로 위치 검색
  Future<List<LatLng>> searchPlacesByAddress(String address) async {
    try {
      isLoading.value = true;
      errorMsg.value = '';
      searchResults.clear();

      List<Location> locations = await locationFromAddress(address);

      List<LatLng> results = locations
          .map((location) => LatLng(location.latitude, location.longitude))
          .toList();

      // 검색 결과 저장
      if (results.isNotEmpty) {
        for (int i = 0; i < results.length; i++) {
          searchResults.add(SearchResult(
            location: results[i],
            address: i == 0 ? address : '$address (대안 ${i + 1})',
          ));
        }

        // 검색 결과 마커 생성
        _addSearchResultMarkers();

        // 첫 번째 검색 결과로 지도 이동
        if (results.isNotEmpty) {
          moveToLocation(results.first);
        }
      }

      isLoading.value = false;
      return results;
    } catch (e) {
      isLoading.value = false;
      errorMsg.value = '주소 검색 중 오류가 발생했습니다: $e';
      return [];
    }
  }

  // 검색 결과 마커 추가
  void _addSearchResultMarkers() {
    // 기존 검색 결과 마커 제거
    markers.removeWhere(
        (marker) => marker.markerId.value.startsWith('search_result_'));

    // 새 검색 결과 마커 추가
    for (int i = 0; i < searchResults.length; i++) {
      final SearchResult result = searchResults[i];
      final markerId = _getMarkerId();

      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: result.location,
          infoWindow: InfoWindow(
            title: '검색 결과 ${i + 1}',
            snippet: result.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              i == 0 ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueOrange),
          onTap: () {
            // 마커 탭 시 해당 위치로 경로 설정
            setDestination(result.location, result.address);
          },
        ),
      );
    }
  }

  // IMPORTANT: 목적지 설정 함수 - 이 부분을 변경하지 마세요
  // 경로 안내의 핵심 기능을 담당하는 중요 함수입니다
  void setDestination(LatLng destination, String address) {
    // 경계 제한 일시적 비활성화 또는 확장
    if (_mapBounds != null) {
      // 목적지가 현재 경계 밖이면 경계를 확장
      if (!_isLocationWithinBounds(destination)) {
        _expandBoundsToIncludeLocation(destination);
      }
    }

    destinationLocation.value = destination;
    destinationAddress.value = address;

    // 목적지 마커 추가
    markers.removeWhere((marker) => marker.markerId.value == 'destination');
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: '목적지', snippet: address),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // 경로 요청
    if (currentLocation.value != null) {
      getDirections(currentLocation.value!, destination);
    } else {
      // 현재 위치가 없는 경우 먼저 가져오기
      getCurrentLocation().then((_) {
        if (currentLocation.value != null) {
          getDirections(currentLocation.value!, destination);
        }
      });
    }

    // 도착지로 지도 이동
    moveToLocation(destination);

    debugPrint('✅ 목적지 설정: $address, 좌표: $destination');
  }

  // IMPORTANT: 경계 확인 함수 - 이 부분을 변경하지 마세요
  bool _isLocationWithinBounds(LatLng location) {
    if (_mapBounds == null) return true;

    return location.latitude >= _mapBounds!.southwest.latitude &&
        location.latitude <= _mapBounds!.northeast.latitude &&
        location.longitude >= _mapBounds!.southwest.longitude &&
        location.longitude <= _mapBounds!.northeast.longitude;
  }

  // IMPORTANT: 경계 확장 함수 - 이 부분을 변경하지 마세요
  void _expandBoundsToIncludeLocation(LatLng location) {
    if (_mapBounds == null) return;

    // 현재 경계와 새 위치를 모두 포함하는 새 경계 계산
    double swLat =
        min(_mapBounds!.southwest.latitude, location.latitude - 0.05);
    double swLng =
        min(_mapBounds!.southwest.longitude, location.longitude - 0.05);
    double neLat =
        max(_mapBounds!.northeast.latitude, location.latitude + 0.05);
    double neLng =
        max(_mapBounds!.northeast.longitude, location.longitude + 0.05);

    _mapBounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );

    debugPrint('✅ 경계 확장: $_mapBounds');
  }

  // IMPORTANT: 경로 가져오기 함수 - 이 부분을 변경하지 마세요
  // 경로 계산의 핵심 로직을 담당하는 중요 함수입니다
  Future<void> getDirections(LatLng origin, LatLng destination) async {
    try {
      isLoading.value = true;
      errorMsg.value = '';

      // 기존 경로 폴리라인 초기화
      polylineCoordinates.clear();
      polylines
          .removeWhere((polyline) => polyline.polylineId.value == 'direction');

      // Google Directions API 호출 URL
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=walking' // 도보 경로
          '&alternatives=true' // 대체 경로도 요청
          '&key=$_apiKey';

      debugPrint('📍 경로 요청: $url');

      // API 요청
      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        debugPrint('📍 경로 응답: ${data['status']}');

        if (data['status'] == 'OK') {
          // 경로 정보 가져오기
          if (data['routes'].isEmpty) {
            debugPrint('❌ 경로 데이터가 비어 있습니다.');
            errorMsg.value = '경로 데이터를 찾을 수 없습니다.';
            isLoading.value = false;
            return;
          }

          debugPrint(
              '📍 경로 데이터 확인: ${data['routes'][0]['overview_polyline']['points']}');

          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> points = polylinePoints.decodePolyline(
            data['routes'][0]['overview_polyline']['points'],
          );

          debugPrint('📍 디코딩된 포인트 수: ${points.length}');

          if (points.isEmpty) {
            debugPrint('❌ 폴리라인 포인트가 비어 있습니다.');
            errorMsg.value = '경로 데이터를 디코딩할 수 없습니다.';
            isLoading.value = false;
            return;
          }

          // 폴리라인 좌표로 변환
          List<LatLng> routePoints = points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          polylineCoordinates.value = routePoints;

          debugPrint('📍 폴리라인 좌표 개수: ${polylineCoordinates.length}');

          // 확인을 위해 첫 번째와 마지막 좌표 출력
          if (routePoints.isNotEmpty) {
            debugPrint(
                '📍 첫 번째 좌표: ${routePoints.first.latitude}, ${routePoints.first.longitude}');
            debugPrint(
                '📍 마지막 좌표: ${routePoints.last.latitude}, ${routePoints.last.longitude}');
          }

          // 폴리라인 생성 - 명확한 ID와 색상으로 설정
          final String polylineId = _getPolylineId();
          polylines.add(
            Polyline(
              polylineId: PolylineId(polylineId),
              points: polylineCoordinates,
              color: Colors.green,
              width: 5,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10)
              ], // 가시성을 높이기 위한 패턴 추가
            ),
          );

          debugPrint(
              '📍 폴리라인 생성 완료: $polylineId, 포인트 수: ${polylineCoordinates.length}');

          // 추가 확인을 위해 현재 polylines 세트 상태 출력
          debugPrint('📍 현재 polylines 개수: ${polylines.length}');
          for (var poly in polylines) {
            debugPrint(
                '📍 폴리라인 ID: ${poly.polylineId.value}, 포인트 수: ${poly.points.length}');
          }

          // 거리와 시간 정보 업데이트
          if (data['routes'][0]['legs'] != null &&
              data['routes'][0]['legs'].isNotEmpty) {
            // 거리 (미터)
            routeDistance.value =
                data['routes'][0]['legs'][0]['distance']['value'].toDouble();
            // 시간 (초를 분으로 변환)
            routeDuration.value =
                (data['routes'][0]['legs'][0]['duration']['value'] / 60)
                    .round();

            debugPrint(
                '📍 경로 거리: ${routeDistance.value}m, 소요 시간: ${routeDuration.value}분');
          }

          // 경로를 따라 카메라 이동 - 모든 경로가 보이도록 Bound 설정
          _fitBoundsForRoute();
        } else if (data['status'] == 'ZERO_RESULTS') {
          errorMsg.value = '해당 위치로 가는 경로를 찾을 수 없습니다. 다른 위치를 선택해 주세요.';
        } else if (data['status'] == 'NOT_FOUND') {
          errorMsg.value = '출발지 또는 목적지의 위치를 찾을 수 없습니다.';
        } else if (data['status'] == 'OVER_QUERY_LIMIT') {
          errorMsg.value = 'API 할당량 초과로 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';
        } else {
          errorMsg.value = '경로를 찾을 수 없습니다: ${data['status']}';
        }
      } else {
        errorMsg.value = '서버 응답 오류: ${response.statusCode} - 나중에 다시 시도해 주세요.';
      }

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      errorMsg.value = '경로 가져오기 중 오류가 발생했습니다: $e';
      debugPrint('❌ 경로 검색 오류: $e');
    }
  }

  // 경로에 맞게 지도 화면 조정
  void _fitBoundsForRoute() {
    if (polylineCoordinates.isEmpty || mapController.value == null) return;

    // 모든 포인트를 포함하는 경계 계산
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    // 출발지와 목적지도 경계에 포함
    if (currentLocation.value != null) {
      minLat = min(minLat, currentLocation.value!.latitude);
      maxLat = max(maxLat, currentLocation.value!.latitude);
      minLng = min(minLng, currentLocation.value!.longitude);
      maxLng = max(maxLng, currentLocation.value!.longitude);
    }

    if (destinationLocation.value != null) {
      minLat = min(minLat, destinationLocation.value!.latitude);
      maxLat = max(maxLat, destinationLocation.value!.latitude);
      minLng = min(minLng, destinationLocation.value!.longitude);
      maxLng = max(maxLng, destinationLocation.value!.longitude);
    }

    // 모든 경로 포인트 포함
    for (var point in polylineCoordinates) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // 경계에 여백 추가
    const padding = 0.005; // 약 500m 정도의 여백
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // 카메라 이동
    mapController.value!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // 패딩 (픽셀)
      ),
    );

    debugPrint('📍 경로에 맞게 지도 화면 조정 완료');
  }

  // 경로 안내 취소 - 경로 표시 제거
  void cancelDirections() {
    // 경로 정보 초기화
    polylineCoordinates.clear();
    polylines.removeWhere(
        (polyline) => polyline.polylineId.value.startsWith('polyline_'));
    polylines
        .removeWhere((polyline) => polyline.polylineId.value == 'direction');

    // 목적지 정보도 초기화
    destinationLocation.value = null;
    destinationAddress.value = '';

    // 목적지 마커 제거
    markers.removeWhere((marker) => marker.markerId.value == 'destination');

    // 경로 정보 초기화
    routeDistance.value = 0.0;
    routeDuration.value = 0;

    // 추적 중이면 추적 중지
    if (isTracking.value) {
      stopTracking();
    }

    debugPrint('📍 경로 안내 취소됨');
  }

  // 지도 초기화 - 모든 마커와 경로 지우기
  void resetMap() {
    currentLocation.value = null;
    destinationLocation.value = null;
    destinationAddress.value = '';
    polylineCoordinates.clear();
    markers.clear();
    polylines.clear();
    locationHistory.clear();
    isTracking.value = false;
    routeDistance.value = 0.0;
    routeDuration.value = 0;
    errorMsg.value = '';

    _positionStream?.cancel();
    _positionStream = null;

    // 현재 위치만 다시 가져오기
    getCurrentLocation();
  }

  // IMPORTANT: 지도 컨트롤러 설정 - 이 부분을 변경하지 마세요
  // 지도 초기화 및 제한 설정을 담당하는 중요 함수입니다
  void setMapController(GoogleMapController controller) {
    mapController.value = controller;

    // 카메라 이동 완료 리스너 추가
    if (currentLocation.value != null) {
      // 현재 위치를 중심으로 지도 경계 설정 (약 5km 반경)
      _setMapBounds(currentLocation.value!);
    }

    debugPrint('✅ 구글 맵 컨트롤러 설정 완료');
  }

  // IMPORTANT: 지도 경계 설정 - 이 부분을 변경하지 마세요
  // 지도가 표시할 수 있는 영역의 한계를 설정하는 함수입니다
  void _setMapBounds(LatLng center) {
    // 위도 1도 = 약 111km, 경도 1도 = 약 111km * cos(위도)
    // 약 20km 반경의 경계 설정 (더 넓게 조정)
    final double latPadding = 0.18; // 약 20km
    final double lngPadding =
        0.18 / cos(center.latitude * pi / 180); // 위도에 따른 경도 보정

    _mapBounds = LatLngBounds(
      southwest:
          LatLng(center.latitude - latPadding, center.longitude - lngPadding),
      northeast:
          LatLng(center.latitude + latPadding, center.longitude + lngPadding),
    );

    debugPrint('✅ 지도 경계 설정 완료: $_mapBounds');
  }

  // IMPORTANT: 검색 위치로 지도 이동 - 이 부분을 변경하지 마세요
  // 지도 이동을 안전하게 처리하는 함수입니다
  void moveToLocation(LatLng location, {double zoom = 15.0}) {
    if (mapController.value != null) {
      // 경계 내부로 제한된 위치 계산
      LatLng boundedLocation = _constrainToMapBounds(location);

      mapController.value!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: boundedLocation, zoom: zoom),
        ),
      );
    }
  }

  // IMPORTANT: 위치 제한 함수 - 이 부분을 변경하지 마세요
  // 지도 이동 시 경계를 벗어나지 않도록 제한하는 함수입니다
  LatLng _constrainToMapBounds(LatLng location) {
    if (_mapBounds == null) return location;

    // 경계를 벗어나면 경계 내부로 조정
    double lat = location.latitude;
    double lng = location.longitude;

    lat = max(_mapBounds!.southwest.latitude, lat);
    lat = min(_mapBounds!.northeast.latitude, lat);

    lng = max(_mapBounds!.southwest.longitude, lng);
    lng = min(_mapBounds!.northeast.longitude, lng);

    return LatLng(lat, lng);
  }

  // 공유된 위치 저장
  Future<bool> saveSharedLocation(SharedLocation location) async {
    try {
      debugPrint('🔄 공유된 위치 저장 시도: ${location.toString()}');

      // Firestore에 위치 정보 저장 (옵션)
      try {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        await firestore
            .collection('shared_locations')
            .doc(location.id)
            .set(location.toJson());
        debugPrint('✅ Firestore에 위치 정보 저장 성공');
      } catch (e) {
        // Firestore 저장 실패는 로컬 저장에 영향 없음
        debugPrint('⚠️ Firestore 위치 저장 실패 (무시됨): $e');
      }

      // 로컬 목록에 추가
      if (!sharedLocations.any((loc) => loc.id == location.id)) {
        sharedLocations.add(location);

        // 지도 마커도 추가
        _updateSharedLocationMarkers();

        debugPrint('✅ 공유 위치 저장 성공: ${location.id}');
        return true;
      } else {
        debugPrint('ℹ️ 이미 저장된 위치입니다: ${location.id}');
        return true; // 이미 있는 경우도 성공으로 처리
      }
    } catch (e) {
      debugPrint('❌ 공유 위치 저장 실패: $e');
      return false;
    }
  }

  // 메시지에서 공유된 위치 표시 설정
  void setShowSharedLocations(bool show) {
    showSharedLocations.value = show;

    // 마커 업데이트
    _updateSharedLocationMarkers();

    debugPrint('✅ 공유 위치 표시 설정: $show');
  }

  // 공유된 위치로 이동
  void moveToSharedLocation(SharedLocation location) {
    if (mapController.value != null) {
      mapController.value!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location.toLatLng(),
            zoom: 15,
          ),
        ),
      );

      debugPrint('✅ 공유 위치로 이동: ${location.toString()}');
    }
  }

  // 공유된 위치 목록 초기화
  Future<void> _loadSharedLocations() async {
    try {
      debugPrint('🔄 저장된 공유 위치 불러오기 시작');
      sharedLocations.clear();

      // Firestore에서 공유된 위치 불러오기
      try {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        final snapshot = await firestore.collection('shared_locations').get();

        for (var doc in snapshot.docs) {
          try {
            final location = SharedLocation.fromFirestore(doc);
            sharedLocations.add(location);
          } catch (e) {
            debugPrint('⚠️ 위치 변환 오류 (무시됨): $e');
          }
        }

        debugPrint('✅ Firestore에서 ${sharedLocations.length}개의 공유 위치를 불러왔습니다');
      } catch (e) {
        // Firestore 로드 실패는 무시
        debugPrint('⚠️ Firestore 위치 불러오기 실패 (무시됨): $e');
      }

      // 마커 업데이트
      _updateSharedLocationMarkers();
    } catch (e) {
      debugPrint('❌ 공유 위치 불러오기 실패: $e');
      // 오류 시 빈 목록 사용
      sharedLocations.clear();
    }
  }

  // 공유된 위치 마커 업데이트
  void _updateSharedLocationMarkers() {
    try {
      // 공유된 위치 표시가 비활성화된 경우 마커 제거
      if (!showSharedLocations.value) {
        markers.removeWhere(
            (marker) => marker.markerId.value.startsWith('shared_'));
        return;
      }

      // 기존 공유 위치 마커 제거
      markers
          .removeWhere((marker) => marker.markerId.value.startsWith('shared_'));

      // 새 마커 추가
      for (var location in sharedLocations) {
        markers.add(
          Marker(
            markerId: MarkerId('shared_${location.id}'),
            position: location.toLatLng(),
            infoWindow: InfoWindow(
              title: location.message,
              snippet: '${location.senderName}님이 공유 · 탭하여 상세 정보',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            onTap: () async {
              // 마커 탭 시 주소 정보 가져오기
              try {
                final addresses = await placemarkFromCoordinates(
                  location.latitude,
                  location.longitude,
                );

                if (addresses.isNotEmpty) {
                  final place = addresses.first;
                  final address =
                      '${place.street}, ${place.locality}, ${place.administrativeArea}';

                  // 주소 정보가 있는 다이얼로그 표시
                  Get.dialog(
                    AlertDialog(
                      title: Text(location.message),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${location.senderName}님이 공유한 위치'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text(address,
                                      style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '${location.timestamp.year}/${location.timestamp.month}/${location.timestamp.day} ${location.timestamp.hour}:${location.timestamp.minute}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('닫기'),
                        ),
                        TextButton(
                          onPressed: () {
                            Get.back();
                            _showDeleteLocationDialog(location);
                          },
                          child: const Text('삭제',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                debugPrint('⚠️ 주소 가져오기 실패: $e');
                // 주소 정보가 없는 경우 기본 삭제 다이얼로그 표시
                _showDeleteLocationDialog(location);
              }
            },
          ),
        );
      }

      debugPrint('✅ 공유 위치 마커 ${sharedLocations.length}개 업데이트 완료');
    } catch (e) {
      debugPrint('❌ 공유 위치 마커 업데이트 실패: $e');
    }
  }

  // 위치 삭제 확인 다이얼로그
  void _showDeleteLocationDialog(SharedLocation location) {
    Get.dialog(
      AlertDialog(
        title: const Text('위치 삭제'),
        content: Text('이 위치를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              removeSharedLocation(location.id).then((success) {
                if (success) {
                  Get.snackbar(
                    '삭제 완료',
                    '위치가 삭제되었습니다.',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                } else {
                  Get.snackbar(
                    '삭제 실패',
                    '위치를 삭제하지 못했습니다.',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 공유된 위치 삭제
  Future<bool> removeSharedLocation(String locationId) async {
    try {
      // Firestore에서 삭제
      try {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        await firestore.collection('shared_locations').doc(locationId).delete();
        debugPrint('✅ Firestore에서 위치 삭제 성공');
      } catch (e) {
        debugPrint('⚠️ Firestore 위치 삭제 실패 (무시됨): $e');
      }

      // 로컬 목록에서 삭제
      sharedLocations.removeWhere((location) => location.id == locationId);

      // 마커 업데이트
      _updateSharedLocationMarkers();

      debugPrint('✅ 공유 위치 삭제 성공: $locationId');
      return true;
    } catch (e) {
      debugPrint('❌ 공유 위치 삭제 실패: $e');
      return false;
    }
  }

  @override
  void onClose() {
    // 자원 해제
    _positionStream?.cancel();
    _locationTimer?.cancel();
    mapController.value?.dispose();
    super.onClose();
  }
}
