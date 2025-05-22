import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/shared_location_model.dart'; // SharedLocation 모델
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

  // 마지막으로 알려진 위치 (오류 발생 시 폴백용)
  Position? _lastKnownPosition;

  // 서비스 초기화
  @override
  void onInit() {
    super.onInit();

    // 서비스 초기화 시 지연 시간을 두고 위치 정보 로드
    Future.delayed(const Duration(seconds: 3), () async {
      await _loadActiveSharing();
      // 백그라운드에서 마지막 위치 가져오기 시도
      _getLastKnownPosition();
    });

    _setupConnectivityListener();
  }

  // 마지막 알려진 위치 가져오기
  Future<void> _getLastKnownPosition() async {
    try {
      _lastKnownPosition = await Geolocator.getLastKnownPosition();
      print(
          '마지막 알려진 위치: ${_lastKnownPosition?.latitude}, ${_lastKnownPosition?.longitude}');
    } catch (e) {
      print('마지막 위치 가져오기 오류: $e');
    }
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

  // 위치 공유 시작 (긴급 연락처와 공유)
  Future<bool> startLocationSharing(String receiverId) async {
    print('📡 [서비스] 위치 공유 시작 요청: receiverId=$receiverId');

    if (!await checkLocationPermission()) {
      print('⚠️ [서비스] 위치 권한 없음: 공유 실패');
      return false;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ [서비스] 사용자 인증 안됨: 공유 실패');
      return false;
    }

    try {
      // 안전하게 위치 정보 가져오기
      print('🔍 [서비스] 현재 위치 가져오기 시도');
      final position = await _getCurrentPositionSafely();
      if (position == null) {
        print('⚠️ [서비스] 위치 정보 획득 실패');
        return false;
      }

      print(
          '📍 [서비스] 위치 획득 성공: lat=${position.latitude}, lng=${position.longitude}');

      final locationId = const Uuid().v4();
      print('🆔 [서비스] 새 위치 공유 ID 생성: $locationId');

      final sharedLocation = SharedLocation(
        id: locationId,
        senderId: userId,
        receiverId: receiverId,
        receiverType: 'emergency_contact', // 명시적으로 타입 지정
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        isActive: true,
        startTime: DateTime.now(),
      );

      // Firestore에 초기 위치 정보 저장
      print('💾 [서비스] Firestore에 위치 데이터 저장 시도');
      await _firestore
          .collection('location_sharing')
          .doc(locationId)
          .set(sharedLocation.toJson());
      print('✅ [서비스] Firestore 저장 성공');

      // 위치 공유 상태 업데이트
      _activeSharing[receiverId] = sharedLocation;
      isSharingLocation.value = true;
      if (!sharingToUserIds.contains(receiverId)) {
        sharingToUserIds.add(receiverId);
      }
      print(
          '🔄 [서비스] 메모리 상태 업데이트: sharingToUserIds=${sharingToUserIds.length}개');

      // 로컬 저장소에 상태 저장
      await _saveActiveSharingState();
      print('💾 [서비스] 로컬 저장소에 상태 저장 완료');

      // 위치 추적 시작
      _startPositionTracking(receiverId);
      print('📡 [서비스] 위치 추적 시작: receiverId=$receiverId');

      // 위치 공유 시작 메시지 전송
      _sendLocationSharingStatusMessage(receiverId, true);

      print('✅ [서비스] 위치 공유 시작 완료: receiverId=$receiverId');
      return true;
    } catch (e) {
      print('❌ [서비스] 위치 공유 시작 오류: $e');
      Get.snackbar(
        '위치 공유 오류',
        '위치 공유를 시작하는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  // 위치 공유 중지
  Future<bool> stopLocationSharing(String receiverId) async {
    print('🛑 [서비스] 위치 공유 중지 요청: receiverId=$receiverId');

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ [서비스] 사용자 인증 안됨: 중지 실패');
      return false;
    }

    try {
      // 위치 추적 중지
      print('🔄 [서비스] 위치 추적 중지');
      _stopPositionTracking(receiverId);

      // 위치 공유 종료 상태로 업데이트
      if (_activeSharing.containsKey(receiverId)) {
        print('🔍 [서비스] 활성 공유 정보 찾음: receiverId=$receiverId');
        final sharedLocation = _activeSharing[receiverId]!.copyWithEndSharing();

        // Firestore 업데이트
        print('💾 [서비스] Firestore 데이터 업데이트 시도');
        await _firestore
            .collection('location_sharing')
            .doc(sharedLocation.id)
            .update({
          'isActive': false,
          'endTime': FieldValue.serverTimestamp(),
        });
        print('✅ [서비스] Firestore 업데이트 성공');

        // 상태 업데이트
        _activeSharing.remove(receiverId);
        sharingToUserIds.remove(receiverId);
        print('🔄 [서비스] 메모리 상태 업데이트: receiverId=$receiverId 제거됨');

        if (_activeSharing.isEmpty) {
          isSharingLocation.value = false;
          print('🔄 [서비스] 모든 공유 종료: isSharingLocation=false');
        }

        // 로컬 저장소 업데이트
        await _saveActiveSharingState();
        print('💾 [서비스] 로컬 저장소에 상태 저장 완료');

        // 위치 공유 종료 메시지 전송
        _sendLocationSharingStatusMessage(receiverId, false);

        print('✅ [서비스] 위치 공유 중지 완료: receiverId=$receiverId');
        return true;
      } else {
        print('⚠️ [서비스] 활성 공유 정보 없음: receiverId=$receiverId');
        return false;
      }
    } catch (e) {
      print('❌ [서비스] 위치 공유 중지 오류: $e');
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

    try {
      // 위치 추적 시작
      final stream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low, // 정확도 요구사항 더 낮춤 (배터리 절약 및 타임아웃 방지)
          distanceFilter: 20, // 더 큰 거리 필터 (불필요한 업데이트 감소)
          timeLimit: Duration(seconds: 30), // 타임아웃 시간 증가 (10초 → 30초)
        ),
      );

      _positionStreams[receiverId] = stream.listen(
        (Position position) {
          // 위치 업데이트 시 마지막 위치 캐싱
          _lastKnownPosition = position;
          _updateLocationData(receiverId, position);
        },
        onError: (error) {
          print('위치 스트림 오류: $error');

          // 타임아웃 오류 발생 시 폴백 메커니즘
          if (error is TimeoutException) {
            print('위치 타임아웃 발생 - 대체 메커니즘 사용');

            // 즉시 한 번 위치 가져오기 시도
            _getCurrentPositionSafely().then((position) {
              if (position != null) {
                _updateLocationData(receiverId, position);
              }
            });

            // 폴백: 대체 타이머로 위치 주기적 업데이트
            _startFallbackPositionTimer(receiverId);
          }

          // 오류 발생 시 마지막 알려진 위치 사용
          if (_lastKnownPosition != null) {
            _updateLocationData(receiverId, _lastKnownPosition!);
          }
        },
      );
    } catch (e) {
      print('위치 스트림 초기화 오류: $e');
      // 실패 시 폴백: 주기적으로 한 번씩 위치 요청
      _startFallbackPositionTimer(receiverId);
    }
  }

  // 폴백 위치 타이머 시작 (스트림 실패 시 대체 메커니즘)
  void _startFallbackPositionTimer(String receiverId) {
    Timer.periodic(Duration(seconds: updateIntervalSeconds.value * 2), (timer) {
      if (!_activeSharing.containsKey(receiverId) ||
          !_activeSharing[receiverId]!.isActive) {
        timer.cancel();
        return;
      }

      _getCurrentPositionSafely().then((position) {
        if (position != null) {
          _updateLocationData(receiverId, position);
        }
      });
    });
  }

  // 안전하게 현재 위치 가져오기 (타임아웃 및 오류 처리 개선)
  Future<Position?> _getCurrentPositionSafely() async {
    try {
      // 위치 권한 확인
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;

      // 더 긴 타임아웃 설정 및 저정확도 위치도 허용
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // 정확도 요구사항 낮춤
        timeLimit: const Duration(seconds: 15), // 시간 제한 증가
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('위치 가져오기 타임아웃: 마지막 알려진 위치 사용');
          // 타임아웃 시 마지막 알려진 위치 사용
          if (_lastKnownPosition != null) {
            return _lastKnownPosition!;
          }
          throw TimeoutException('위치 정보를 가져오는 시간이 초과되었습니다.');
        },
      );

      // 성공적으로 가져온 위치를 마지막 알려진 위치로 캐싱
      _lastKnownPosition = position;
      return position;
    } catch (e) {
      print('현재 위치 가져오기 오류: $e');

      // 오류 발생 시 최후의 수단으로 기본 위치 반환 (서울시청 좌표)
      if (_lastKnownPosition == null) {
        // 서울시청 좌표 (기본값)
        Get.snackbar(
          '위치 정보 오류',
          '현재 위치를 가져올 수 없어 기본 위치를 사용합니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return Position(
          longitude: 126.9780, // 서울시청 경도
          latitude: 37.5665, // 서울시청 위도
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
      return _lastKnownPosition;
    }
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

    // 위치 정보 로그 추가
    print('📍 [위치 공유] 위치 정보 업데이트: receiverId=$receiverId');
    print('📍 [위치 공유] 위도: ${position.latitude}, 경도: ${position.longitude}');
    print('📍 [위치 공유] 정확도: ${position.accuracy}m, 속도: ${position.speed}m/s');
    print('📍 [위치 공유] 타임스탬프: ${position.timestamp}');

    try {
      print('📤 [위치 공유] Firebase에 위치 데이터 업데이트 시도...');

      // Firestore에 위치 업데이트
      await _firestore
          .collection('location_sharing')
          .doc(sharedLocation.id)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ [위치 공유] Firebase 위치 데이터 업데이트 성공');

      // 캐시에서 성공적으로 업로드된 항목 제거
      _removeFromLocationCache(sharedLocation.id);
    } catch (e) {
      print('❌ [위치 공유] Firebase 위치 업데이트 오류: $e');
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
    print(
        '✉️ [서비스] 위치 공유 ${isStarting ? "시작" : "종료"} 메시지 전송 시도: receiverId=$receiverId');

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ [서비스] 메시지 전송 실패: 로그인된 사용자 없음');
        return;
      }

      // 현재 사용자 정보 가져오기
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName =
          userDoc.data()?['nickname'] ?? currentUser.displayName ?? '사용자';

      // 위치 공유 ID (시작할 때만 사용)
      String? locationId = isStarting ? _activeSharing[receiverId]?.id : null;

      // 메시지 내용 생성
      final String message = isStarting
          ? '$userName님이 실시간 위치 공유를 시작했습니다. 지도에서 확인하세요.'
          : '$userName님이 위치 공유를 중지했습니다.';

      // 현재 위치 정보 (시작할 때만 포함)
      String locationInfo = '';
      if (isStarting && _lastKnownPosition != null) {
        locationInfo =
            '현재 위치: 위도 ${_lastKnownPosition!.latitude.toStringAsFixed(6)}, 경도 ${_lastKnownPosition!.longitude.toStringAsFixed(6)}';
      }

      // 전체 메시지 (위치 정보 포함)
      final fullMessage = isStarting && locationInfo.isNotEmpty
          ? '$message\n$locationInfo'
          : message;

      // Firestore에 메시지 저장
      await _firestore.collection('messages').add({
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'message': fullMessage,
        'type': 'location_sharing',
        'action': isStarting ? 'start' : 'stop',
        'locationId': locationId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('💾 [서비스] Firestore에 메시지 저장 완료: $fullMessage');

      // FCM 푸시 알림 전송
      await _sendPushNotification(
          receiverId, userName, fullMessage, isStarting, locationId);

      print('✅ [서비스] 위치 공유 ${isStarting ? "시작" : "종료"} 메시지 전송 완료');
    } catch (e) {
      print('❌ [서비스] 메시지 전송 오류: $e');
    }
  }

  // FCM 푸시 알림 전송
  Future<void> _sendPushNotification(String receiverId, String senderName,
      String message, bool isStarting, String? locationId) async {
    print('📤 [서비스] 푸시 알림 전송 시도: receiverId=$receiverId');

    try {
      // 수신자의 FCM 토큰 가져오기
      final tokenDoc =
          await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = tokenDoc.data()?['fcmToken'];
      final currentUserId = _auth.currentUser?.uid ?? '';

      if (fcmToken == null) {
        print('⚠️ [서비스] 수신자의 FCM 토큰 없음');

        // 로컬 알림 보내기 (백그라운드 서비스용)
        try {
          // 로컬 알림 사용을 위한 NotificationService 인스턴스 가져오기
          final notificationService = await Get.putAsync(
              () async => await NotificationService.getInstance(),
              permanent: true);

          // 위치 공유 알림 표시
          await notificationService.showLocationSharingNotification(
            senderName: senderName,
            message: message,
            senderId: currentUserId,
            isStarting: isStarting,
            locationId: locationId,
          );

          print('🔔 [서비스] 위치 공유 알림 전송 완료 (FCM 대체)');
        } catch (e) {
          print('⚠️ [서비스] 위치 공유 알림 전송 오류: $e');
        }

        return;
      }

      // FCM 기능이 구현되어 있다면 여기서 Firebase Cloud Functions를 통해 FCM 메시지 전송
      // 현재는 로컬 알림으로 대체

      // 로컬 알림 보내기
      try {
        // 로컬 알림 사용을 위한 NotificationService 인스턴스 가져오기
        final notificationService = await Get.putAsync(
            () async => await NotificationService.getInstance(),
            permanent: true);

        // 위치 공유 알림 표시
        await notificationService.showLocationSharingNotification(
          senderName: senderName,
          message: message,
          senderId: currentUserId,
          isStarting: isStarting,
          locationId: locationId,
        );

        print('🔔 [서비스] 위치 공유 알림 전송 완료');
      } catch (e) {
        print('⚠️ [서비스] 위치 공유 알림 전송 오류: $e');
      }

      print('✅ [서비스] 푸시 알림 전송 완료');
    } catch (e) {
      print('❌ [서비스] 푸시 알림 전송 오류: $e');
    }
  }

  // 앱 사용자와 위치 공유 시작 (UID로 공유)
  Future<bool> startLocationSharingWithUser(String receiverUid) async {
    print('📡 [서비스] 앱 사용자와 위치 공유 시작: receiverUid=$receiverUid');

    if (!await checkLocationPermission()) {
      print('⚠️ [서비스] 위치 권한 없음: 공유 실패');
      return false;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ [서비스] 사용자 인증 안됨: 공유 실패');
      return false;
    }

    try {
      // 안전하게 위치 정보 가져오기
      print('🔍 [서비스] 현재 위치 가져오기 시도');
      final position = await _getCurrentPositionSafely();
      if (position == null) {
        print('⚠️ [서비스] 위치 정보 획득 실패');
        return false;
      }

      print(
          '📍 [서비스] 위치 획득 성공: lat=${position.latitude}, lng=${position.longitude}');

      final locationId = const Uuid().v4();
      print('🆔 [서비스] 새 위치 공유 ID 생성: $locationId');

      final sharedLocation = SharedLocation(
        id: locationId,
        senderId: userId,
        receiverId: receiverUid,
        receiverType: 'user', // 앱 사용자로 타입 지정
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        isActive: true,
        startTime: DateTime.now(),
      );

      // Firestore에 초기 위치 정보 저장
      print('💾 [서비스] Firestore에 위치 데이터 저장 시도');
      await _firestore
          .collection('location_sharing')
          .doc(locationId)
          .set(sharedLocation.toJson());
      print('✅ [서비스] Firestore 저장 성공');

      // 위치 공유 상태 업데이트 - 중요 변경: userId가 아닌 receiverId를 키로 사용
      _activeSharing[receiverUid] = sharedLocation; // 키를 receiverUid로 사용
      isSharingLocation.value = true;
      if (!sharingToUserIds.contains(receiverUid)) {
        sharingToUserIds.add(receiverUid);
      }
      print(
          '🔄 [서비스] 메모리 상태 업데이트: receiverUid=$receiverUid 추가됨, 총 ${sharingToUserIds.length}개');

      // 로컬 저장소에 상태 저장
      await _saveActiveSharingState();
      print('💾 [서비스] 로컬 저장소에 상태 저장 완료');

      // 위치 추적 시작
      _startPositionTracking(receiverUid);
      print('📡 [서비스] 위치 추적 시작: receiverUid=$receiverUid');

      // 위치 공유 시작 메시지 전송
      _sendLocationSharingStatusMessage(receiverUid, true);

      print('✅ [서비스] 앱 사용자와 위치 공유 시작 완료: receiverUid=$receiverUid');
      return true;
    } catch (e) {
      print('❌ [서비스] 앱 사용자와 위치 공유 시작 오류: $e');
      Get.snackbar(
        '위치 공유 오류',
        '위치 공유를 시작하는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
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
    print('🔍 [서비스] 위치 공유 상태 확인: receiverId=$receiverId');

    // 먼저 receiverId로 직접 확인
    bool isActive = _activeSharing.containsKey(receiverId) &&
        _activeSharing[receiverId]!.isActive;

    // 직접 매칭되지 않는 경우, 활성 공유 목록의 모든 항목을 확인
    if (!isActive && _activeSharing.isNotEmpty) {
      // 모든 활성 공유 항목 검사 (userId가 키로 사용된 경우를 위해)
      for (var entry in _activeSharing.entries) {
        // receiverId가 userId와 일치하는지 확인 (앱 사용자인 경우)
        if (entry.value.receiverId == receiverId && entry.value.isActive) {
          isActive = true;
          print(
              '🔄 [서비스] userId를 통해 활성 공유 발견: key=${entry.key}, receiverId=$receiverId');
          break;
        }
      }
    }

    print(
        '🔍 [서비스] 위치 공유 상태 최종 결과: receiverId=$receiverId, isActive=$isActive');

    // 실제 공유 목록 출력 (디버깅용)
    if (_activeSharing.isNotEmpty) {
      print('📊 [서비스] 현재 활성 공유 목록: ${_activeSharing.keys.join(', ')}');
      // 상세 정보 추가
      _activeSharing.forEach((key, value) {
        print(
            '📋 [서비스] 공유 상세: key=$key, receiverId=${value.receiverId}, senderId=${value.senderId}, isActive=${value.isActive}');
      });
    }

    return isActive;
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

  // 긴급 연락처 유형에 따라 위치 공유 시작
  Future<bool> startLocationSharingWithEmergencyContact(
      String contactId, String? userId, bool isAppUser) async {
    print(
        '🚀 [서비스] 긴급 연락처 위치 공유 시작: contactId=$contactId, userId=$userId, isAppUser=$isAppUser');

    // 위치 권한 확인
    if (!await checkLocationPermission()) {
      print('⚠️ [서비스] 위치 권한 없음: 공유 실패');
      return false;
    }

    try {
      // 위치 정보 로드 중임을 알림
      Get.snackbar(
        '위치 공유 시작 중',
        '위치 정보를 가져오는 중입니다. 잠시만 기다려주세요.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      bool result = false;

      // 앱 사용자/일반 연락처 여부에 따라 공유 방식 결정
      if (isAppUser && userId != null) {
        // 앱 사용자인 경우 userId로 공유
        print('📱 [서비스] 앱 사용자와 공유 시도: userId=$userId, contactId=$contactId');

        // 중요: 앱 사용자의 경우 userId를 전달하지만 contactId를 키로 사용하도록 함
        // userId는 내부적으로만 사용하고, UI에서는 항상 contactId로 상태를 확인할 수 있도록 함
        result = await startLocationSharingWithUser(userId);

        // 만약 현재 위치 공유가 활성화되어 있지만 UI에서 인식하지 못하는 경우,
        // 수동으로 contactId와 userId를 매핑
        if (result &&
            _activeSharing.containsKey(userId) &&
            !_activeSharing.containsKey(contactId)) {
          print('🔄 [서비스] ID 매핑 생성: userId=$userId -> contactId=$contactId');
          // userId로 저장된 정보를 contactId로도 복제
          _activeSharing[contactId] = _activeSharing[userId]!;

          // 목록 업데이트
          if (!sharingToUserIds.contains(contactId)) {
            sharingToUserIds.add(contactId);
          }

          // 변경사항 저장
          await _saveActiveSharingState();
        }
      } else {
        // 일반 연락처인 경우 contactId로 공유
        print('📞 [서비스] 일반 연락처와 공유 시도: contactId=$contactId');
        result = await startLocationSharing(contactId);
      }

      if (result) {
        // UI 즉시 갱신을 위해 Get.forceAppUpdate() 호출
        print('🔄 [서비스] 공유 성공 - UI 강제 갱신');
        Get.forceAppUpdate();
      } else {
        print('⚠️ [서비스] 공유 실패');
      }

      return result;
    } catch (e) {
      print('❌ [서비스] 위치 공유 시작 오류: $e');
      Get.snackbar(
        '위치 공유 오류',
        '위치 공유를 시작하는 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// 특정 사용자에 대한 위치 공유 ID 가져오기
  String? getLocationId(String userId) {
    print('🔍 [서비스] 위치 공유 ID 조회 시도: userId=$userId');

    if (_activeSharing.containsKey(userId)) {
      final id = _activeSharing[userId]?.id;
      print('✅ [서비스] 위치 공유 ID 찾음: $id');
      return id;
    }

    print('ℹ️ [서비스] 위치 공유 ID를 찾을 수 없음');
    return null;
  }
}
