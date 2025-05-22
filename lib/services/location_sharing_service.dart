import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/shared_location_model.dart';
import 'notification_service.dart';

class LocationSharingService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 공유 중인 위치 정보 저장
  final RxMap<String, SharedLocation> _activeSharing =
      <String, SharedLocation>{}.obs;

  // 위치 수신 스트림 구독 객체 저장
  final Map<String, StreamSubscription<Position>> _positionStreams = {};

  // 위치 업데이트 간격 (초)
  final RxInt updateIntervalSeconds = 5.obs;

  // 위치 공유 상태 (활성화 여부)
  final RxBool isSharingLocation = false.obs;

  // 위치 공유 중인 사용자 ID 목록
  final RxList<String> sharingToUserIds = <String>[].obs;

  // 위치 정보 캐시 (오프라인 지원용)
  final RxList<Map<String, dynamic>> _locationCache =
      <Map<String, dynamic>>[].obs;

  // 서비스 초기화
  @override
  void onInit() {
    super.onInit();
    _loadActiveSharing();
    _setupConnectivityListener();
  }

  // 위치 공유 상태 로드
  Future<void> _loadActiveSharing() async {
    final prefs = await SharedPreferences.getInstance();
    final activeSharingJson = prefs.getString('active_location_sharing');

    if (activeSharingJson != null && activeSharingJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(activeSharingJson);
        decoded.forEach((key, value) {
          _activeSharing[key] = SharedLocation.fromJson(value);
        });

        // 이미 공유 중인 위치가 있다면 상태 업데이트
        if (_activeSharing.isNotEmpty) {
          isSharingLocation.value = true;
          sharingToUserIds.value = _activeSharing.keys.toList();

          // 위치 공유 재개
          _activeSharing.forEach((userId, sharedLocation) {
            if (sharedLocation.isActive) {
              _startPositionTracking(userId);
            }
          });
        }
      } catch (e) {
        print('위치 공유 상태 로드 오류: $e');
      }
    }
  }

  // 네트워크 연결 상태 리스너 설정
  void _setupConnectivityListener() {
    // 네트워크 연결 복구 시 캐시된 위치 정보 업로드
    // 실제 구현은 connectivity 패키지 사용 필요
  }

  // 위치 권한 확인
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        '위치 서비스 비활성화',
        '위치 서비스를 활성화해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar(
          '위치 권한 거부됨',
          '위치 권한이 필요합니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
        '위치 권한 영구 거부됨',
        '앱 설정에서 위치 권한을 허용해주세요.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  // 위치 공유 시작
  Future<bool> startLocationSharing(String receiverId) async {
    if (!await checkLocationPermission()) return false;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // 위치 공유 정보 생성
      final position = await Geolocator.getCurrentPosition();
      final locationId = const Uuid().v4();

      final sharedLocation = SharedLocation(
        id: locationId,
        senderId: userId,
        receiverId: receiverId,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        isActive: true,
        startTime: DateTime.now(),
      );

      // Firestore에 초기 위치 정보 저장
      await _firestore
          .collection('location_sharing')
          .doc(locationId)
          .set(sharedLocation.toJson());

      // 위치 공유 상태 업데이트
      _activeSharing[receiverId] = sharedLocation;
      isSharingLocation.value = true;
      if (!sharingToUserIds.contains(receiverId)) {
        sharingToUserIds.add(receiverId);
      }

      // 로컬 저장소에 상태 저장
      _saveActiveSharingState();

      // 위치 추적 시작
      _startPositionTracking(receiverId);

      // 위치 공유 시작 메시지 전송
      _sendLocationSharingStatusMessage(receiverId, true);

      return true;
    } catch (e) {
      print('위치 공유 시작 오류: $e');
      return false;
    }
  }

  // 위치 공유 중지
  Future<bool> stopLocationSharing(String receiverId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      // 위치 추적 중지
      _stopPositionTracking(receiverId);

      // 위치 공유 종료 상태로 업데이트
      if (_activeSharing.containsKey(receiverId)) {
        final sharedLocation = _activeSharing[receiverId]!.copyWithEndSharing();

        // Firestore 업데이트
        await _firestore
            .collection('location_sharing')
            .doc(sharedLocation.id)
            .update({
          'isActive': false,
          'endTime': FieldValue.serverTimestamp(),
        });

        // 상태 업데이트
        _activeSharing.remove(receiverId);
        sharingToUserIds.remove(receiverId);

        if (_activeSharing.isEmpty) {
          isSharingLocation.value = false;
        }

        // 로컬 저장소 업데이트
        _saveActiveSharingState();

        // 위치 공유 종료 메시지 전송
        _sendLocationSharingStatusMessage(receiverId, false);

        return true;
      }

      return false;
    } catch (e) {
      print('위치 공유 중지 오류: $e');
      return false;
    }
  }

  // 모든 위치 공유 중지
  Future<void> stopAllLocationSharing() async {
    final userIds = List<String>.from(sharingToUserIds);

    for (final userId in userIds) {
      await stopLocationSharing(userId);
    }
  }

  // 위치 추적 시작
  void _startPositionTracking(String receiverId) {
    // 이미 추적 중인 경우 중지
    _stopPositionTracking(receiverId);

    // 위치 추적 시작
    final stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: updateIntervalSeconds.value),
      ),
    );

    _positionStreams[receiverId] = stream.listen((Position position) {
      _updateLocationData(receiverId, position);
    });
  }

  // 위치 추적 중지
  void _stopPositionTracking(String receiverId) {
    if (_positionStreams.containsKey(receiverId)) {
      _positionStreams[receiverId]?.cancel();
      _positionStreams.remove(receiverId);
    }
  }

  // 위치 정보 업데이트
  Future<void> _updateLocationData(String receiverId, Position position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (!_activeSharing.containsKey(receiverId)) return;

    final sharedLocation = _activeSharing[receiverId]!.copyWithNewLocation(
      position.latitude,
      position.longitude,
    );

    // 위치 데이터 캐시에 추가 (오프라인 지원)
    _addToLocationCache(sharedLocation);

    try {
      // Firestore에 위치 업데이트
      await _firestore
          .collection('location_sharing')
          .doc(sharedLocation.id)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 캐시에서 성공적으로 업로드된 항목 제거
      _removeFromLocationCache(sharedLocation.id);
    } catch (e) {
      print('위치 업데이트 오류: $e');
      // 오류 발생 시 캐시에 유지 (나중에 다시 시도)
    }
  }

  // 위치 데이터 캐시에 추가
  void _addToLocationCache(SharedLocation location) {
    _locationCache.add(location.toJson());
    _saveLocationCache();
  }

  // 위치 데이터 캐시에서 제거
  void _removeFromLocationCache(String locationId) {
    _locationCache.removeWhere((item) => item['id'] == locationId);
    _saveLocationCache();
  }

  // 캐시된 위치 정보 저장
  Future<void> _saveLocationCache() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('location_cache', jsonEncode(_locationCache));
  }

  // 위치 공유 상태 저장
  Future<void> _saveActiveSharingState() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> activeSharingMap = {};
    _activeSharing.forEach((key, value) {
      activeSharingMap[key] = value.toJson();
    });

    prefs.setString('active_location_sharing', jsonEncode(activeSharingMap));
  }

  // 위치 공유 시작/종료 메시지 전송
  Future<void> _sendLocationSharingStatusMessage(
      String receiverId, bool isStarting) async {
    // 메시지 서비스 연동 코드 (구현 필요)
    // MessageService의 인스턴스를 통해 메시지 전송
  }

  // 특정 사용자의 실시간 위치 구독
  Stream<SharedLocation> subscribeToUserLocation(String userId) {
    return _firestore
        .collection('location_sharing')
        .where('senderId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return SharedLocation.fromFirestore(snapshot.docs.first);
      } else {
        throw Exception('활성화된 위치 공유가 없습니다.');
      }
    });
  }

  // 앱 종료 시 리소스 해제
  @override
  void onClose() {
    for (var stream in _positionStreams.values) {
      stream.cancel();
    }
    _positionStreams.clear();
    super.onClose();
  }

  // 위치 공유 여부 확인
  bool isShareLocationActive(String receiverId) {
    return _activeSharing.containsKey(receiverId) &&
        _activeSharing[receiverId]!.isActive;
  }

  // 업데이트 간격 변경
  void setUpdateInterval(int seconds) {
    if (seconds >= 1 && seconds <= 60) {
      updateIntervalSeconds.value = seconds;

      // 활성 스트림 재시작 (새 간격 적용)
      final userIds = List<String>.from(sharingToUserIds);
      for (final userId in userIds) {
        _startPositionTracking(userId);
      }
    }
  }
}
