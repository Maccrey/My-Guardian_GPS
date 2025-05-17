import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
        title: const Text('공유된 위치'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 위치 공유 기능 (나중에 구현)
              Get.snackbar('알림', '위치 공유 기능은 아직 개발 중입니다.',
                  snackPosition: SnackPosition.BOTTOM);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 위치 정보 헤더
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.location_on, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.senderName} · ${_formatTimestamp(widget.timestamp)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '좌표: ${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 지도 표시
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              markers: _markers,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(_initialCameraPosition),
            );
          }
        },
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }
}
