// ****************************************************************************
// ******** 중요: 이 파일은 보호된 긴급 연락처 서비스 코드입니다. 절대 수정하지 마세요. *******
// ****************************************************************************

import 'dart:convert';
import 'dart:math';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/emergency_contact_model.dart';
import '../main.dart'; // prefsInstance 접근용
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyContactService extends GetxController
    with WidgetsBindingObserver {
  static const String _storageKey = 'emergency_contacts';
  final RxList<EmergencyContact> contacts = <EmergencyContact>[].obs;
  final Rx<bool> isLoading = false.obs;
  final Rx<bool> hasError = false.obs; // 오류 발생 여부 추적

  // 메모리 모드 동작 여부 플래그
  final bool useMemoryOnly;
  // 외부에서 주입된 SharedPreferences 인스턴스
  final SharedPreferences? prefs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 사용자 정의 연락처 목록
  final RxList<EmergencyContact> userContacts = <EmergencyContact>[].obs;

  // 기본 제공 연락처 목록
  final RxList<EmergencyContact> defaultContacts = <EmergencyContact>[].obs;

  // 생성자에서 메모리 모드 옵션과 SharedPreferences 인스턴스를 받음
  EmergencyContactService({
    this.useMemoryOnly = false,
    this.prefs,
  });

  // SharedPreferences 안전 접근
  Future<SharedPreferences?> _getPrefs() async {
    // 메모리 모드라면 null을 반환하여 저장소를 사용하지 않음
    if (useMemoryOnly) {
      debugPrint('🔍 메모리 모드로 작동 중: 저장소에 접근하지 않음');
      return null;
    }

    try {
      // 주입된 인스턴스가 있으면 사용
      if (prefs != null) {
        debugPrint('✅ 주입된 SharedPreferences 인스턴스 사용');
        return prefs;
      }

      // 전역 인스턴스가 있으면 사용
      if (prefsInstance != null && prefsInstance!.getKeys().isNotEmpty) {
        debugPrint('✅ 전역 SharedPreferences 인스턴스 사용');
        return prefsInstance;
      }
    } catch (e) {
      debugPrint('전역 SharedPreferences 접근 실패: $e');
    }

    // 전역 인스턴스가 없거나 접근 실패 시 새로 생성
    try {
      debugPrint('🔄 새 SharedPreferences 인스턴스 생성 시도');
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('❌ SharedPreferences 인스턴스 생성 실패: $e');
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this); // 라이프사이클 관찰 시작

    if (useMemoryOnly) {
      debugPrint('⚠️ 메모리 모드로 작동 중입니다. 앱을 종료하면 데이터가 사라집니다.');
      // 메모리 모드 알림 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          '메모리 모드',
          'SharedPreferences 문제로 메모리 모드로 작동 중입니다. 앱을 종료하면 변경사항이 사라집니다.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.yellow.shade100,
          colorText: Colors.black87,
          duration: const Duration(seconds: 5),
        );
      });
    }

    _initDefaultContacts();
    loadContacts();
    _verifyStorageState(); // 초기 상태 확인
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this); // 라이프사이클 관찰 종료
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드로 갈 때 데이터 상태 확인
    if (state == AppLifecycleState.paused) {
      debugPrint('🔍 앱이 백그라운드로 이동: 데이터 상태 확인');
      _verifyStorageState();
    }
    // 앱이 포그라운드로 돌아올 때 데이터 다시 로드
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔍 앱이 포그라운드로 복귀: 데이터 다시 로드');
      loadContacts();
    }
  }

  // 저장소 상태 확인
  Future<void> _verifyStorageState() async {
    try {
      final prefs = await _getPrefs();
      final storedData = prefs?.getString(_storageKey);

      if (storedData == null) {
        debugPrint('❌ 저장소 확인: SharedPreferences에 데이터가 없음');
      } else {
        debugPrint(
            '✅ 저장소 확인: SharedPreferences에 ${storedData.length} 바이트 데이터 있음');
        // 메모리와 저장소의 데이터 일치 여부 확인
        try {
          final storedContacts = jsonDecode(storedData) as List;
          final storedCount = storedContacts.length;
          debugPrint('📊 저장소에 $storedCount개 연락처, 메모리에 ${contacts.length}개 연락처');
        } catch (e) {
          debugPrint('❌ 저장된 데이터 파싱 오류: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 저장소 확인 중 오류: $e');
    }
  }

  // 기본 긴급 연락처 초기화
  Future<void> _initDefaultContacts() async {
    // 기본 연락처의 ID를 일정하게 유지 (항상 같은 ID 사용)
    final defaultContacts = [
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000001', // 고정 ID 사용
        name: '긴급 신고',
        phoneNumber: '119',
        isDefault: true,
        description: '화재, 구조, 구급 등 긴급 상황',
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000002', // 고정 ID 사용
        name: '경찰청',
        phoneNumber: '112',
        isDefault: true,
        description: '범죄 신고 및 위급 상황',
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000003', // 고정 ID 사용
        name: '해양경찰청',
        phoneNumber: '122',
        isDefault: true,
        description: '해상 긴급 상황',
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000004', // 고정 ID 사용
        name: '마약 신고',
        phoneNumber: '1301',
        isDefault: true,
        description: '마약 범죄 신고 및 제보',
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000005', // 고정 ID 사용
        name: '중앙재난안전상황실',
        phoneNumber: '044-205-1542',
        isDefault: true,
        description: '자연재해 및 대형 사고',
      ),
    ];

    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        debugPrint('SharedPreferences 인스턴스를 가져올 수 없어 메모리에만 기본 연락처 저장');
        contacts.value = defaultContacts;
        return;
      }

      // SharedPreferences 경로 출력 (디버깅용)
      try {
        debugPrint('SharedPreferences 저장 경로: ${prefs.toString()}');
      } catch (e) {
        debugPrint('저장 경로 확인 실패: $e');
      }

      final storedContacts = prefs.getString(_storageKey);

      // 이미 저장된 연락처가 있는지 확인
      if (storedContacts == null) {
        debugPrint('⚠️ 저장된 연락처가 없어 기본 연락처를 저장합니다.');
        final success = await saveContacts(defaultContacts, showMessage: false);
        if (!success) {
          // 저장 실패 시 메모리에라도 저장
          contacts.value = defaultContacts;
        }
      } else {
        debugPrint('✅ 기존 연락처 데이터 발견: ${storedContacts.length} 바이트');

        // 기존 데이터에 기본 연락처 ID가 있는지 확인
        try {
          final List<dynamic> contactsList = jsonDecode(storedContacts);
          final List<String> existingIds =
              contactsList.map((c) => c['id'] as String).toList();

          // 기본 연락처 ID 확인
          bool allDefaultContactsExist = defaultContacts
              .every((contact) => existingIds.contains(contact.id));

          if (!allDefaultContactsExist) {
            debugPrint('⚠️ 일부 기본 연락처가 누락되어 있어 통합합니다.');

            // 기존 사용자 정의 연락처 추출
            final List<EmergencyContact> customContacts = contactsList
                .map((c) => EmergencyContact.fromJson(c))
                .where((contact) => !contact.isDefault)
                .toList();

            // 기본 연락처와 사용자 정의 연락처 통합
            final List<EmergencyContact> mergedContacts = [
              ...defaultContacts,
              ...customContacts
            ];

            final success =
                await saveContacts(mergedContacts, showMessage: false);
            if (!success) {
              // 저장 실패 시 메모리에라도 업데이트
              contacts.value = mergedContacts;
            }
          }
        } catch (e) {
          debugPrint('⚠️ 연락처 데이터 파싱 중 오류: $e');
          final success =
              await saveContacts(defaultContacts, showMessage: false);
          if (!success) {
            contacts.value = defaultContacts;
          }
        }
      }
    } catch (e) {
      debugPrint('기본 연락처 초기화 오류: $e');
      // 로컬 저장소 오류 시 메모리에만 저장
      contacts.value = defaultContacts;
    }
  }

  // 모든 연락처 로드
  Future<void> loadContacts() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final prefs = await _getPrefs();
      if (prefs == null) {
        throw Exception('SharedPreferences 인스턴스를 얻을 수 없음');
      }

      await _checkSharedPreferences(prefs); // SharedPreferences 상태 확인

      final storedContacts = prefs.getString(_storageKey);

      if (storedContacts != null && storedContacts.isNotEmpty) {
        debugPrint(
            '로드된 연락처 데이터: ${storedContacts.substring(0, min(100, storedContacts.length))}${storedContacts.length > 100 ? '...' : ''}');

        final List<dynamic> decodedList = jsonDecode(storedContacts);
        contacts.value =
            decodedList.map((item) => EmergencyContact.fromJson(item)).toList();
        debugPrint('연락처 ${contacts.length}개 로드됨');
      } else {
        debugPrint('저장된 연락처가 없음');
        // 저장된 연락처가 없으면 기본 연락처만 다시 초기화
        await _initDefaultContacts();
      }
    } catch (e) {
      debugPrint('연락처 로드 오류: $e');
      hasError.value = true;
      // 오류가 발생했을 때 이미 메모리에 있는 연락처를 유지
      if (contacts.isEmpty) {
        // 기본 연락처를 메모리에 저장
        _loadDefaultContactsToMemory();
      }
    } finally {
      isLoading.value = false;
    }
  }

  // SharedPreferences 디버깅 도구
  Future<void> _checkSharedPreferences(SharedPreferences prefs) async {
    try {
      final keys = prefs.getKeys();
      debugPrint('==== SharedPreferences 상태 확인 ====');
      debugPrint('저장된 키 개수: ${keys.length}');
      if (keys.isNotEmpty) {
        debugPrint('저장된 키 목록: $keys');

        // emergency_contacts 키가 있는지 확인
        if (keys.contains(_storageKey)) {
          final data = prefs.getString(_storageKey);
          debugPrint('$_storageKey 데이터 크기: ${data?.length ?? 0} 바이트');
        } else {
          debugPrint('⚠️ $_storageKey 키가 없음!');
        }
      } else {
        debugPrint('⚠️ SharedPreferences에 저장된 키 없음!');
      }
      debugPrint('====================================');
    } catch (e) {
      debugPrint('⚠️ SharedPreferences 확인 중 오류: $e');
    }
  }

  // 로컬 저장소 접근 오류 시 기본 연락처를 메모리에만 저장
  void _loadDefaultContactsToMemory() {
    contacts.value = [
      EmergencyContact(
        id: const Uuid().v4(),
        name: '긴급 신고',
        phoneNumber: '119',
        isDefault: true,
        description: '화재, 구조, 구급 등 긴급 상황',
      ),
      EmergencyContact(
        id: const Uuid().v4(),
        name: '경찰청',
        phoneNumber: '112',
        isDefault: true,
        description: '범죄 신고 및 위급 상황',
      ),
      EmergencyContact(
        id: const Uuid().v4(),
        name: '마약 신고',
        phoneNumber: '1301',
        isDefault: true,
        description: '마약 범죄 신고 및 제보',
      ),
    ];
  }

  // 전화번호 형식 자동 정리 (하이픈 추가)
  String formatPhoneNumber(String phoneNumber) {
    // 모든 공백과 하이픈 제거
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    // 이미 정리된 번호라면 그대로 반환
    if (cleaned.length <= 3) {
      return cleaned; // 너무 짧은 번호는 그대로 반환 (119, 112 등)
    }

    // 한국 전화번호 형식에 맞게 하이픈 추가
    if (cleaned.length == 8) {
      // 지역번호 없는 전화번호 (예: 1234-5678)
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4)}';
    } else if (cleaned.length == 11) {
      // 휴대폰 번호 (예: 010-1234-5678)
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      // 지역번호가 2자리인 경우 (예: 02-123-4567)
      if (cleaned.startsWith('02')) {
        return '${cleaned.substring(0, 2)}-${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
      }
      // 지역번호가 3자리인 경우 (예: 031-123-4567)
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 12) {
      // 국제 코드나 특수 번호 (예: 0505-123-4567)
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
    }

    // 예상하지 못한 길이는 4자리마다 하이픈 추가
    String formatted = '';
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += '-';
      }
      formatted += cleaned[i];
    }
    return formatted;
  }

  // 연락처 저장
  Future<bool> saveContacts(List<EmergencyContact> contactsList,
      {bool showMessage = true}) async {
    isLoading.value = true;
    hasError.value = false;
    bool success = false;
    int retryCount = 0;
    const maxRetries = 3;

    // 메모리 모드라면 저장 없이 메모리 업데이트만 수행
    if (useMemoryOnly) {
      contacts.value = contactsList;
      isLoading.value = false;

      if (showMessage) {
        Get.snackbar(
          '메모리 모드',
          '연락처가 메모리에만 저장되었습니다. 앱을 종료하면 변경사항이 사라집니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.yellow.shade100,
          colorText: Colors.black87,
          duration: const Duration(seconds: 3),
        );
      }

      debugPrint('🔍 메모리 모드: 연락처 ${contactsList.length}개가 메모리에만 저장됨');
      return false; // 실제 저장은 실패했지만 UI는 업데이트
    }

    // 데이터 직렬화는 한 번만 수행
    final encodedList =
        jsonEncode(contactsList.map((contact) => contact.toJson()).toList());
    debugPrint('저장할 데이터 크기: ${encodedList.length} 바이트');

    // 저장 시도 함수
    Future<bool> attemptSave() async {
      try {
        final prefs = await _getPrefs();
        if (prefs == null) {
          debugPrint('❌ SharedPreferences 인스턴스를 얻을 수 없음');
          return false;
        }

        // 저장 시도 전 상태 기록
        debugPrint('📝 저장 시도 전 상태: 키 개수=${prefs.getKeys().length}');

        try {
          final result = await prefs.setString(_storageKey, encodedList);

          // 저장 후 즉시 검증
          final verifyData = prefs.getString(_storageKey);
          final verified = verifyData != null && verifyData.isNotEmpty;

          if (!result) {
            debugPrint('❌ 저장 명령 실패 (시도 ${retryCount + 1}/$maxRetries)');
            return false;
          } else if (!verified) {
            debugPrint('❌ 저장 후 데이터 검증 실패 (시도 ${retryCount + 1}/$maxRetries)');
            return false;
          }

          debugPrint(
              '✅ 저장 성공 (시도 ${retryCount + 1}/$maxRetries) - 데이터 크기: ${verifyData.length} 바이트');
          return true;
        } catch (e) {
          debugPrint('❌ setString 작업 중 오류: $e');
          return false;
        }
      } catch (e) {
        debugPrint('❌ 저장 전 작업 중 오류 발생: $e (시도 ${retryCount + 1}/$maxRetries)');
        return false;
      }
    }

    // 최대 3번까지 저장 시도
    while (retryCount < maxRetries && !success) {
      success = await attemptSave();

      if (!success) {
        retryCount++;
        if (retryCount < maxRetries) {
          // 다음 시도 전 짧은 대기
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        }
      } else {
        break; // 성공하면 반복 종료
      }
    }

    // 최종 결과 처리
    if (success) {
      // 성공했을 때만 연락처 목록 업데이트
      contacts.value = contactsList;
      debugPrint('연락처 ${contactsList.length}개 메모리에 저장됨');
      hasError.value = false;
    } else {
      debugPrint('❌ 모든 저장 시도 실패 ($maxRetries회)');
      hasError.value = true;

      if (showMessage) {
        Get.snackbar(
          '저장 오류',
          '연락처가 저장되지 않았습니다. 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black87,
        );
      }

      // 저장 실패 시 최소한 메모리에는 저장 (UI에 바로 반영되도록)
      contacts.value = contactsList;
    }

    isLoading.value = false;
    return success;
  }

  // 새 연락처 추가
  Future<bool> addContact(EmergencyContact contact) async {
    // 전화번호 형식 자동 정리
    final formattedContact =
        contact.copyWith(phoneNumber: formatPhoneNumber(contact.phoneNumber));

    final newList = [...contacts, formattedContact];
    bool result = await saveContacts(newList);
    return result;
  }

  // 연락처 업데이트
  Future<bool> updateContact(EmergencyContact updatedContact) async {
    // 전화번호 형식 자동 정리
    final formattedContact = updatedContact.copyWith(
        phoneNumber: formatPhoneNumber(updatedContact.phoneNumber));

    final newList = contacts.map((contact) {
      return contact.id == formattedContact.id ? formattedContact : contact;
    }).toList();
    bool result = await saveContacts(newList);
    return result;
  }

  // 연락처 삭제
  Future<bool> deleteContact(String id) async {
    try {
      // 기본 연락처는 삭제할 수 없음
      final contactToDelete = contacts.firstWhere((c) => c.id == id);
      if (contactToDelete.isDefault) {
        hasError.value = true;
        Get.snackbar(
          '삭제 오류',
          '기본 연락처는 삭제할 수 없습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.black87,
        );
        return false;
      }

      final newList = contacts.where((contact) => contact.id != id).toList();
      bool result = await saveContacts(newList);
      return result;
    } catch (e) {
      // 연락처를 찾지 못한 경우
      debugPrint('❌ 연락처 삭제 오류: $e');
      hasError.value = true;
      Get.snackbar(
        '삭제 오류',
        '연락처를 찾을 수 없습니다.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black87,
      );
      return false;
    }
  }

  // 기본 연락처만 가져오기
  List<EmergencyContact> get defaultContactsList =>
      contacts.where((contact) => contact.isDefault).toList();

  // 사용자 정의 연락처만 가져오기
  List<EmergencyContact> get customContacts =>
      contacts.where((contact) => !contact.isDefault).toList();

  // 연락처 목록 로드
  Future<void> _loadContacts() async {
    // 기본 제공 연락처 로드
    defaultContacts.value = EmergencyContact.getDefaultContacts();

    // 사용자 정의 연락처 로드
    await _loadUserContacts();
  }

  // 사용자 정의 연락처 로드
  Future<void> _loadUserContacts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // 로컬 저장소에서 먼저 로드 (오프라인 지원)
      await _loadContactsFromLocal();

      // Firestore에서 로드
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .get();

      final List<EmergencyContact> contacts = snapshot.docs
          .map((doc) => EmergencyContact.fromFirestore(doc))
          .toList();

      userContacts.value = contacts;

      // 로컬 저장소에 저장
      _saveContactsToLocal();
    } catch (e) {
      print('연락처 로드 오류: $e');
    }
  }

  // 로컬 저장소에서 연락처 로드
  Future<void> _loadContactsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('emergency_contacts');

      if (contactsJson != null && contactsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(contactsJson);
        final List<EmergencyContact> contacts =
            decoded.map((item) => EmergencyContact.fromJson(item)).toList();

        userContacts.value = contacts;
      }
    } catch (e) {
      print('로컬 연락처 로드 오류: $e');
    }
  }

  // 로컬 저장소에 연락처 저장
  Future<void> _saveContactsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> contactsJson =
          userContacts.map((contact) => contact.toJson()).toList();

      prefs.setString('emergency_contacts', jsonEncode(contactsJson));
    } catch (e) {
      print('로컬 연락처 저장 오류: $e');
    }
  }
}
