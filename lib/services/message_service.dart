import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import 'auth_service.dart';

class MessageService extends GetxController {
  static const String _localStorageKey = 'local_messages';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = Get.find<AuthService>();

  // 읽지 않은 메시지 수
  final RxInt unreadMessageCount = 0.obs;

  // 모든 메시지 목록
  final RxList<Message> messages = <Message>[].obs;

  // 로딩 상태
  final RxBool isLoading = false.obs;

  // 에러 상태
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // 스트림 구독
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void onInit() {
    super.onInit();
    _initMessages();
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    super.onClose();
  }

  // 메시지 초기화
  Future<void> _initMessages() async {
    isLoading.value = true;
    hasError.value = false;

    try {
      debugPrint('🔄 메시지 서비스 초기화 시작');

      // 로컬 메시지 불러오기
      await _loadLocalMessages();

      // 사용자가 로그인되어 있으면 Firebase에서 메시지 스트림 구독
      if (_authService.currentUser != null) {
        debugPrint('👤 로그인 상태: ${_authService.uid} - Firestore 구독 시작');
        _subscribeToFirestoreMessages();
      } else {
        debugPrint('⚠️ 로그인되지 않음 - 로컬 메시지만 사용');
      }

      // 읽지 않은 메시지 수 계산
      _updateUnreadCount();

      // 메시지가 비어있는지 확인하고 필요하면 테스트 메시지 생성
      if (messages.isEmpty) {
        debugPrint('⚠️ 메시지 목록이 비어있습니다. 테스트 메시지 생성');
        _createTestMessages();
      }

      isLoading.value = false;
      debugPrint('✅ 메시지 서비스 초기화 완료 (${messages.length}개 메시지)');
    } catch (e) {
      debugPrint('⚠️ 메시지 초기화 오류: $e');
      hasError.value = true;
      errorMessage.value = '메시지를 불러오는 도중 오류가 발생했습니다.';
      isLoading.value = false;

      // 오류 발생 시에도 테스트 메시지 생성
      _createTestMessages();
    }
  }

  // 로컬에 저장된 메시지 불러오기
  Future<void> _loadLocalMessages() async {
    try {
      // SharedPreferences 인스턴스 가져오기 시도
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        debugPrint('🔍 SharedPreferences 인스턴스 가져오기 성공');
      } catch (e) {
        debugPrint('⚠️ SharedPreferences 인스턴스 가져오기 실패: $e');
        // 오류 발생 시 테스트 메시지 생성
        _createTestMessages();
        return;
      }

      if (prefs == null) {
        debugPrint('⚠️ SharedPreferences가 null입니다.');
        _createTestMessages();
        return;
      }

      // 저장된 키 확인
      try {
        final keys = prefs.getKeys();
        debugPrint('🔍 로컬 저장소 확인: $keys');
      } catch (e) {
        debugPrint('⚠️ 저장소 키 목록 가져오기 오류: $e');
      }

      // 메시지 데이터 가져오기
      String? messagesJson;
      try {
        messagesJson = prefs.getString(_localStorageKey);
      } catch (e) {
        debugPrint('⚠️ 메시지 데이터 가져오기 오류: $e');
        _createTestMessages();
        return;
      }

      if (messagesJson != null && messagesJson.isNotEmpty) {
        debugPrint('📄 로컬 메시지 JSON 데이터 크기: ${messagesJson.length} 바이트');
        if (messagesJson.length > 100) {
          debugPrint(
              '📄 로컬 메시지 JSON 앞부분: ${messagesJson.substring(0, 100)}...');
        } else {
          debugPrint('📄 로컬 메시지 JSON: $messagesJson');
        }

        try {
          final List<dynamic> decodedMessages = jsonDecode(messagesJson);
          debugPrint('🔍 JSON 디코딩 성공: ${decodedMessages.length}개 메시지');

          if (decodedMessages.isEmpty) {
            debugPrint('⚠️ 디코딩된 메시지가 비어있습니다. 테스트 메시지 생성');
            _createTestMessages();
            return;
          }

          final List<Message> loadedMessages = [];
          for (var json in decodedMessages) {
            try {
              final message = Message.fromJson(json);
              loadedMessages.add(message);
            } catch (e) {
              debugPrint('⚠️ 메시지 객체 변환 오류: $e');
              // 개별 메시지 변환 오류는 무시하고 계속 진행
            }
          }

          // 시간순 정렬
          loadedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (loadedMessages.isEmpty) {
            debugPrint('⚠️ 유효한 메시지가 없습니다. 테스트 메시지 생성');
            _createTestMessages();
            return;
          }

          // 기존 메시지 목록 갱신
          messages.value = loadedMessages;

          // 추가 디버깅 정보
          for (var msg in loadedMessages.take(3)) {
            debugPrint(
                '📱 로컬 메시지: ID=${msg.id.substring(0, 6)}... | 보낸이=${msg.senderId} | 받는이=${msg.receiverId} | 시간=${msg.timestamp} | 내용=${msg.content.substring(0, msg.content.length > 20 ? 20 : msg.content.length)}...');
          }

          debugPrint('✅ 로컬에서 ${loadedMessages.length}개의 메시지를 불러왔습니다.');
        } catch (e) {
          debugPrint('⚠️ JSON 파싱 오류: $e');
          debugPrint('⚠️ 손상된 메시지 데이터, 로컬 저장소 초기화 후 테스트 메시지 생성');
          await _clearLocalMessages();
          _createTestMessages();
        }
      } else {
        debugPrint('⚠️ 로컬에 저장된 메시지가 없습니다.');

        // 테스트용 더미 메시지 추가 (개발용)
        _createTestMessages();
      }
    } catch (e) {
      debugPrint('⚠️ 로컬 메시지 불러오기 오류: $e');
      // 오류 발생 시 테스트 메시지 생성
      _createTestMessages();
    }
  }

  // 로컬 메시지 저장소 비우기
  Future<void> _clearLocalMessages() async {
    try {
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('⚠️ SharedPreferences 인스턴스 가져오기 실패: $e');
        return;
      }

      if (prefs == null) {
        debugPrint('⚠️ SharedPreferences가 null입니다.');
        return;
      }

      final result = await prefs.remove(_localStorageKey);
      if (result) {
        debugPrint('🧹 로컬 메시지 저장소를 비웠습니다.');
      } else {
        debugPrint('⚠️ 로컬 메시지 저장소 비우기 실패');
      }
    } catch (e) {
      debugPrint('⚠️ 로컬 메시지 저장소 비우기 오류: $e');
    }
  }

  // 로컬에 메시지 저장하기
  Future<void> _saveLocalMessages() async {
    try {
      if (messages.isEmpty) {
        debugPrint('⚠️ 저장할 메시지가 없습니다.');
        return;
      }

      // SharedPreferences 인스턴스 가져오기 시도
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        debugPrint('⚠️ SharedPreferences 인스턴스 가져오기 실패: $e');
        return;
      }

      if (prefs == null) {
        debugPrint('⚠️ SharedPreferences가 null입니다.');
        return;
      }

      try {
        // JSON 직렬화
        final jsonList = messages.map((m) => m.toJson()).toList();
        final String messagesJson = jsonEncode(jsonList);

        // 저장
        final result = await prefs.setString(_localStorageKey, messagesJson);

        if (result) {
          debugPrint('✅ ${messages.length}개의 메시지를 로컬에 저장했습니다.');

          // 첫 메시지 확인용 로그
          if (messages.isNotEmpty) {
            final msg = messages.first;
            debugPrint(
                '📱 마지막 저장 메시지: ID=${msg.id.substring(0, 6)}... | 보낸이=${msg.senderId} | 받는이=${msg.receiverId}');
          }
        } else {
          debugPrint('⚠️ 로컬 저장소에 메시지 저장 실패');
        }
      } catch (e) {
        debugPrint('⚠️ 메시지 JSON 직렬화 또는 저장 오류: $e');
      }
    } catch (e) {
      debugPrint('⚠️ 로컬 메시지 저장 오류: $e');
    }
  }

  // 로컬 메시지 디버깅용 메서드 (외부에서 호출 가능)
  Future<void> debugLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      debugPrint('🔍 로컬 저장소 키 목록: $keys');

      final String? messagesJson = prefs.getString(_localStorageKey);
      if (messagesJson != null) {
        debugPrint('📊 로컬 저장소 메시지 JSON 크기: ${messagesJson.length} 바이트');

        try {
          final List decoded = jsonDecode(messagesJson);
          debugPrint('📊 디코딩된 메시지 수: ${decoded.length}');
        } catch (e) {
          debugPrint('⚠️ JSON 디코딩 오류: $e');
        }
      } else {
        debugPrint('⚠️ 로컬 저장소에 메시지 없음');
      }
    } catch (e) {
      debugPrint('⚠️ 로컬 저장소 디버깅 오류: $e');
    }
  }

  // 모든 로컬 메시지 지우기 (외부에서 호출 가능)
  Future<void> clearAllMessages() async {
    try {
      debugPrint('🧹 모든 메시지 지우기 시작');

      // 메모리 내 메시지 초기화
      messages.clear();

      // 로컬 저장소 초기화
      await _clearLocalMessages();

      // 읽지 않은 메시지 수 업데이트
      _updateUnreadCount();

      debugPrint('✅ 모든 메시지가 삭제되었습니다.');
    } catch (e) {
      debugPrint('⚠️ 메시지 삭제 오류: $e');
    }
  }

  // 테스트용 더미 메시지 생성 (개발 중에만 사용)
  void _createTestMessages() {
    debugPrint('🧪 테스트 메시지 생성 중...');

    // 현재 시간 기준 테스트 ID 생성
    final testSenderId = 'test-${DateTime.now().millisecondsSinceEpoch}';
    // 대화 상대는 기본값으로 설정
    final testReceiverId = 'user-123456';

    debugPrint('🧪 테스트 발신자 ID: $testSenderId, 테스트 수신자 ID: $testReceiverId');

    // 몇 개의 테스트 메시지 생성
    final testMessages = [
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-1',
        senderId: testSenderId,
        receiverId: testReceiverId,
        content: '안녕하세요! 테스트 메시지입니다.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        messageType: 'text',
      ),
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-2',
        senderId: testReceiverId,
        receiverId: testSenderId,
        content: '반갑습니다! 어떻게 지내세요?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isRead: true,
        messageType: 'text',
      ),
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-3',
        senderId: testSenderId,
        receiverId: testReceiverId,
        content: '잘 지내고 있어요. 감사합니다!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        isRead: false,
        messageType: 'text',
      ),
    ];

    // 메시지 목록에 추가
    messages.value = testMessages;

    // 로컬에 저장
    _saveLocalMessages();

    debugPrint('✅ ${testMessages.length}개의 테스트 메시지가 생성되었습니다.');
  }

  // 특정 사용자와의 대화용 테스트 메시지 생성
  void createTestMessagesForUser(String userId) {
    debugPrint('🧪 사용자 $userId와의 테스트 메시지 생성 중...');

    // 현재 시간 기준 테스트 ID 생성
    final testSenderId = 'test-${DateTime.now().millisecondsSinceEpoch}';

    debugPrint('🧪 테스트 발신자 ID: $testSenderId, 대화 상대 ID: $userId');

    // 몇 개의 테스트 메시지 생성
    final testMessages = [
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-1',
        senderId: testSenderId,
        receiverId: userId,
        content: '안녕하세요! $userId님, 테스트 메시지입니다.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        messageType: 'text',
      ),
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-2',
        senderId: userId,
        receiverId: testSenderId,
        content: '반갑습니다! 어떻게 지내세요?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isRead: true,
        messageType: 'text',
      ),
      Message(
        id: 'test-msg-${DateTime.now().millisecondsSinceEpoch}-3',
        senderId: testSenderId,
        receiverId: userId,
        content: '잘 지내고 있어요. 감사합니다!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        isRead: false,
        messageType: 'text',
      ),
    ];

    // 기존 메시지 목록에 추가 (기존 메시지 유지, 테스트 메시지만 추가)
    if (messages.isEmpty) {
      // 메시지가 없으면 직접 설정
      messages.value = testMessages;
    } else {
      // 기존 메시지가 있으면 합치기
      final updatedMessages = [...messages, ...testMessages];
      messages.value = updatedMessages;
    }

    // 로컬에 저장
    _saveLocalMessages();

    debugPrint('✅ 사용자 $userId와의 ${testMessages.length}개의 테스트 메시지가 생성되었습니다.');

    // 저장 후 메시지 수 확인
    final conversation = getConversationWith(userId);
    debugPrint('📊 테스트 메시지 생성 후 대화 메시지 수: ${conversation.length}');
  }

  // Firebase Firestore 메시지 구독
  void _subscribeToFirestoreMessages() {
    final String currentUserId = _authService.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      debugPrint('⚠️ 사용자가 로그인되어 있지 않습니다.');
      return;
    }

    // 기존 구독 취소
    _messagesSubscription?.cancel();

    try {
      // 메시지 스트림 구독 (수신자가 현재 사용자인 메시지와 발신자가 현재 사용자인 메시지)
      _messagesSubscription = _firestore
          .collection('messages')
          .where(Filter.or(
            Filter('receiverId', isEqualTo: currentUserId),
            Filter('senderId', isEqualTo: currentUserId),
          ))
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          // Firestore 데이터를 Message 객체로 변환
          final List<Message> firestoreMessages =
              snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();

          // 로컬 메시지와 Firestore 메시지 병합 (중복 제거)
          _mergeMessages(firestoreMessages);

          // 읽지 않은 메시지 수 업데이트
          _updateUnreadCount();

          debugPrint(
              '✅ Firestore에서 ${firestoreMessages.length}개의 메시지를 불러왔습니다.');
        },
        onError: (error) {
          debugPrint('⚠️ Firestore 메시지 구독 오류: $error');

          // 권한 오류는 개발 모드에서는 경고만 표시
          if (error.toString().contains('permission-denied')) {
            debugPrint('🔒 Firebase 권한 오류: 개발 모드에서는 로컬 데이터만 사용합니다.');
            hasError.value = false; // 오류 상태 해제
          } else {
            hasError.value = true;
            errorMessage.value = 'Firestore에서 메시지를 불러오는 도중 오류가 발생했습니다.';
          }
        },
      );
    } catch (e) {
      debugPrint('⚠️ Firestore 메시지 구독 설정 실패: $e');
      // 권한 오류는 개발 모드에서는 무시
      if (e.toString().contains('permission-denied')) {
        debugPrint('🔒 Firebase 권한 오류: 개발 모드에서는 로컬 저장만 사용합니다.');
      }
    }
  }

  // 로컬 메시지와 Firestore 메시지 병합
  void _mergeMessages(List<Message> firestoreMessages) {
    // 로컬 메시지 중 Firestore에 없는 메시지 찾기
    final List<Message> localOnlyMessages = messages
        .where((local) =>
            !firestoreMessages.any((firestore) => firestore.id == local.id))
        .toList();

    // 모든 메시지 병합 후 시간순 정렬
    final List<Message> mergedMessages = [
      ...firestoreMessages,
      ...localOnlyMessages
    ];
    mergedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 메시지 목록 갱신
    messages.value = mergedMessages;

    // 로컬에 저장
    _saveLocalMessages();
  }

  // 읽지 않은 메시지 수 계산
  void _updateUnreadCount() {
    final String currentUserId = _authService.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final int count = messages
        .where((m) => m.receiverId == currentUserId && !m.isRead)
        .length;

    unreadMessageCount.value = count;
    debugPrint('✅ 읽지 않은 메시지 수: $count');
  }

  // 새 메시지 전송
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      debugPrint('📤 메시지 전송 시작: 받는이=$receiverId, 타입=$messageType');

      final String currentUserId = _authService.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) {
        debugPrint('❌ 현재 로그인된 사용자가 없습니다. 테스트 ID 사용');
        // 테스트용 ID 생성
        final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('🔄 테스트 ID 생성: $testId');

        // 고유 ID 생성
        final String messageId = const Uuid().v4();

        // 메시지 객체 생성
        final Message message = Message(
          id: messageId,
          senderId: testId,
          receiverId: receiverId,
          content: content,
          timestamp: DateTime.now(),
          isRead: false,
          messageType: messageType,
        );

        // 메시지를 로컬 메시지 목록에 추가
        messages.insert(0, message);
        await _saveLocalMessages();

        debugPrint('✅ 테스트 사용자로 메시지 전송 완료: ${message.id}');
        isLoading.value = false;
        return true;
      }

      // 고유 ID 생성
      final String messageId = const Uuid().v4();

      // 메시지 객체 생성
      final Message message = Message(
        id: messageId,
        senderId: currentUserId,
        receiverId: receiverId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
        messageType: messageType,
      );

      debugPrint(
          '🔄 메시지 객체 생성: ID=${message.id}, 보낸이=${message.senderId}, 받는이=${message.receiverId}');

      // 메시지를 로컬 메시지 목록에 추가
      messages.insert(0, message);
      await _saveLocalMessages();

      // 온라인 상태라면 Firestore에도 저장 시도
      try {
        // Firestore 전송 시도
        debugPrint('📤 Firestore에 메시지 저장 시도: ${message.id}');
        await _firestore
            .collection('messages')
            .doc(messageId)
            .set(message.toJson());
        debugPrint('✅ 메시지가 Firestore에 저장되었습니다.');
      } catch (e) {
        // Firebase 권한 오류는 개발 중에는 무시 (로컬 저장이 성공했으므로)
        debugPrint('⚠️ Firestore 메시지 저장 실패 (오프라인 모드에서 나중에 동기화 예정): $e');

        // 실패 로그만 남기고 오류로 처리하지 않음
        if (e.toString().contains('permission-denied')) {
          debugPrint('🔒 Firebase 권한 오류: 개발 모드에서는 로컬 저장만 사용합니다.');
        }
      }

      isLoading.value = false;

      // 메시지 전송 후 대화 목록 확인
      final conversation = getConversationWith(receiverId);
      debugPrint('🔄 메시지 전송 후 대화 목록 확인: ${conversation.length}개 메시지 있음');

      return true;
    } catch (e) {
      debugPrint('⚠️ 메시지 전송 오류: $e');
      hasError.value = true;
      errorMessage.value = '메시지 전송 중 오류가 발생했습니다.';
      isLoading.value = false;
      return false;
    }
  }

  // 메시지 읽음 상태 변경
  Future<void> markMessageAsRead(String messageId) async {
    try {
      // 로컬 메시지 상태 업데이트
      final int index = messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final Message updatedMessage = messages[index].copyWith(isRead: true);
        messages[index] = updatedMessage;
        await _saveLocalMessages();
      }

      // Firestore 메시지 상태 업데이트
      try {
        await _firestore.collection('messages').doc(messageId).update({
          'isRead': true,
        });
        debugPrint('✅ 메시지 읽음 상태가 Firestore에 업데이트되었습니다.');
      } catch (e) {
        debugPrint('⚠️ Firestore 메시지 읽음 상태 업데이트 실패: $e');

        // 권한 오류는 개발 모드에서는 무시
        if (e.toString().contains('permission-denied')) {
          debugPrint('🔒 Firebase 권한 오류: 개발 모드에서는 로컬 저장만 사용합니다.');
        }
      }

      // 읽지 않은 메시지 수 업데이트
      _updateUnreadCount();
    } catch (e) {
      debugPrint('⚠️ 메시지 읽음 상태 변경 오류: $e');
    }
  }

  // 여러 메시지 읽음 상태로 변경
  Future<void> markMultipleMessagesAsRead(List<String> messageIds) async {
    try {
      // 로컬 메시지 상태 업데이트
      for (String id in messageIds) {
        final int index = messages.indexWhere((m) => m.id == id);
        if (index >= 0) {
          messages[index] = messages[index].copyWith(isRead: true);
        }
      }
      await _saveLocalMessages();

      // Firestore 메시지 상태 업데이트 (배치 작업)
      try {
        final batch = _firestore.batch();
        for (String id in messageIds) {
          final docRef = _firestore.collection('messages').doc(id);
          batch.update(docRef, {'isRead': true});
        }
        await batch.commit();
        debugPrint('✅ ${messageIds.length}개 메시지 읽음 상태가 Firestore에 업데이트되었습니다.');
      } catch (e) {
        debugPrint('⚠️ Firestore 다중 메시지 읽음 상태 업데이트 실패: $e');

        // 권한 오류는 개발 모드에서는 무시
        if (e.toString().contains('permission-denied')) {
          debugPrint('🔒 Firebase 권한 오류: 개발 모드에서는 로컬 저장만 사용합니다.');
        }
      }

      // 읽지 않은 메시지 수 업데이트
      _updateUnreadCount();
    } catch (e) {
      debugPrint('⚠️ 다중 메시지 읽음 상태 변경 오류: $e');
    }
  }

  // 특정 사용자와의 대화 가져오기
  List<Message> getConversationWith(String userId) {
    try {
      // 빈 ID 체크
      if (userId.isEmpty) {
        debugPrint('⚠️ 대화 상대 ID가 비어있습니다 - 빈 대화 반환');
        return [];
      }

      // 메시지 목록이 null이거나 비어있는 경우 빈 목록 반환
      if (messages == null || messages.isEmpty) {
        debugPrint('⚠️ 메시지 목록이 비어있습니다 - 빈 대화 반환');
        return [];
      }

      // 현재 사용자 ID (로그인 안 되어 있으면 공백)
      final String currentUserId = _authService.currentUser?.uid ?? '';

      // 로그 디버깅 (대화 상대 및 현재 사용자 확인)
      debugPrint('🔍 대화 가져오기: currentUser=$currentUserId, targetUser=$userId');
      debugPrint('📊 전체 메시지 수: ${messages.length}');

      // ID 값 디버깅을 위한 로그 (첫 번째 메시지만)
      if (messages.isNotEmpty) {
        try {
          final msg = messages.first;
          final idPreview = msg.id.isNotEmpty
              ? msg.id.substring(0, min(6, msg.id.length))
              : '빈ID';
          debugPrint(
              '📱 첫 번째 저장 메시지: ID=${idPreview}... | 보낸이=${msg.senderId} | 받는이=${msg.receiverId}');
        } catch (e) {
          debugPrint('⚠️ 첫 번째 메시지 로깅 중 오류: $e');
        }
      }

      List<Message> conversation = [];

      if (currentUserId.isEmpty) {
        debugPrint('⚠️ 현재 로그인된 사용자가 없습니다 - 테스트 모드 사용');

        // 테스트 모드: 지금까지 생성된 모든 test- ID 포함
        final testIds = <String>[];

        // 메시지에서 test- 패턴의 ID 수집
        for (var m in messages) {
          try {
            if (m.senderId.startsWith('test-')) {
              testIds.add(m.senderId);
            }
            if (m.receiverId.startsWith('test-')) {
              testIds.add(m.receiverId);
            }
          } catch (e) {
            debugPrint('⚠️ 테스트 ID 수집 중 오류: $e');
          }
        }

        // 중복 제거 및 로깅
        final uniqueTestIds = testIds.toSet();
        debugPrint('🔍 발견된 테스트 ID: ${uniqueTestIds.join(', ')}');

        // 테스트 ID와 target ID 사이의 모든 메시지 포함
        try {
          conversation = messages
              .where((m) =>
                  // 테스트 ID가 발신자이고 target이 수신자
                  (uniqueTestIds.contains(m.senderId) &&
                      m.receiverId == userId) ||
                  // target이 발신자이고 테스트 ID가 수신자
                  (m.senderId == userId &&
                      uniqueTestIds.contains(m.receiverId)))
              .toList();
        } catch (e) {
          debugPrint('⚠️ 테스트 모드에서 대화 필터링 중 오류: $e');
          conversation = [];
        }
      } else {
        // 정상 모드: 현재 사용자와 target 사이 메시지만 포함
        try {
          conversation = messages
              .where((m) =>
                  (m.senderId == currentUserId && m.receiverId == userId) ||
                  (m.receiverId == currentUserId && m.senderId == userId))
              .toList();
        } catch (e) {
          debugPrint('⚠️ 정상 모드에서 대화 필터링 중 오류: $e');
          conversation = [];
        }
      }

      // 시간 순으로 정렬 (오래된 메시지가 위로)
      try {
        conversation.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      } catch (e) {
        debugPrint('⚠️ 대화 정렬 중 오류: $e');
      }

      debugPrint('📱 사용자 $userId와의 대화 ${conversation.length}개 메시지 찾음');

      // 디버깅: 처음 몇 개 메시지 출력
      if (conversation.isNotEmpty) {
        try {
          final msg = conversation.first;
          final idPreview = msg.id.isNotEmpty
              ? msg.id.substring(0, min(6, msg.id.length))
              : '빈ID';
          final contentPreview = msg.content.length > 20
              ? msg.content.substring(0, 20) + "..."
              : msg.content;
          debugPrint(
              '📱 첫 번째 메시지: ID=${idPreview}... | 보낸이=${msg.senderId} | 받는이=${msg.receiverId} | 내용=$contentPreview');
        } catch (e) {
          debugPrint('⚠️ 첫 번째 대화 메시지 로깅 중 오류: $e');
        }
      } else {
        debugPrint('⚠️ 대화가 비어있습니다. 필터링 기준 확인 필요');
      }

      return conversation;
    } catch (e) {
      debugPrint('⚠️ 특정 사용자와의 대화 가져오기 오류: $e');
      return [];
    }
  }

  // 대화 목록 가져오기 (각 사용자별 마지막 메시지)
  List<Message> getConversationList() {
    try {
      final String? currentUserId = _authService.currentUser?.uid ?? '';
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 현재 로그인된 사용자가 없습니다 - 빈 대화 목록 반환');
        return [];
      }

      // 현재 사용자가 참여한 모든 메시지
      final userMessages = messages
          .where((m) =>
              m.senderId == currentUserId || m.receiverId == currentUserId)
          .toList();

      // 대화 상대 ID 목록
      final Set<String> conversationUserIds = {};
      for (var message in userMessages) {
        if (message.senderId == currentUserId) {
          conversationUserIds.add(message.receiverId);
        } else {
          conversationUserIds.add(message.senderId);
        }
      }

      // 각 대화 상대별 최신 메시지 찾기
      final List<Message> conversationList = [];
      for (String userId in conversationUserIds) {
        final userConversation = userMessages
            .where((m) =>
                (m.senderId == currentUserId && m.receiverId == userId) ||
                (m.receiverId == currentUserId && m.senderId == userId))
            .toList();

        if (userConversation.isNotEmpty) {
          // 시간순 정렬 후 첫 번째 메시지 (가장 최신)
          userConversation.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          conversationList.add(userConversation.first);
        }
      }

      // 시간순 정렬
      conversationList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return conversationList;
    } catch (e) {
      debugPrint('⚠️ 대화 목록 가져오기 오류: $e');
      return [];
    }
  }

  // 위치 공유 요청 메시지 보내기
  Future<bool> sendLocationRequest({
    required String receiverId,
    String message = '위치를 공유해 주세요.',
  }) async {
    try {
      // 위치 공유 요청 메시지 전송
      final result = await sendMessage(
        receiverId: receiverId,
        content: message,
        messageType: 'location_request',
      );
      return result;
    } catch (e) {
      debugPrint('⚠️ 위치 공유 요청 전송 오류: $e');
      return false;
    }
  }

  // 위치 공유 메시지 보내기
  Future<bool> sendLocationShare({
    required String receiverId,
    required double latitude,
    required double longitude,
    String message = '제 현재 위치입니다.',
  }) async {
    try {
      final String locationData = jsonEncode(
          {'latitude': latitude, 'longitude': longitude, 'message': message});

      return sendMessage(
        receiverId: receiverId,
        content: locationData,
        messageType: 'location_share',
      );
    } catch (e) {
      debugPrint('⚠️ 위치 공유 메시지 전송 오류: $e');
      return false;
    }
  }
}
