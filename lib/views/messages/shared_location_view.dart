import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class SharedLocationView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String message;
  final DateTime timestamp;
  final String senderName;

  const SharedLocationView({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.message,
    required this.timestamp,
    required this.senderName,
  }) : super(key: key);

  @override
  State<SharedLocationView> createState() => _SharedLocationViewState();
}

class _SharedLocationViewState extends State<SharedLocationView> {
  late final CameraPosition _initialCameraPosition;
  late final Set<Marker> _markers;
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  bool _isLoadingLocation = false;

  // 내 위치에 대한 마커 ID
  static const String myLocationMarkerId = 'my_location';

  @override
  void initState() {
    super.initState();

    // 초기 카메라 위치 설정
    _initialCameraPosition = CameraPosition(
      target: LatLng(widget.latitude, widget.longitude),
      zoom: 15,
    );

    // 마커 설정
    _markers = {
      Marker(
        markerId: const MarkerId('shared_location'),
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(title: widget.message),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // 현재 기기 위치 가져오기
  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            '위치 권한 없음',
            '위치 정보를 가져오려면 권한이 필요합니다',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            borderRadius: 10,
          );
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          '위치 권한 영구 거부됨',
          '앱 설정에서 위치 권한을 활성화해주세요',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 진동 피드백 제공
      HapticFeedback.mediumImpact();

      // 내 위치 마커 추가 또는 업데이트
      final LatLng myLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        // 기존 내 위치 마커 제거
        _markers.removeWhere(
            (marker) => marker.markerId.value == myLocationMarkerId);

        // 새 마커 추가
        _markers.add(
          Marker(
            markerId: const MarkerId(myLocationMarkerId),
            position: myLocation,
            infoWindow: const InfoWindow(title: '내 현재 위치'),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });

      // 카메라 이동
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: myLocation,
              zoom: 15,
            ),
          ),
        );
      }

      // 성공 메시지
      Get.snackbar(
        '내 위치 확인됨',
        '현재 위치를 지도에 표시합니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '위치 가져오기 실패',
        '현재 위치를 가져오는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // 공유된 원래 위치로 돌아가기
  void _moveToSharedLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(_initialCameraPosition),
      );

      // 이동 알림
      Get.snackbar(
        '원래 위치로 이동',
        '${widget.senderName}님이 공유한 위치로 돌아갑니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.teal.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 2),
      );
    }
  }

  // 날짜 형식화 함수
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // 오늘인 경우 시간만 표시
      return '오늘 ${DateFormat('HH:mm').format(timestamp)}';
    } else if (difference.inDays == 1) {
      // 어제인 경우
      return '어제 ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      // 그 외 경우 날짜와 시간 표시
      return DateFormat('yyyy/MM/dd HH:mm').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              radius: 16,
              child: Icon(
                Icons.location_on,
                color: Colors.teal.shade700,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '공유된 위치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share_rounded,
              color: Colors.blue.shade600,
            ),
            onPressed: () {
              // 위치 공유 기능 (나중에 구현)
              Get.snackbar(
                '알림',
                '위치 공유 기능은 아직 개발 중입니다.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.blue.shade700,
                colorText: Colors.white,
                borderRadius: 10,
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 2),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 위치 정보 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 위치 아이콘 컨테이너
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.shade200.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // 위치 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              widget.senderName.isNotEmpty
                                  ? widget.senderName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '·',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimestamp(widget.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Text(
                          '위도: ${widget.latitude.toStringAsFixed(6)}, 경도: ${widget.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 지도 로딩 표시
          if (!_isMapReady)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.teal.shade400,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '지도를 불러오는 중...',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 지도 표시
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // 커스텀 버튼 사용
                  zoomControlsEnabled: false, // 커스텀 버튼 사용
                  compassEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    // 맵 스타일 설정 (옵션)
                    setState(() {
                      _isMapReady = true;
                    });
                  },
                ),

                // 지도 컨트롤 버튼 - 왼쪽 하단
                Positioned(
                  bottom: 100,
                  left: 16,
                  child: Column(
                    children: [
                      // 확대 버튼
                      _buildMapControlButton(
                        icon: Icons.add,
                        tooltip: '확대',
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // 축소 버튼
                      _buildMapControlButton(
                        icon: Icons.remove,
                        tooltip: '축소',
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 공유된 위치로 돌아가기 버튼 - 오른쪽 하단
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: _buildMapControlButton(
                    icon: Icons.place,
                    tooltip: '공유된 위치로 돌아가기',
                    color: Colors.teal.shade600,
                    onPressed: _moveToSharedLocation,
                  ),
                ),

                // 지도 도움말 - 상단
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '지도를 움직여 주변을 확인하세요',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 지도 컨트롤 버튼 위젯
  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip ?? '',
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
