import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

/// 위치 추적 화면
class LocationTrackingView extends StatefulWidget {
  const LocationTrackingView({Key? key}) : super(key: key);

  @override
  State<LocationTrackingView> createState() => _LocationTrackingViewState();
}

class _LocationTrackingViewState extends State<LocationTrackingView> {
  // Google Maps 컨트롤러
  final Completer<GoogleMapController> _controller = Completer();

  // Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 공유 위치 스트림 구독 객체
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  // 현재 표시 중인 위치
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // 서울 기본값

  // 지도 마커
  final Set<Marker> _markers = {};

  // 위치 정보
  String _locationInfo = '위치 정보 로딩 중...';
  String _updatedTime = '';

  // 라우트 매개변수
  String? _userId;
  String? _contactName;
  String? _locationId;

  // 초기 위치 로드 완료 여부 추적
  bool _initialLocationLoaded = false;

  @override
  void initState() {
    super.initState();

    // 라우트 매개변수 가져오기
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _userId = arguments['userId'] as String?;
      _contactName = arguments['contactName'] as String?;
      _locationId = arguments['locationId'] as String?;

      print(
          '📍 [지도] 위치 추적 화면 초기화: userId=$_userId, contactName=$_contactName, locationId=$_locationId');

      // 위치 공유 데이터 구독
      _subscribeToLocationUpdates();
    }
  }

  @override
  void dispose() {
    // 구독 취소
    _locationSubscription?.cancel();
    super.dispose();
  }

  // 위치 업데이트 구독
  void _subscribeToLocationUpdates() {
    if (_locationId == null) {
      setState(() {
        _locationInfo = '위치 정보를 찾을 수 없습니다.';
      });
      return;
    }

    try {
      print('📡 [지도] 위치 업데이트 구독 시작: locationId=$_locationId');

      // Firestore 실시간 구독
      _locationSubscription = _firestore
          .collection('location_sharing')
          .doc(_locationId)
          .snapshots()
          .listen(
        (snapshot) {
          if (!snapshot.exists) {
            print('⚠️ [지도] 위치 데이터가 존재하지 않습니다.');
            setState(() {
              _locationInfo = '위치 공유가 중지되었거나 데이터가 삭제되었습니다.';
              _markers.clear();
              _updatedTime = '데이터 없음';
            });

            // 데이터가 없는 경우 사용자에게 알림
            Get.snackbar(
              '위치 데이터 없음',
              '${_contactName ?? '상대방'}님의 위치 공유가 중지되었거나 데이터가 삭제되었습니다.',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red.withOpacity(0.7),
              colorText: Colors.white,
            );

            return;
          }

          final data = snapshot.data()!;
          final latitude = data['latitude'] as double?;
          final longitude = data['longitude'] as double?;
          final timestamp = data['timestamp'] as Timestamp?;

          if (latitude == null || longitude == null) {
            print('⚠️ [지도] 위치 데이터 누락: lat=$latitude, lng=$longitude');
            return;
          }

          final newLocation = LatLng(latitude, longitude);
          print('📍 [지도] 위치 업데이트: lat=$latitude, lng=$longitude');

          // 위치 및 마커 업데이트
          setState(() {
            _currentLocation = newLocation;
            _markers.clear();
            _markers.add(
              Marker(
                markerId: MarkerId(_locationId!),
                position: newLocation,
                infoWindow: InfoWindow(
                  title: _contactName ?? '공유 위치',
                  snippet: '최근 업데이트: ${_formatTimestamp(timestamp)}',
                ),
              ),
            );

            // 위치 정보 텍스트 업데이트
            _locationInfo =
                '위도: ${latitude.toStringAsFixed(6)}, 경도: ${longitude.toStringAsFixed(6)}';
            _updatedTime = _formatTimestamp(timestamp);
          });

          // 초기 로드 시에만 카메라 이동 (이후 업데이트에서는 사용자의 확대/축소 상태 유지)
          if (!_initialLocationLoaded) {
            _moveCameraToLocation(newLocation);
            _initialLocationLoaded = true;
            print('📍 [지도] 초기 위치로 카메라 이동');
          } else {
            print('📍 [지도] 위치 업데이트 - 카메라 이동 생략 (확대/축소 상태 유지)');
          }
        },
        onError: (error) {
          print('❌ [지도] 위치 업데이트 구독 오류: $error');
          setState(() {
            _locationInfo = '위치 데이터를 불러오는 중 오류가 발생했습니다.';
          });
        },
      );
    } catch (e) {
      print('❌ [지도] 위치 구독 시작 실패: $e');
      setState(() {
        _locationInfo = '위치 추적을 시작할 수 없습니다: $e';
      });
    }
  }

  // 카메라 이동
  Future<void> _moveCameraToLocation(LatLng location) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 15.0,
        ),
      ),
    );
  }

  // 타임스탬프 포맷
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '시간 정보 없음';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else {
      return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  // 지도 확대 함수
  Future<void> _zoomIn() async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.zoomIn());
  }

  // 지도 축소 함수
  Future<void> _zoomOut() async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.zoomOut());
  }

  // 컨트롤 버튼 위젯 생성 함수
  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
  }) {
    return Container(
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
        shape: BoxShape.circle,
      ),
      child: FloatingActionButton.small(
        heroTag: 'mapControl_${icon.hashCode}',
        onPressed: onPressed,
        backgroundColor: color ?? Colors.white,
        foregroundColor: color != null ? Colors.white : Colors.blue,
        tooltip: tooltip,
        child: Icon(icon, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contactName != null ? '$_contactName님의 위치' : '나님의 위치'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 위치 정보 표시 카드
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationInfo,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (_updatedTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '최근 업데이트: $_updatedTime',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 지도 표시
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false, // 기본 줌 컨트롤 비활성화
                  compassEnabled: true,
                ),

                // 확대/축소 컨트롤 추가
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    children: [
                      // 확대 버튼
                      _buildMapControlButton(
                        icon: Icons.add,
                        tooltip: '확대',
                        onPressed: _zoomIn,
                      ),
                      // 축소 버튼
                      _buildMapControlButton(
                        icon: Icons.remove,
                        tooltip: '축소',
                        onPressed: _zoomOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
