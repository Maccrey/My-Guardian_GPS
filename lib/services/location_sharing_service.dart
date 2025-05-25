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
import 'message_service.dart'; // MessageService 추가

class LocationSharingService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 공유 중인 위치 정보 저장
  final RxMap<String, SharedLocation> _activeSharing =
      <String, SharedLocation>{}.obs;

  // 위치 수신 스트림 구독 객체 저장
  final Map<String, StreamSubscription<Position>> _positionStreams = {};

  // 폴백 타이머 저장 (추가)
  final Map<String, Timer> _fallbackTimers = {};

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

      // 위치 공유 시작 메시지 전송 (비동기로 실행하되 완료 대기)
      try {
        print('✉️ [서비스] 위치 공유 시작 메시지 전송 시도');
        await _sendLocationSharingStatusMessage(receiverId, true);
        print('✅ [서비스] 위치 공유 시작 메시지 전송 완료');
      } catch (e) {
        print('⚠️ [서비스] 위치 공유 시작 메시지 전송 오류: $e');
        // 메시지 전송 실패를 사용자에게 알림
        Get.snackbar(
          '알림',
          '위치 공유는 시작되었지만 메시지 전송에 실패했습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }

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
      // 위치 추적 중지 - 먼저 호출하여 스트림 및 타이머를 확실히 중지
      print('🔄 [서비스] 위치 추적 중지');
      _stopPositionTracking(receiverId);

      // 폴백 타이머도 명시적으로 취소
      _stopFallbackPositionTimer(receiverId);

      // 위치 공유 종료 상태로 업데이트
      SharedLocation? sharedLocation;
      if (_activeSharing.containsKey(receiverId)) {
        print('🔍 [서비스] 활성 공유 정보 찾음: receiverId=$receiverId');
        sharedLocation = _activeSharing[receiverId]!;
      } else {
        // receiverId로 찾지 못한 경우 전체 목록에서 해당 receiverId와 일치하는 항목 검색
        print('🔍 [서비스] 대체 방법으로 활성 공유 정보 검색');
        for (var entry in _activeSharing.entries) {
          if (entry.value.receiverId == receiverId) {
            sharedLocation = entry.value;
            receiverId = entry.key; // 실제 맵에 저장된 키로 갱신
            print('✅ [서비스] 대체 키로 활성 공유 발견: key=${entry.key}');
            break;
          }
        }
      }

      if (sharedLocation != null) {
        // Firestore 문서 삭제 대신 비활성화로 변경 (60분 보존)
        print('🔄 [서비스] Firestore 데이터 비활성화: locationId=${sharedLocation.id}');
        try {
          final endTime = DateTime.now();
          final retentionTime = endTime.add(Duration(minutes: 60)); // 60분 보존

          await _firestore
              .collection('location_sharing')
              .doc(sharedLocation.id)
              .update({
            'isActive': false,
            'endTime': endTime,
            'retentionTime': retentionTime, // 보존 만료 시간
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('✅ [서비스] Firestore 위치 공유 데이터 비활성화 성공 (60분 보존)');
        } catch (e) {
          print('⚠️ [서비스] Firestore 데이터 비활성화 오류: $e');
          // 비활성화 실패해도 진행 (로컬 상태는 업데이트)
        }

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

        // 위치 공유 종료 메시지 전송 (비동기로 실행하고 결과 대기)
        try {
          print('✉️ [서비스] 위치 공유 종료 메시지 전송 시도: receiverId=$receiverId');
          await _sendLocationSharingStatusMessage(receiverId, false);
          print('✅ [서비스] 위치 공유 종료 메시지 전송 완료');
        } catch (e) {
          print('⚠️ [서비스] 위치 공유 종료 메시지 전송 오류: $e');
          // 위치 공유는 중지되었지만 메시지 전송 실패를 사용자에게 알림
          Get.snackbar(
            '알림',
            '위치 공유는 중지되었지만 메시지 전송에 실패했습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }

        // MessageService에게 위치 공유 종료 알림 (추가)
        try {
          final messageService = Get.find<MessageService>();
          if (messageService != null) {
            print('🔔 [서비스] MessageService에 위치 공유 종료 알림');
            messageService.activeLocationSharing.remove(receiverId);
            messageService.activeLocationSharing.refresh();
          }
        } catch (e) {
          print('⚠️ [서비스] MessageService 업데이트 오류 (무시됨): $e');
        }

        // UI 갱신 (추가)
        Get.forceAppUpdate();

        print('✅ [서비스] 위치 공유 중지 완료: receiverId=$receiverId');
        return true;
      } else {
        print('⚠️ [서비스] 활성 공유 정보 없음: receiverId=$receiverId');

        // 그래도 스트림과 타이머는 중지 (안전하게)
        _stopPositionTracking(receiverId);
        _stopFallbackPositionTimer(receiverId);

        return false;
      }
    } catch (e) {
      print('❌ [서비스] 위치 공유 중지 오류: $e');

      // 오류 발생해도 스트림과 타이머는 중지 (안전하게)
      _stopPositionTracking(receiverId);
      _stopFallbackPositionTimer(receiverId);

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
    // 먼저 receiverId가 활성 공유 목록에 있는지 확인
    if (!_activeSharing.containsKey(receiverId)) {
      print('⚠️ [서비스] 위치 추적 시작 불가: 활성 공유 없음 - receiverId=$receiverId');
      return;
    }

    // 이미 추적 중인 경우 중지
    _stopPositionTracking(receiverId);

    try {
      print('🔄 [서비스] 위치 추적 시작: receiverId=$receiverId');

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
          // 위치 공유가 취소되었는지 확인
          if (!_activeSharing.containsKey(receiverId)) {
            print('🛑 [서비스] 위치 공유 취소됨: 추적 중지 - receiverId=$receiverId');
            _stopPositionTracking(receiverId);
            _stopFallbackPositionTimer(receiverId);
            return;
          }

          // 위치 업데이트 시 마지막 위치 캐싱
          _lastKnownPosition = position;
          _updateLocationData(receiverId, position);
        },
        onError: (error) {
          print('위치 스트림 오류: $error');

          // 위치 공유가 취소되었는지 확인
          if (!_activeSharing.containsKey(receiverId)) {
            print('🛑 [서비스] 위치 공유 취소됨: 폴백 시작 중지 - receiverId=$receiverId');
            _stopPositionTracking(receiverId);
            _stopFallbackPositionTimer(receiverId);
            return;
          }

          // 타임아웃 오류 발생 시 폴백 메커니즘
          if (error is TimeoutException) {
            print('위치 타임아웃 발생 - 대체 메커니즘 사용');

            // 즉시 한 번 위치 가져오기 시도
            _getCurrentPositionSafely().then((position) {
              // 위치 요청 도중 공유가 취소되었는지 다시 확인
              if (!_activeSharing.containsKey(receiverId)) {
                print(
                    '🛑 [서비스] 위치 공유 취소됨: 위치 업데이트 중지 - receiverId=$receiverId');
                return;
              }

              if (position != null) {
                _updateLocationData(receiverId, position);
              }
            });

            // 폴백: 대체 타이머로 위치 주기적 업데이트
            _startFallbackPositionTimer(receiverId);
          }

          // 오류 발생 시 마지막 알려진 위치 사용
          if (_lastKnownPosition != null &&
              _activeSharing.containsKey(receiverId)) {
            _updateLocationData(receiverId, _lastKnownPosition!);
          }
        },
      );
    } catch (e) {
      print('위치 스트림 초기화 오류: $e');

      // 위치 공유가 취소되었는지 확인
      if (!_activeSharing.containsKey(receiverId)) {
        print('🛑 [서비스] 위치 공유 취소됨: 폴백 타이머 시작 중지 - receiverId=$receiverId');
        return;
      }

      // 실패 시 폴백: 주기적으로 한 번씩 위치 요청
      _startFallbackPositionTimer(receiverId);
    }
  }

  // 폴백 위치 타이머 시작 (스트림 실패 시 대체 메커니즘)
  void _startFallbackPositionTimer(String receiverId) {
    // 먼저 공유 상태 확인
    if (!_activeSharing.containsKey(receiverId)) {
      print('⚠️ [서비스] 폴백 타이머 시작 불가: 활성 공유 없음 - receiverId=$receiverId');
      return;
    }

    // 공유가 비활성화된 경우 타이머를 시작하지 않음
    if (!_activeSharing[receiverId]!.isActive) {
      print('⚠️ [서비스] 폴백 타이머 시작 불가: 비활성화된 공유 - receiverId=$receiverId');
      return;
    }

    // 기존 타이머가 있으면 취소
    _stopFallbackPositionTimer(receiverId);

    print('🔄 [서비스] 폴백 위치 타이머 시작: receiverId=$receiverId');

    // 새 타이머 시작
    _fallbackTimers[receiverId] = Timer.periodic(
        Duration(seconds: updateIntervalSeconds.value * 2), (timer) {
      // 매 타이머 실행 시 공유 상태 다시 확인 (더 엄격한 검사)
      if (!_activeSharing.containsKey(receiverId)) {
        print('🛑 [서비스] 위치 공유 취소됨: 폴백 타이머 중지 - receiverId=$receiverId');
        timer.cancel();
        _fallbackTimers.remove(receiverId);
        return;
      }

      // 비활성화된 경우도 명시적으로 체크
      if (!_activeSharing[receiverId]!.isActive) {
        print('🛑 [서비스] 비활성화된 공유: 폴백 타이머 즉시 중지 - receiverId=$receiverId');
        timer.cancel();
        _fallbackTimers.remove(receiverId);
        return;
      }

      print('🔄 [서비스] 폴백 타이머로 위치 업데이트 시도: receiverId=$receiverId');

      _getCurrentPositionSafely().then((position) {
        // 위치 획득 후 다시 공유 상태 확인 (더 엄격한 검사)
        if (!_activeSharing.containsKey(receiverId) ||
            !_activeSharing[receiverId]!.isActive) {
          print(
              '🛑 [서비스] 위치 공유 취소됨 또는 비활성화됨: 위치 업데이트 중지 - receiverId=$receiverId');
          timer.cancel();
          _fallbackTimers.remove(receiverId);
          return;
        }

        if (position != null) {
          _updateLocationData(receiverId, position);
        }
      });
    });
  }

  // 폴백 타이머 중지 (추가)
  void _stopFallbackPositionTimer(String receiverId) {
    if (_fallbackTimers.containsKey(receiverId)) {
      _fallbackTimers[receiverId]?.cancel();
      _fallbackTimers.remove(receiverId);
      print('🛑 [서비스] 폴백 타이머 취소: receiverId=$receiverId');
    }
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
    // 위치 스트림 구독 취소
    if (_positionStreams.containsKey(receiverId)) {
      _positionStreams[receiverId]?.cancel();
      _positionStreams.remove(receiverId);
      print('🛑 [서비스] 위치 스트림 구독 취소: receiverId=$receiverId');
    }

    // 폴백 타이머 취소 (추가)
    _stopFallbackPositionTimer(receiverId);
  }

  // 위치 정보 업데이트
  Future<void> _updateLocationData(String receiverId, Position position) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ [위치 공유] 위치 업데이트 중단: 사용자 인증 안됨');
      return;
    }

    // 활성 공유 여부 확인
    if (!_activeSharing.containsKey(receiverId)) {
      print('⚠️ [위치 공유] 위치 업데이트 중단: 활성 공유 없음 - receiverId=$receiverId');
      // 위치 추적이 아직 완전히 중지되지 않았을 수 있으므로 중지 시도
      _stopPositionTracking(receiverId);
      _stopFallbackPositionTimer(receiverId);
      return;
    }

    // isActive 상태 추가 확인 - 비활성화된 경우 즉시 중단
    if (!_activeSharing[receiverId]!.isActive) {
      print('🛑 [위치 공유] 위치 업데이트 즉시 중단: 비활성화된 공유 - receiverId=$receiverId');
      // 위치 추적 중지
      _stopPositionTracking(receiverId);
      _stopFallbackPositionTimer(receiverId);
      return;
    }

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

      // 먼저 문서가 존재하는지 확인
      final docSnapshot = await _firestore
          .collection('location_sharing')
          .doc(sharedLocation.id)
          .get()
          .catchError((e) {
        print('⚠️ [위치 공유] 문서 존재 확인 오류: $e');
        return null;
      });

      if (docSnapshot == null || !docSnapshot.exists) {
        print('⚠️ [위치 공유] Firebase 문서가 존재하지 않음: 위치 공유가 이미 중지됨');
        // 로컬 상태 정리 - 문서가 없다면 위치 공유가 중지된 것으로 간주
        _activeSharing.remove(receiverId);
        sharingToUserIds.remove(receiverId);

        if (_activeSharing.isEmpty) {
          isSharingLocation.value = false;
        }

        // 위치 추적 중지
        _stopPositionTracking(receiverId);
        _stopFallbackPositionTimer(receiverId);

        // 로컬 저장소 업데이트
        await _saveActiveSharingState();
        return;
      }

      // 문서가 있지만 이미 비활성화된 경우, 즉시 위치 업데이트 중단
      final docData = docSnapshot.data();
      if (docData != null && docData['isActive'] == false) {
        print('🛑 [위치 공유] 비활성화된 공유: 위치 업데이트 즉시 중단');

        // 로컬 상태 정리
        _activeSharing.remove(receiverId);
        sharingToUserIds.remove(receiverId);

        if (_activeSharing.isEmpty) {
          isSharingLocation.value = false;
        }

        // 위치 추적 중지
        _stopPositionTracking(receiverId);
        _stopFallbackPositionTimer(receiverId);

        // 로컬 저장소 업데이트
        await _saveActiveSharingState();

        print('✅ [위치 공유] 공유 정지 후 위치 추적 완전 중단');

        // 문서는 삭제하지 않고 60분 보존 기간 동안 유지 (표시 목적)
        return;
      }

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

      // 오류 메시지 분석
      String errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('not found') ||
          errorMsg.contains('no document to update') ||
          errorMsg.contains('not exist')) {
        print('🛑 [위치 공유] 문서가 존재하지 않음: 위치 공유 중지 처리');

        // 로컬 상태 정리
        _activeSharing.remove(receiverId);
        sharingToUserIds.remove(receiverId);

        if (_activeSharing.isEmpty) {
          isSharingLocation.value = false;
        }

        // 위치 추적 중지
        _stopPositionTracking(receiverId);
        _stopFallbackPositionTimer(receiverId);

        // 로컬 저장소 업데이트
        await _saveActiveSharingState();
      } else {
        // 다른 오류인 경우 캐시에 유지 (나중에 다시 시도)
      }
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
      // 현재 인증 상태를 새로고침하여 토큰이 유효한지 확인
      try {
        await _auth.currentUser?.reload();
        print('🔄 [서비스] 사용자 인증 상태 새로고침 완료');
      } catch (authError) {
        print('⚠️ [서비스] 사용자 인증 상태 새로고침 실패: $authError');
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ [서비스] 메시지 전송 실패: 로그인된 사용자 없음');
        throw Exception('로그인된 사용자가 없습니다. 로그인 후 다시 시도하세요.');
      }

      print('🔍 [서비스] 현재 인증된 사용자 UID: ${currentUser.uid}');

      // 현재 사용자 정보 가져오기
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName =
          userDoc.data()?['nickname'] ?? currentUser.displayName ?? '사용자';

      // 위치 공유 ID (시작할 때만 사용)
      String? locationId = isStarting ? _activeSharing[receiverId]?.id : null;

      // 종료 메시지일 경우 기존 locationId 찾기
      if (!isStarting && locationId == null) {
        print('🔍 [서비스] 종료 메시지용 위치 공유 ID 찾기');
        // 인덱스 오류 방지를 위해 간소화된 쿼리 사용
        final recentMessages = await _firestore
            .collection('messages')
            .where('senderId', isEqualTo: currentUser.uid)
            .where('receiverId', isEqualTo: receiverId)
            .limit(50) // 최근 50개 메시지만 조회
            .get();

        // 직접 필터링
        for (var doc in recentMessages.docs) {
          final data = doc.data();
          if (data['type'] == 'location_sharing' && data['action'] == 'start') {
            locationId = data['locationId'];
            print('✅ [서비스] 기존 위치 공유 ID 찾음: $locationId');
            break;
          }
        }
      }

      // 메시지 내용 생성
      final String message = isStarting
          ? '$userName님이 실시간 위치 공유를 시작했습니다. 지도에서 확인하세요.'
          : '$userName님이 위치 공유를 중지했습니다.';

      // 현재 위치 정보 (시작할 때만 포함)
      String locationInfo = '';
      Map<String, dynamic> messageData = {
        'message': message,
        'type': 'location_sharing',
        'action': isStarting ? 'start' : 'stop',
        'locationId': locationId,
        'senderName': userName,
      };

      if (isStarting && _lastKnownPosition != null) {
        locationInfo =
            '현재 위치: 위도 ${_lastKnownPosition!.latitude.toStringAsFixed(6)}, 경도 ${_lastKnownPosition!.longitude.toStringAsFixed(6)}';

        // 위치 데이터 추가
        messageData['latitude'] = _lastKnownPosition!.latitude;
        messageData['longitude'] = _lastKnownPosition!.longitude;
        messageData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      // 전체 메시지 (위치 정보 포함)
      final fullMessage = isStarting && locationInfo.isNotEmpty
          ? '$message\n$locationInfo'
          : message;

      // 참가자 ID를 일관된 순서로 정렬하여 항상 같은 채팅방 ID가 생성되도록 함
      List<String> participants = [currentUser.uid, receiverId];
      participants.sort(); // 알파벳 순서로 정렬하여 일관성 보장

      // 채팅방 ID 조회 또는 생성 (동일한 채팅방 사용을 위해)
      String chatRoomId = '';

      // 참가자 ID를 직접 조합하여 고정된 채팅방 ID 생성
      String participantsKey = participants.join('_');

      // Firestore에서 일치하는 채팅방 검색
      try {
        // 먼저 chat_rooms 컬렉션에서 participants 배열에 두 사용자가 모두 포함된 문서 찾기
        final chatRooms = await _firestore
            .collection('chat_rooms')
            .where('participants', arrayContainsAny: participants)
            .get();

        print('🔍 [서비스] 채팅방 검색 결과: ${chatRooms.docs.length}개');

        for (var room in chatRooms.docs) {
          final roomParticipants = room.data()['participants'] as List<dynamic>;
          // 두 참가자가 모두 포함되어 있고 다른 참가자는 없는지 확인
          if (roomParticipants.contains(currentUser.uid) &&
              roomParticipants.contains(receiverId) &&
              roomParticipants.length == 2) {
            chatRoomId = room.id;
            print('🔍 [서비스] 기존 채팅방 찾음: $chatRoomId');
            break;
          }
        }
      } catch (e) {
        print('⚠️ [서비스] 채팅방 검색 오류 (무시됨): $e');
      }

      // 채팅방이 없으면 새로 생성
      if (chatRoomId.isEmpty) {
        print('➕ [서비스] 새 채팅방 생성');

        // 고정된 채팅방 ID 생성 시도 (참가자 ID 조합)
        try {
          chatRoomId = participantsKey;

          // 기존에 문서가 있는지 확인
          final existingDoc =
              await _firestore.collection('chat_rooms').doc(chatRoomId).get();

          if (!existingDoc.exists) {
            // 문서가 없으면 고정 ID로 새 문서 생성
            await _firestore.collection('chat_rooms').doc(chatRoomId).set({
              'participants': participants,
              'createdAt': FieldValue.serverTimestamp(),
              'lastMessageAt': FieldValue.serverTimestamp(),
            });
            print('✅ [서비스] 고정 ID로 새 채팅방 생성 완료: $chatRoomId');
          } else {
            print('✅ [서비스] 고정 ID의 채팅방이 이미 존재함: $chatRoomId');
          }
        } catch (e) {
          print('⚠️ [서비스] 고정 ID 채팅방 생성 실패: $e');

          // 실패하면 자동 ID 생성으로 대체
          final newChatRoom = await _firestore.collection('chat_rooms').add({
            'participants': participants,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessageAt': FieldValue.serverTimestamp(),
          });
          chatRoomId = newChatRoom.id;
          print('✅ [서비스] 자동 ID로 새 채팅방 생성 완료: $chatRoomId');
        }
      }

      // 메시지 데이터 구성 - MessageModel과 완벽히 호환되도록 필드명 수정
      Map<String, dynamic> messageDoc = {
        'senderId': currentUser.uid, // 현재 인증된 사용자의 UID 사용
        'receiverId': receiverId,
        'content': fullMessage,
        'messageType': 'location_sharing',

        // Message 모델의 data 필드에 구조화된 데이터 저장
        'data': {
          'latitude': _lastKnownPosition?.latitude,
          'longitude': _lastKnownPosition?.longitude,
          'message': message,
          'senderName': userName,
        },

        // Message 모델의 extra 필드에 위치 공유 관련 정보 저장
        'extra': {
          'action': isStarting ? 'start' : 'stop',
          'locationId': locationId,
        },

        // 이전 버전 호환성 유지 (기존 필드들)
        'messageData': messageData,
        'type': 'location_sharing',
        'action': isStarting ? 'start' : 'stop',
        'locationId': locationId,

        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'chatRoomId': chatRoomId,
      };

      // Firebase 메시지 상세 로깅
      print(
          '📝 [서비스] 위치 공유 메시지 저장 시도 - receiverId: $receiverId, isStarting: $isStarting');
      print('🔍 [서비스] 메시지에 설정된 senderId: ${currentUser.uid}');
      print(
          '📝 [서비스] 메시지 데이터: senderId=${currentUser.uid}, locationId=$locationId');

      try {
        // Firestore에 메시지 저장
        final docRef = await _firestore.collection('messages').add(messageDoc);
        print('✅ [서비스] Firestore에 메시지 저장 완료: ${docRef.id}');

        // 메시지 ID 저장 (오류 디버깅용)
        _firestore.collection('debug_logs').add({
          'action': 'location_message_saved',
          'messageId': docRef.id,
          'senderId': currentUser.uid,
          'receiverId': receiverId,
          'isStarting': isStarting,
          'timestamp': FieldValue.serverTimestamp(),
          'chatRoomId': chatRoomId, // 채팅방 ID 추가 (디버깅용)
        });

        // 채팅방 마지막 메시지 업데이트
        await _firestore.collection('chat_rooms').doc(chatRoomId).update({
          'lastMessage': fullMessage,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageType': 'location_sharing',
        });

        // MessageService에게도 메시지 추가 알림 (동기화)
        try {
          final messageService = Get.find<MessageService>();
          if (messageService != null) {
            print('🔔 [서비스] MessageService에 새 메시지 알림');
            messageService.refreshMessages(); // 메시지 목록 새로고침
          }
        } catch (e) {
          print('⚠️ [서비스] MessageService 업데이트 오류 (무시됨): $e');
        }

        print('💾 [서비스] Firestore에 메시지 저장 완료: $fullMessage');

        // FCM 푸시 알림 전송
        await _sendPushNotification(
            receiverId, userName, fullMessage, isStarting, locationId);

        print('✅ [서비스] 위치 공유 ${isStarting ? "시작" : "종료"} 메시지 전송 완료');
      } catch (e) {
        print('❌ [서비스] Firestore에 메시지 저장 실패: $e');

        // 접근 권한 오류인지 확인
        if (e.toString().contains('permission-denied')) {
          print('🔒 [서비스] 파이어베이스 보안 규칙으로 인한 접근 거부 - 인증 상태 확인 필요');

          // 디버그용 권한 데이터 로깅
          print(
              '🔑 [서비스] 인증된 사용자: ${_auth.currentUser?.uid}, 메시지 발신자: ${messageDoc['senderId']}');
        }
        throw e; // 상위 함수에서 오류 처리를 위해 다시 던짐
      }
    } catch (e) {
      print('❌ [서비스] 위치 공유 메시지 전송 실패: $e');
      // 오류 상세 로깅
      print('❌ [서비스] 오류 상세: ${e.toString()}');

      // 오류를 던져서 호출자가 처리할 수 있도록 함
      rethrow;
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

      // 위치 공유 시작 메시지 전송 (비동기로 실행하되 완료 대기)
      try {
        print('✉️ [서비스] 위치 공유 시작 메시지 전송 시도: receiverUid=$receiverUid');
        await _sendLocationSharingStatusMessage(receiverUid, true);
        print('✅ [서비스] 위치 공유 시작 메시지 전송 완료');
      } catch (e) {
        print('⚠️ [서비스] 위치 공유 시작 메시지 전송 오류: $e');
        // 메시지 전송 실패를 사용자에게 알림
        Get.snackbar(
          '알림',
          '위치 공유는 시작되었지만 메시지 전송에 실패했습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }

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
    print('🧹 [서비스] LocationSharingService 종료 - 리소스 정리');

    // 모든 위치 스트림 구독 취소
    for (var stream in _positionStreams.values) {
      stream.cancel();
    }
    _positionStreams.clear();

    // 모든 폴백 타이머 취소
    for (var timer in _fallbackTimers.values) {
      timer.cancel();
    }
    _fallbackTimers.clear();

    // 필요시 모든 공유 중지
    if (isSharingLocation.value) {
      print('🛑 [서비스] 앱 종료 시 모든 위치 공유 중지');
      stopAllLocationSharing();
    }

    print('✅ [서비스] 모든 리소스 정리 완료');
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
