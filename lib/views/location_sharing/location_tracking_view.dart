import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../controllers/location_sharing_controller.dart';
import '../../models/shared_location_model.dart'; // SharedLocation 모델

class LocationTrackingView extends StatefulWidget {
  final String userId; // 추적할 사용자 ID
  final String userName; // 사용자 이름

  const LocationTrackingView({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  _LocationTrackingViewState createState() => _LocationTrackingViewState();
}

class _LocationTrackingViewState extends State<LocationTrackingView> {
  final LocationSharingController _controller =
      Get.find<LocationSharingController>();

  // 구글 맵 컨트롤러
  Completer<GoogleMapController> _mapController = Completer();

  // 마커와 폴리라인
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];

  // 지도 초기 위치 (서울 시청)
  CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 15,
  );

  // 경로 색상
  Color _routeColor = Colors.blue;

  // 최근 위치 정보
  SharedLocation? _lastLocation;

  // 위치 구독 취소 객체
  StreamSubscription<SharedLocation>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // 위치 정보 구독
  void _subscribeToLocation() {
    try {
      _locationSubscription = _controller
          .subscribeToUserLocation(widget.userId)
          .listen(_updateLocationOnMap);
    } catch (e) {
      print('위치 구독 오류: $e');
      Get.snackbar(
        '위치 추적 오류',
        '현재 위치 정보를 받아올 수 없습니다.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // 지도에 위치 업데이트
  void _updateLocationOnMap(SharedLocation location) async {
    if (!mounted) return;

    setState(() {
      _lastLocation = location;

      // 위치 좌표
      final position = LatLng(location.latitude, location.longitude);

      // 경로에 포인트 추가
      _routePoints.add(position);

      // 마커 업데이트
      _markers.clear();
      _markers.add(
        Marker(
          markerId: MarkerId(widget.userId),
          position: position,
          infoWindow: InfoWindow(
            title: widget.userName,
            snippet: '마지막 업데이트: ${_formatTime(location.timestamp)}',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      // 폴리라인 업데이트
      _updatePolylines();
    });

    // 카메라 이동
    _animateToCurrent(location);
  }

  // 폴리라인 업데이트
  void _updatePolylines() {
    if (_routePoints.length < 2) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: _routePoints,
        color: _routeColor,
        width: 5,
      ),
    );
  }

  // 현재 위치로 카메라 이동
  Future<void> _animateToCurrent(SharedLocation location) async {
    final controller = await _mapController.future;

    controller.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(location.latitude, location.longitude),
      ),
    );
  }

  // 시간 포맷
  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 경로 전체 보기
  void _showFullRoute() async {
    if (_routePoints.length < 2) return;

    final controller = await _mapController.future;

    // 모든 경로를 보여주기 위한 경계 계산
    final bounds = _calculateBounds();

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  // 위도/경도 경계 계산
  LatLngBounds _calculateBounds() {
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} 위치 추적'),
        elevation: 0,
        actions: [
          // 경로 전체 보기 버튼
          IconButton(
            icon: Icon(Icons.map),
            onPressed: _showFullRoute,
            tooltip: '경로 전체 보기',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 구글 맵
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController.complete(controller);
            },
          ),

          // 위치 정보 상태 패널
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_lastLocation != null) ...[
                      Text(
                        '마지막 업데이트: ${_formatTime(_lastLocation!.timestamp)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '위치: ${_lastLocation!.latitude.toStringAsFixed(6)}, ${_lastLocation!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ] else
                      Text(
                        '위치 정보를 받아오는 중...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
