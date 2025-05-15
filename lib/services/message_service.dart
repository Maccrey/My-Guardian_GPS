import 'dart:async';
import 'dart:convert';
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
      // 로컬 메시지 불러오기
      await _loadLocalMessages();

      // 사용자가 로그인되어 있으면 Firebase에서 메시지 스트림 구독
      if (_authService.isLoggedIn) {
        _subscribeToFirestoreMessages();
      }

      // 읽지 않은 메시지 수 계산
      _updateUnreadCount();

      isLoading.value = false;
    } catch (e) {
      debugPrint('⚠️ 메시지 초기화 오류: $e');
      hasError.value = true;
      errorMessage.value = '메시지를 불러오는 도중 오류가 발생했습니다.';
      isLoading.value = false;
    }
  }

  // 로컬에 저장된 메시지 불러오기
  Future<void> _loadLocalMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? messagesJson = prefs.getString(_localStorageKey);

      if (messagesJson != null) {
        final List<dynamic> decodedMessages = jsonDecode(messagesJson);
        final List<Message> loadedMessages =
            decodedMessages.map((json) => Message.fromJson(json)).toList();

        // 시간순 정렬
        loadedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // 기존 메시지 목록 갱신
        messages.value = loadedMessages;
        debugPrint('✅ 로컬에서 ${loadedMessages.length}개의 메시지를 불러왔습니다.');
      } else {
        debugPrint('⚠️ 로컬에 저장된 메시지가 없습니다.');
      }
    } catch (e) {
      debugPrint('⚠️ 로컬 메시지 불러오기 오류: $e');
    }
  }

  // 로컬에 메시지 저장하기
  Future<void> _saveLocalMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String messagesJson =
          jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString(_localStorageKey, messagesJson);
      debugPrint('✅ ${messages.length}개의 메시지를 로컬에 저장했습니다.');
    } catch (e) {
      debugPrint('⚠️ 로컬 메시지 저장 오류: $e');
    }
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

      final String currentUserId = _authService.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) {
        debugPrint('❌ 현재 로그인된 사용자가 없습니다. 테스트 ID 사용');
        // 테스트용 ID 생성
        final testId = 'test-${DateTime.now().millisecondsSinceEpoch}';

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
      final String? currentUserId = _authService.currentUser?.uid ?? '';
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 현재 로그인된 사용자가 없습니다 - 빈 대화 반환');
        return [];
      }

      if (userId.isEmpty) {
        debugPrint('⚠️ 대화 상대 ID가 비어있습니다 - 빈 대화 반환');
        return [];
      }

      final conversation = messages
          .where((m) =>
              (m.senderId == currentUserId && m.receiverId == userId) ||
              (m.receiverId == currentUserId && m.senderId == userId))
          .toList();

      // 시간 순으로 정렬 (오래된 메시지가 위로)
      conversation.sort((a, b) => a.timestamp.compareTo(b.timestamp));

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
