import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/location_service.dart';
import '../../models/shared_location_model.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class SharedLocationView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String message;
  final DateTime timestamp;
  final String senderName;

  // URL 파싱을 통한 위치 열기를 위한 정적 메서드 추가
  static Future<void> openFromMapsUrl(String url) async {
    try {
      // URL 파싱
      final coordinates = _parseGoogleMapsUrl(url);
      if (coordinates != null) {
        final lat = coordinates['latitude']!;
        final lng = coordinates['longitude']!;

        // SharedLocationView로 이동
        Get.to(
          () => SharedLocationView(
            latitude: lat,
            longitude: lng,
            message: '공유된 위치',
            timestamp: DateTime.now(),
            senderName: '공유',
          ),
          transition: Transition.rightToLeft,
        );

        return;
      }

      // 파싱 실패 시 외부 브라우저로 열기
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ 지도 URL 열기 오류: $e');
      Get.snackbar(
        '오류',
        '지도 URL을 열 수 없습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }

  // Google Maps URL 파싱 정적 메서드
  static Map<String, double>? _parseGoogleMapsUrl(String url) {
    try {
      // URL에서 좌표 추출
      Uri uri = Uri.parse(url);

      // maps.google.com 형식 확인
      if (uri.host.contains('maps.google.com') ||
          uri.host.contains('google.com/maps')) {
        // q 파라미터로 좌표가 있는 경우
        if (uri.queryParameters.containsKey('q')) {
          final coordinates = uri.queryParameters['q']!.split(',');
          if (coordinates.length == 2) {
            final lat = double.tryParse(coordinates[0]);
            final lng = double.tryParse(coordinates[1]);

            if (lat != null && lng != null) {
              return {'latitude': lat, 'longitude': lng};
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ URL 파싱 오류: $e');
      return null;
    }
  }

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
  bool _isSharing = false;
  final LocationService _locationService = Get.find<LocationService>();
  bool _isSavedToMap = false;
  Timer? _clipboardCheckTimer;

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
        infoWindow: InfoWindow(
          title: widget.message,
          onTap: () => _openInExternalMap(),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };

    // 클립보드 모니터링 시작
    _startClipboardMonitoring();
  }

  // 클립보드 모니터링 시작
  void _startClipboardMonitoring() {
    try {
      _clipboardCheckTimer?.cancel();

      // 주기적으로 클립보드를 확인
      _clipboardCheckTimer =
          Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkClipboardForMapsUrl();
      });

      // 초기 클립보드 확인
      _checkClipboardForMapsUrl();
    } catch (e) {
      debugPrint('⚠️ 클립보드 모니터링 시작 오류: $e');
    }
  }

  // 클립보드에서 Google Maps URL 확인
  Future<void> _checkClipboardForMapsUrl() async {
    try {
      final ClipboardData? clipboardData =
          await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!;

        // Google Maps URL 패턴 확인
        if (text.contains('maps.google.com') && text.contains('?q=')) {
          debugPrint('🔍 클립보드에서 Google Maps URL 발견: $text');

          // 사용자에게 앱에서 열기 옵션 제공
          if (mounted) {
            _showOpenInAppDialog(text);
          }

          // 확인 후 타이머 일시정지 (중복 알림 방지)
          _clipboardCheckTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('⚠️ 클립보드 확인 오류: $e');
    }
  }

  // 앱에서 열기 다이얼로그
  void _showOpenInAppDialog(String url) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지도 링크 감지'),
        content: const Text('Google Maps 링크가 감지되었습니다. Watch Over 앱에서 열겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SharedLocationView.openFromMapsUrl(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('앱에서 열기'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clipboardCheckTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
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

  // 위치 정보 공유하기 (클립보드 사용)
  Future<void> _shareLocation() async {
    // 중복 공유 방지
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // 진동 피드백
      HapticFeedback.lightImpact();

      // 위치 URL 생성
      final String locationUrl =
          'https://maps.google.com/maps?q=${widget.latitude},${widget.longitude}';

      // 공유할 텍스트 생성 (단순화)
      final String shareText = '${widget.message}\n\n'
          '${widget.senderName}님의 위치 (${_formatTimestamp(widget.timestamp)})\n'
          '위도: ${widget.latitude.toStringAsFixed(6)} 경도: ${widget.longitude.toStringAsFixed(6)}\n\n'
          '지도에서 보기: $locationUrl';

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: shareText));

      // 지도 URL 실행 확인 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 공유'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('위치 정보가 클립보드에 복사되었습니다.'),
                const SizedBox(height: 16),
                const Text('지도에서 위치를 바로 확인하시겠습니까?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('아니오'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openInExternalMap();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인하기'),
              ),
            ],
          ),
        );
      }

      // 성공 토스트 표시
      Get.snackbar(
        '복사 완료',
        '위치 정보가 클립보드에 복사되었습니다.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // 오류 세부 정보 로깅
      debugPrint('⚠️ 위치 공유 오류: $e');

      // 오류 메시지 표시
      Get.snackbar(
        '공유 실패',
        '위치를 공유할 수 없습니다. 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
    } finally {
      // 공유 상태 초기화
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  // 앱 내 지도에 위치 저장
  Future<void> _saveToAppMap() async {
    if (_isSavedToMap) {
      // 이미 저장된 경우 알림 표시
      Get.snackbar(
        '이미 저장됨',
        '이 위치는 이미 지도에 저장되어 있습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      // 진동 피드백
      HapticFeedback.lightImpact();

      // 저장 진행 중 알림
      Get.snackbar(
        '저장 중',
        '지도에 위치를 저장하는 중...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.teal.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 1),
      );

      // 공유된 위치 모델 생성
      final sharedLocation = SharedLocationModel(
        id: const Uuid().v4(), // 고유 ID 생성
        senderId: 'shared_from_message', // 메시지에서 공유된 위치임을 표시
        senderName: widget.senderName,
        latitude: widget.latitude,
        longitude: widget.longitude,
        message: widget.message,
        timestamp: widget.timestamp,
        messageId: 'direct_share', // 직접 공유시 메시지 ID 없음
      );

      // 위치 서비스에 저장
      final success = await _locationService.saveSharedLocation(sharedLocation);

      if (success) {
        setState(() {
          _isSavedToMap = true;
        });

        Get.snackbar(
          '저장 완료',
          '위치가 지도에 저장되었습니다. 지도 메뉴에서 확인할 수 있습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '저장 실패',
          '위치를 지도에 저장하지 못했습니다. 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 지도에 위치 저장 중 오류: $e');

      Get.snackbar(
        '저장 오류',
        '오류가 발생했습니다: 위치를 저장할 수 없습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // 외부 지도 앱에서 위치 열기
  Future<void> _openInExternalMap() async {
    try {
      // 진동 피드백
      HapticFeedback.mediumImpact();

      // 지도 URL 생성
      String urlString;

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOS에서는 Apple Maps URL 스킴 사용
        urlString =
            'https://maps.apple.com/?ll=${widget.latitude},${widget.longitude}&q=${Uri.encodeComponent(widget.message)}';
      } else {
        // Android 및 기타 플랫폼에서는 Google Maps URL 스킴 사용
        urlString =
            'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
      }

      // URL 파싱
      final Uri url = Uri.parse(urlString);

      debugPrint('🔗 외부 지도 URL: $urlString');

      // URL 실행 시도
      final bool canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        final bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          _showErrorSnackbar('지도 앱을 실행할 수 없습니다. 기본 브라우저에서 열기를 시도합니다.');
          // 대체 방식으로 웹 브라우저에서 열기
          await launchUrl(
            Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}'),
            mode: LaunchMode.platformDefault,
          );
        }
      } else {
        _showErrorSnackbar('지도 앱이 설치되어 있지 않습니다. 브라우저에서 열기를 시도합니다.');
        // 대체 방식으로 웹 브라우저에서 열기
        await launchUrl(
          Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}'),
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      debugPrint('⚠️ 외부 지도 앱 열기 오류: $e');
      _showErrorSnackbar('지도 앱을 열 수 없습니다. 인터넷 연결을 확인해주세요.');
    }
  }

  // 에러 스낵바 표시
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      '오류',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: const Duration(seconds: 3),
    );
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

  // 지도 화면으로 직접 이동
  void _openInMapView() {
    try {
      // 진동 피드백
      HapticFeedback.mediumImpact();

      // 현재 화면 닫기
      Get.back();

      // 잠시 대기 후 지도로 이동 (애니메이션을 위해)
      Future.delayed(const Duration(milliseconds: 300), () {
        // 공유 위치로 이동하는 기능은 이미 구현된 위치 서비스 활용
        if (!_isSavedToMap) {
          // 아직 저장되지 않은 경우 위치 저장 후 이동
          final sharedLocation = SharedLocationModel(
            id: const Uuid().v4(),
            senderId: 'temp_navigation',
            senderName: widget.senderName,
            latitude: widget.latitude,
            longitude: widget.longitude,
            message: widget.message,
            timestamp: widget.timestamp,
            messageId: 'direct_navigation',
          );

          // 임시로 저장하고 이동
          _locationService.saveSharedLocation(sharedLocation).then((success) {
            if (success) {
              _locationService.moveToSharedLocation(sharedLocation);
            }
          });
        }

        // 지도 탭으로 이동
        Get.toNamed('/map');
      });
    } catch (e) {
      debugPrint('⚠️ 지도 화면으로 이동 중 오류: $e');
      Get.snackbar(
        '이동 오류',
        '지도 화면으로 이동할 수 없습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
        duration: const Duration(seconds: 3),
      );
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
          // 앱 내 지도에 저장 버튼 추가
          IconButton(
            icon: Icon(
              _isSavedToMap ? Icons.bookmark : Icons.bookmark_outline,
              color:
                  _isSavedToMap ? Colors.amber.shade600 : Colors.blue.shade600,
            ),
            onPressed: _saveToAppMap,
            tooltip: '앱 지도에 저장',
          ),
          // 공유 버튼
          _isSharing
              ? Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade600,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: Colors.blue.shade600,
                  ),
                  onPressed: _shareLocation,
                  tooltip: '위치 정보 복사',
                ),
          // 외부 앱에서 열기 버튼
          IconButton(
            icon: Icon(
              Icons.open_in_new,
              color: Colors.blue.shade600,
            ),
            onPressed: _openInExternalMap,
            tooltip: '외부 지도 앱에서 열기',
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
                GestureDetector(
                  onTap: _openInExternalMap,
                  child: Container(
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
                      GestureDetector(
                        onTap: _openInExternalMap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.grey.shade300, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '위도: ${widget.latitude.toStringAsFixed(6)}, 경도: ${widget.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new,
                                size: 12,
                                color: Colors.teal.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 하단에 앱 내 지도 버튼 추가
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _openInMapView,
              icon: const Icon(Icons.map),
              label: const Text('앱 지도에서 보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
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
                  onTap: (_) {
                    // 지도의 마커가 아닌 부분을 탭했을 때 플랫폼 지도 앱에서 열기
                    _openInExternalMap();
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 14,
                            color: Colors.teal.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '탭하여 외부 지도 앱에서 열기',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
