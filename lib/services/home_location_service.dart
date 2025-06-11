import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/home_location_model.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'dart:convert';

class HomeLocationService extends GetxController {
  // 가정용 위치 목록
  final RxList<HomeLocationModel> homeLocations = <HomeLocationModel>[].obs;

  // 현재 선택된 위치 ID
  final RxString selectedHomeLocationId = ''.obs;

  // 로딩 상태
  final RxBool isLoading = false.obs;

  // 오류 상태
  final RxString errorMessage = ''.obs;

  // Auth 서비스
  final AuthService _authService = Get.find<AuthService>();

  // MessageService (선택적)
  MessageService? _messageService;

  // 로컬 저장소
  SharedPreferences? _prefs;

  // 싱글톤 인스턴스
  static HomeLocationService? _instance;

  // 위치 저장소 키
  static const String _homeLocationsKey = 'home_locations';
  static const String _selectedHomeLocationIdKey = 'selected_home_location_id';

  // 싱글톤 인스턴스 가져오기
  static Future<HomeLocationService> getInstance() async {
    if (_instance == null) {
      _instance = HomeLocationService._();
      await _instance!._init();
    }
    return _instance!;
  }

  // 생성자
  HomeLocationService._();

  // 초기화 메소드
  Future<void> _init() async {
    try {
      // SharedPreferences 인스턴스 가져오기
      _prefs = await SharedPreferences.getInstance();

      // MessageService 가져오기 (선택적)
      try {
        if (Get.isRegistered<MessageService>()) {
          _messageService = Get.find<MessageService>();
        }
      } catch (e) {
        debugPrint('⚠️ MessageService를 찾을 수 없음: $e');
      }

      // 저장된 위치 ID 불러오기
      final savedLocationId =
          _prefs?.getString(_selectedHomeLocationIdKey) ?? '';
      if (savedLocationId.isNotEmpty) {
        selectedHomeLocationId.value = savedLocationId;
      }

      // 위치 목록 불러오기
      await loadHomeLocations();
    } catch (e) {
      debugPrint('❌ HomeLocationService 초기화 중 오류: $e');
      errorMessage.value = '설정을 불러오는 중 오류가 발생했습니다: $e';
    }
  }

  // 위치 목록 불러오기
  Future<void> loadHomeLocations() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // 사용자 ID 확인
      final userId = _authService.uid;
      if (userId == null) {
        errorMessage.value = '로그인 상태를 확인할 수 없습니다.';
        isLoading.value = false;
        return;
      }

      // 로컬 저장소에서 위치 목록 불러오기
      final locationsJson = _prefs?.getString(_homeLocationsKey) ?? '[]';
      final List<dynamic> locationsData = json.decode(locationsJson);

      // 목록 초기화
      homeLocations.clear();

      // 위치 목록 변환 및 추가
      for (var data in locationsData) {
        try {
          final location = HomeLocationModel.fromJson(data);
          // 현재 사용자의 위치만 추가
          if (location.userId == userId) {
            homeLocations.add(location);
          }
        } catch (e) {
          debugPrint('⚠️ 위치 변환 오류 (무시됨): $e');
        }
      }

      // 선택된 위치 확인
      if (selectedHomeLocationId.value.isNotEmpty) {
        // 저장된 위치가 목록에 있는지 확인
        final exists =
            homeLocations.any((loc) => loc.id == selectedHomeLocationId.value);
        if (!exists) {
          // 없으면 초기화
          selectedHomeLocationId.value = '';
          await _prefs?.remove(_selectedHomeLocationIdKey);
        }
      }

      // 기본 위치 설정 (목록이 있고 선택된 위치가 없는 경우)
      if (homeLocations.isNotEmpty && selectedHomeLocationId.value.isEmpty) {
        // 기본 위치를 먼저 찾음
        final defaultLocation =
            homeLocations.firstWhereOrNull((loc) => loc.isDefault);
        if (defaultLocation != null) {
          selectedHomeLocationId.value = defaultLocation.id;
          await _prefs?.setString(
              _selectedHomeLocationIdKey, defaultLocation.id);
        } else {
          // 기본 위치가 없으면 첫 번째 항목 선택
          selectedHomeLocationId.value = homeLocations.first.id;
          await _prefs?.setString(
              _selectedHomeLocationIdKey, homeLocations.first.id);
        }
      }

      debugPrint('✅ ${homeLocations.length}개의 집 위치를 불러왔습니다');
    } catch (e) {
      debugPrint('❌ 집 위치 불러오기 실패: $e');
      errorMessage.value = '위치 목록을 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // 로컬 저장소에 위치 목록 저장
  Future<void> _saveHomeLocations() async {
    try {
      final List<Map<String, dynamic>> locationsData =
          homeLocations.map((loc) => loc.toJson()).toList();
      final String locationsJson = json.encode(locationsData);
      await _prefs?.setString(_homeLocationsKey, locationsJson);
      debugPrint('✅ 위치 목록 저장 완료');
    } catch (e) {
      debugPrint('❌ 위치 목록 저장 실패: $e');
      errorMessage.value = '위치 목록을 저장하는 중 오류가 발생했습니다: $e';
    }
  }

  // 선택된 홈 위치 가져오기
  HomeLocationModel? getSelectedHomeLocation() {
    if (selectedHomeLocationId.value.isEmpty) return null;
    return homeLocations
        .firstWhereOrNull((loc) => loc.id == selectedHomeLocationId.value);
  }

  // 홈 위치 추가
  Future<bool> addHomeLocation({
    required double latitude,
    required double longitude,
    required String address,
    required String name,
    bool isDefault = false,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // 사용자 ID 확인
      final userId = _authService.uid;
      if (userId == null) {
        errorMessage.value = '로그인 상태를 확인할 수 없습니다.';
        isLoading.value = false;
        return false;
      }

      // ID 생성
      final id = const Uuid().v4();
      final now = DateTime.now();

      // 이 위치가 기본값이면 다른 위치들의 기본값 해제
      if (isDefault) {
        await _updateAllLocationsDefaultStatus(userId, false);
      }

      // 위치 모델 생성
      final homeLocation = HomeLocationModel(
        id: id,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        name: name,
        createdAt: now,
        updatedAt: now,
        isDefault: isDefault,
      );

      // 목록에 추가
      homeLocations.add(homeLocation);

      // 로컬 저장소에 저장
      await _saveHomeLocations();

      // 첫 위치이거나 기본 위치인 경우 선택
      if (homeLocations.length == 1 || isDefault) {
        selectedHomeLocationId.value = id;
        await _prefs?.setString(_selectedHomeLocationIdKey, id);
      }

      debugPrint('✅ 새 집 위치 추가됨: $name');
      return true;
    } catch (e) {
      debugPrint('❌ 집 위치 추가 실패: $e');
      errorMessage.value = '위치를 추가하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // 홈 위치 업데이트
  Future<bool> updateHomeLocation({
    required String id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // 사용자 ID 확인
      final userId = _authService.uid;
      if (userId == null) {
        errorMessage.value = '로그인 상태를 확인할 수 없습니다.';
        isLoading.value = false;
        return false;
      }

      // 위치 확인
      final index = homeLocations.indexWhere((loc) => loc.id == id);
      if (index == -1) {
        errorMessage.value = '수정하려는 위치를 찾을 수 없습니다.';
        isLoading.value = false;
        return false;
      }

      // 기존 위치 정보
      final existingLocation = homeLocations[index];

      // 이 위치가 기본값으로 변경되면 다른 위치들의 기본값 해제
      if (isDefault == true && !existingLocation.isDefault) {
        await _updateAllLocationsDefaultStatus(userId, false);
      }

      // 업데이트된 위치 모델 생성
      final updatedLocation = existingLocation.copyWith(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
        isDefault: isDefault,
      );

      // 목록 업데이트
      homeLocations[index] = updatedLocation;

      // 로컬 저장소에 저장
      await _saveHomeLocations();

      debugPrint('✅ 집 위치 업데이트됨: ${updatedLocation.name}');
      return true;
    } catch (e) {
      debugPrint('❌ 집 위치 업데이트 실패: $e');
      errorMessage.value = '위치를 업데이트하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // 홈 위치 삭제
  Future<bool> deleteHomeLocation(String id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // 선택된 위치인 경우 선택 해제
      if (selectedHomeLocationId.value == id) {
        selectedHomeLocationId.value = '';
        await _prefs?.remove(_selectedHomeLocationIdKey);

        // 다른 위치 선택
        if (homeLocations.length > 1) {
          // 기본 위치를 먼저 찾아봄
          final remainingLocations =
              homeLocations.where((loc) => loc.id != id).toList();
          final defaultLocation =
              remainingLocations.firstWhereOrNull((loc) => loc.isDefault);

          if (defaultLocation != null) {
            selectedHomeLocationId.value = defaultLocation.id;
            await _prefs?.setString(
                _selectedHomeLocationIdKey, defaultLocation.id);
          } else {
            // 첫 번째 항목 선택
            selectedHomeLocationId.value = remainingLocations.first.id;
            await _prefs?.setString(
                _selectedHomeLocationIdKey, remainingLocations.first.id);
          }
        }
      }

      // 목록에서 제거
      homeLocations.removeWhere((loc) => loc.id == id);

      // 로컬 저장소에 저장
      await _saveHomeLocations();

      debugPrint('✅ 집 위치 삭제됨: $id');
      return true;
    } catch (e) {
      debugPrint('❌ 집 위치 삭제 실패: $e');
      errorMessage.value = '위치를 삭제하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // 선택된 홈 위치 설정
  Future<void> setSelectedHomeLocation(String id) async {
    // 목록에 있는지 확인
    final exists = homeLocations.any((loc) => loc.id == id);
    if (!exists) {
      debugPrint('⚠️ 선택하려는 위치가 목록에 없습니다: $id');
      return;
    }

    selectedHomeLocationId.value = id;
    await _prefs?.setString(_selectedHomeLocationIdKey, id);
    debugPrint('✅ 선택된 집 위치 변경: $id');
  }

  // 모든 위치의 기본값 상태 업데이트
  Future<void> _updateAllLocationsDefaultStatus(
      String userId, bool status) async {
    try {
      // 로컬 목록 업데이트
      for (int i = 0; i < homeLocations.length; i++) {
        if (homeLocations[i].isDefault && homeLocations[i].userId == userId) {
          homeLocations[i] = homeLocations[i].copyWith(isDefault: status);
        }
      }

      // 로컬 저장소에 저장
      await _saveHomeLocations();
    } catch (e) {
      debugPrint('⚠️ 기본값 상태 업데이트 중 오류: $e');
    }
  }

  // 귀가 메시지 전송 (실제 메시지 전송 기능)
  Future<bool> sendHomeArrivalMessage({
    required String receiverId,
    required String message,
    required HomeLocationModel homeLocation,
  }) async {
    try {
      debugPrint('[sendHomeArrivalMessage] receiverId: $receiverId');
      debugPrint('[sendHomeArrivalMessage] message: $message');
      debugPrint(
          '[sendHomeArrivalMessage] homeLocation: ${homeLocation.name}, ${homeLocation.address}, ${homeLocation.latitude}, ${homeLocation.longitude}');
      // MessageService가 없으면 실패
      if (_messageService == null) {
        errorMessage.value = '메시지 서비스가 초기화되지 않았습니다.';
        debugPrint('[sendHomeArrivalMessage] 실패: 메시지 서비스가 초기화되지 않음');
        return false;
      }

      // 사용자 ID 확인
      final userId = _authService.uid;
      if (userId == null) {
        errorMessage.value = '로그인 상태를 확인할 수 없습니다.';
        debugPrint('[sendHomeArrivalMessage] 실패: 로그인 상태 없음');
        return false;
      }

      // 메시지 데이터 준비 - 위치 정보 포함
      final locationData = {
        'type': 'arrival_notification',
        'latitude': homeLocation.latitude,
        'longitude': homeLocation.longitude,
        'address': homeLocation.address,
        'name': homeLocation.name,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 메시지 내용을 JSON으로 변환
      final String locationContent = json.encode(locationData);

      debugPrint('[sendHomeArrivalMessage] 전송 데이터: $locationContent');

      // 메시지 전송
      final success = await _messageService!.sendMessage(
        receiverId: receiverId,
        content: locationContent,
        messageType: 'location_arrival',
      );

      debugPrint('[sendHomeArrivalMessage] sendMessage 반환값: $success');

      if (success) {
        debugPrint('✅ 귀가 알림 메시지 전송 성공');
      } else {
        debugPrint('❌ 귀가 알림 메시지 전송 실패');
        errorMessage.value = '메시지 전송에 실패했습니다.';
      }

      return success;
    } catch (e) {
      debugPrint('❌ 귀가 알림 메시지 전송 중 오류: $e');
      errorMessage.value = '메시지 전송 중 오류가 발생했습니다: $e';
      return false;
    }
  }

  // Firebase에서 마이그레이션 (기존 데이터가 있는 경우)
  Future<bool> migrateFromFirebase() async {
    try {
      // Firebase 의존성이 제거된 상태에서는 실행할 수 없음
      debugPrint('⚠️ Firebase 마이그레이션 기능은 더 이상 지원되지 않습니다.');
      return false;
    } catch (e) {
      debugPrint('❌ Firebase 마이그레이션 실패: $e');
      return false;
    }
  }
}
