import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';
import 'message_detail_view.dart';
import 'dart:convert';

class MessagesListView extends StatefulWidget {
  const MessagesListView({Key? key}) : super(key: key);

  @override
  State<MessagesListView> createState() => _MessagesListViewState();
}

class _MessagesListViewState extends State<MessagesListView> {
  final MessageService _messageService = Get.find<MessageService>();
  final AuthService _authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();
    // 메시지 목록 화면에 들어왔을 때 자동으로 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshMessages();

        // 화면에 진입할 때 읽지 않은 메시지 수 업데이트
        _messageService.updateUnreadCount();
      }
    });
  }

  @override
  void dispose() {
    // 여기서 상태 업데이트 시도 금지
    super.dispose();
  }

  // 메시지 새로고침
  Future<void> _refreshMessages() async {
    if (!mounted) return;

    debugPrint('🔄 메시지 목록 새로고침');

    // 명시적으로 상태 업데이트
    setState(() {
      // 새로고침 상태 표시
    });

    // 현재 로그인 상태 확인
    final currentUserId = _authService.uid;
    debugPrint('👤 현재 사용자 ID: $currentUserId');

    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('⚠️ 로그인되어 있지 않음 - 테스트 계정으로 자동 로그인 시도');
      await _authService.login('test@example.com', 'Password1!');
    }

    // Firebase에서 데이터 다시 로드
    try {
      await _messageService.refreshMessages();

      // 새로고침 후 상태 제대로 확인
      if (_messageService.hasError.value) {
        debugPrint('⚠️ 메시지 새로고침 오류: ${_messageService.errorMessage.value}');

        if (mounted) {
          Get.snackbar(
            '메시지 새로고침 중 오류',
            _messageService.errorMessage.value,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        debugPrint('✅ 메시지 새로고침 성공: ${_messageService.messages.length}개 메시지');

        // 메시지 목록 화면이 열렸을 때 모든 읽지 않은 메시지를 읽음 처리
        _markAllMessagesAsRead();

        if (mounted && _messageService.messages.isEmpty) {
          Get.snackbar(
            '메시지 없음',
            '메시지가 없습니다. 새 대화를 시작해보세요.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.withOpacity(0.7),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 새로고침 오류: $e');

      if (mounted) {
        Get.snackbar(
          '오류',
          '메시지 새로고침 중 문제가 발생했습니다: ${e.toString().split('\n').first}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    }

    // 상태 갱신
    if (mounted) {
      setState(() {
        // 대화 목록 새로고침
      });
    }
  }

  // 모든 읽지 않은 메시지를 읽음 처리
  Future<void> _markAllMessagesAsRead() async {
    if (!mounted) return;

    try {
      final currentUserId = _authService.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 로그인되어 있지 않아 읽음 처리를 중단합니다.');
        return;
      }

      // 읽지 않은 모든 메시지 ID 찾기 (내가 받은 메시지만)
      final unreadMessageIds = _messageService.messages
          .where((m) => !m.isRead && m.receiverId == currentUserId)
          .map((m) => m.id)
          .toList();

      if (unreadMessageIds.isEmpty) {
        debugPrint('✅ 읽지 않은 메시지가 없습니다.');
        return;
      }

      debugPrint('🔄 메시지 목록 화면에서 ${unreadMessageIds.length}개의 메시지를 읽음 처리합니다.');

      // 읽음 처리
      await _messageService.markMultipleMessagesAsRead(unreadMessageIds);

      // 메시지 목록 갱신 및 읽지 않은 메시지 수 업데이트
      _messageService.messages.refresh();
      _messageService.updateUnreadCount();

      debugPrint('✅ 모든 메시지 읽음 처리 완료');

      // 지연 후 한번 더 업데이트 (UI 갱신이 확실하게 되도록)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _messageService.updateUnreadCount();
          setState(() {});
          debugPrint('🔄 지연 업데이트 완료');
        }
      });
    } catch (e) {
      debugPrint('⚠️ 메시지 일괄 읽음 처리 중 오류: $e');
    }
  }

  // 날짜 형식화 함수
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // 오늘인 경우 시간만 표시
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      // 어제인 경우
      return '어제';
    } else if (difference.inDays < 7) {
      // 일주일 내인 경우 요일 표시
      return DateFormat('E', 'ko_KR').format(date);
    } else {
      // 그외 경우 날짜 표시
      return DateFormat('MM/dd').format(date);
    }
  }

  // 상대방 이름 가져오기 (Firebase에서 실제 정보를 가져오도록 개선)
  String _getRecipientName(String userId) {
    // 자신인 경우 즉시 '나'로 반환
    if (userId == _authService.uid) {
      return '나';
    }

    // 특수 케이스 빠른 처리
    if (userId == 'admin') {
      return '관리자';
    }

    if (userId.isEmpty) {
      return '알 수 없음';
    }

    // 1. 메시지 서비스의 검색 결과에서 사용자 먼저 찾기
    try {
      final foundUsers = _messageService.searchResults
          .where((user) => user.uid == userId)
          .toList();

      if (foundUsers.isNotEmpty) {
        final user = foundUsers.first;

        // 닉네임 우선 사용
        if (user.nickname != null && user.nickname!.isNotEmpty) {
          return user.nickname!;
        }

        // 이메일이 있으면 사용자 이름 부분 추출
        if (user.email != null && user.email!.isNotEmpty) {
          return user.email!.split('@')[0];
        }
      }

      // 2. 검색 결과에 없는 경우는 Firebase에서 조회 시도
      if (mounted) {
        // findUserById를 호출하여 Firebase에서 사용자 정보 조회
        _messageService.findUserById(userId).then((user) {
          if (user != null && mounted) {
            // 상태 업데이트가 필요하므로 setState 호출
            setState(() {});
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ 사용자 정보 검색 처리 중 오류: $e');
    }

    // ID 접두어 처리하여 사람이 읽기 쉬운 형식으로 변환
    // 임시 표시 (Firebase에서 정보를 가져오는 동안 사용)

    // fixed- 접두사 제거
    if (userId.startsWith('fixed-')) {
      final cleanId = userId.replaceAll('fixed-', '');
      // user- 접두사도 제거
      final finalId = cleanId.replaceAll('user-', '');

      // 숫자로만 구성된 ID인 경우 '사용자'와 함께 표시
      if (finalId.contains(RegExp(r'^[0-9]+$'))) {
        return '사용자 $finalId';
      }

      // 이메일 형식이면 @ 앞부분만 표시
      if (finalId.contains('@')) {
        return finalId.split('@')[0];
      }

      // 그 외의 경우 첫 글자 대문자로 변환
      return finalId.capitalize ?? finalId;
    }

    // real- 접두사 제거
    if (userId.startsWith('real-')) {
      final cleanId = userId.replaceAll('real-', '');
      if (cleanId.contains('@')) {
        return cleanId.split('@')[0];
      }
      return cleanId.capitalize ?? cleanId;
    }

    // test- 접두사 제거
    if (userId.startsWith('test-')) {
      final cleanId = userId.replaceAll('test-', '');
      return '테스트 $cleanId';
    }

    // 이메일 형식이면 @ 앞부분만 표시
    if (userId.contains('@')) {
      return userId.split('@')[0];
    }

    // 마지막 대안: ID에서 불필요한 숫자나 기호 제거 후 보기 좋게 변환
    final cleanUserId = userId.replaceAll(RegExp(r'[0-9-_]+$'), '');
    return cleanUserId.isNotEmpty
        ? (cleanUserId.capitalize ?? cleanUserId)
        : userId;
  }

  // 메시지 미리보기 텍스트 만들기
  String _getPreviewText(Message message) {
    if (message.messageType == 'text') {
      // 일반 텍스트 메시지
      return message.content;
    } else if (message.messageType == 'location_request') {
      // 위치 공유 요청
      return '위치 공유 요청을 보냈습니다';
    } else if (message.messageType == 'location_share') {
      // 위치 공유
      try {
        // 위치 메시지 파싱 시도
        final locationData =
            jsonDecode(message.content) as Map<String, dynamic>;
        final customMessage = locationData['message'] as String?;

        if (customMessage != null && customMessage.isNotEmpty) {
          // 위치와 함께 보낸 메시지가 있으면 표시
          if (customMessage == '제 현재 위치입니다.') {
            return '📍 현재 위치를 공유했습니다';
          }
          return '📍 $customMessage';
        }
        return '📍 위치를 공유했습니다';
      } catch (e) {
        // 파싱 실패 시 기본 메시지
        return '📍 위치를 공유했습니다';
      }
    } else if (message.messageType == 'arrival_notification' ||
        message.messageType == 'location_arrival') {
      // 귀가 알림
      try {
        // 귀가 알림 메시지 파싱 시도
        final arrivalData = jsonDecode(message.content) as Map<String, dynamic>;
        final customMessage = arrivalData['message'] as String?;
        final locationName = arrivalData['name'] as String?;

        if (customMessage != null && customMessage.isNotEmpty) {
          if (locationName != null && locationName.isNotEmpty) {
            return '🏠 $locationName: $customMessage';
          }
          return '🏠 $customMessage';
        }
        return '🏠 안전하게 귀가했습니다';
      } catch (e) {
        // 파싱 실패 시 기본 메시지
        return '🏠 귀가 알림이 도착했습니다';
      }
    } else {
      // 기타 메시지 타입
      return message.content;
    }
  }

  // 특정 사용자와의 대화에서 읽지 않은 메시지 확인
  bool _hasUnreadMessages(String userId) {
    try {
      final currentUserId = _authService.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return false;
      }

      // 현재 사용자와 상대방 사이의 모든 메시지 가져오기
      final conversation = _messageService.getConversationWith(userId);

      // 읽지 않은 메시지 확인 (내가 받은 메시지 중에서)
      final hasUnread = conversation.any((m) =>
          !m.isRead &&
          m.receiverId == currentUserId &&
          m.senderId != currentUserId);

      return hasUnread;
    } catch (e) {
      debugPrint('⚠️ 읽지 않은 메시지 확인 오류: $e');
      return false;
    }
  }

  // 읽지 않은 메시지 수 가져오기
  int _getUnreadCount(String userId) {
    try {
      final currentUserId = _authService.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return 0;
      }

      // 현재 사용자와 상대방 사이의 모든 메시지 가져오기
      final conversation = _messageService.getConversationWith(userId);

      // 읽지 않은 메시지 수 (내가 받은 메시지 중에서)
      final unreadCount = conversation
          .where((m) =>
              !m.isRead &&
              m.receiverId == currentUserId &&
              m.senderId != currentUserId)
          .length;

      return unreadCount;
    } catch (e) {
      debugPrint('⚠️ 읽지 않은 메시지 수 확인 오류: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        title: const Text(
          '메시지',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.blue.shade700,
            onPressed: _refreshMessages,
            tooltip: '메시지 새로고침',
          ),
          // 테스트 계정 버튼 추가
          IconButton(
            icon: const Icon(Icons.person_add),
            color: Colors.green.shade600,
            onPressed: _showUserSearchDialog,
            tooltip: '대화 상대 검색',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUserSearchDialog,
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
        child: const Icon(Icons.edit),
      ),
      body: Builder(
        builder: (context) {
          if (_messageService.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '메시지를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (_messageService.hasError.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${_messageService.errorMessage.value}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refreshMessages,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '※ 오류가 계속되면 앱을 다시 시작하거나 설정을 확인해주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _showUserSearchDialog,
                    icon: const Icon(Icons.search),
                    label: const Text('대화 상대 검색하기'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          // 대화 목록 가져오기
          final conversations = _messageService.getConversationList();
          if (conversations.isEmpty) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                image: DecorationImage(
                  image: const NetworkImage(
                    'https://i.pinimg.com/originals/97/c0/07/97c00759d90d786d9b6096d274ad3e07.png',
                  ),
                  opacity: 0.07,
                  repeat: ImageRepeat.repeat,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 80,
                      color: Colors.blue.shade200,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '메시지가 없습니다',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        '위치 공유 요청이나 메시지를 보내면\n여기에 표시됩니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _showUserSearchDialog,
                      icon: const Icon(Icons.search),
                      label: const Text('대화 상대 검색'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              image: DecorationImage(
                image: const NetworkImage(
                  'https://i.pinimg.com/originals/97/c0/07/97c00759d90d786d9b6096d274ad3e07.png',
                ),
                opacity: 0.07,
                repeat: ImageRepeat.repeat,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _refreshMessages,
              color: Colors.blue.shade700,
              child: ListView.separated(
                itemCount: conversations.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey.shade300,
                  indent: 80,
                ),
                itemBuilder: (context, index) {
                  if (index >= conversations.length) {
                    // 인덱스 범위 체크
                    return const SizedBox.shrink();
                  }

                  final message = conversations[index];
                  // null 체크
                  if (message == null) {
                    return const SizedBox.shrink();
                  }

                  // AuthService UID null 체크
                  final String? currentUserUid = _authService.uid;
                  final isCurrentUserSender = currentUserUid != null &&
                      (message.senderId == currentUserUid ||
                          message.senderId.startsWith('test-') ||
                          message.senderId.startsWith('fixed-'));

                  // 대화 상대 ID - 수정: dynamic ID 처리 개선
                  final String otherUserId = isCurrentUserSender
                      ? message.receiverId
                      : message.senderId;

                  // 대화 상대 이름
                  final otherUserName = _getRecipientName(otherUserId);

                  // 메시지 타입에 따른 아이콘 및 색상 결정
                  IconData? messageTypeIcon;
                  Color? messageTypeColor;

                  if (message.messageType == 'location_share') {
                    messageTypeIcon = Icons.location_on;
                    messageTypeColor = Colors.teal.shade600;
                  } else if (message.messageType == 'location_request') {
                    messageTypeIcon = Icons.location_searching;
                    messageTypeColor = Colors.blue.shade600;
                  }

                  return Dismissible(
                    key: Key('conversation-${message.id}'),
                    background: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('대화 삭제'),
                            content: Text('$otherUserName님과의 대화를 삭제하시겠습니까?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('삭제'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) async {
                      // 대화 삭제 기능 구현
                      try {
                        // 해당 대화에 속한 모든 메시지 삭제
                        final conversation =
                            _messageService.getConversationWith(otherUserId);

                        // 메시지가 있으면 모두 삭제
                        if (conversation.isNotEmpty) {
                          for (var msg in conversation) {
                            await _messageService.deleteMessage(msg.id);
                          }
                          debugPrint('✅ ${conversation.length}개 메시지가 삭제되었습니다.');
                        }

                        Get.snackbar(
                          '대화 삭제',
                          '$otherUserName님과의 대화가 삭제되었습니다',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.grey.shade800,
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(12),
                          borderRadius: 10,
                        );

                        // 데이터 변경 후 메시지 목록을 갱신하기 위해 인위적으로 새로고침
                        _refreshMessages();
                      } catch (e) {
                        debugPrint('⚠️ 대화 삭제 오류: $e');
                        Get.snackbar(
                          '오류',
                          '대화 삭제 중 오류가 발생했습니다',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.shade400,
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(12),
                          borderRadius: 10,
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: _hasUnreadMessages(otherUserId)
                            ? Colors.blue.shade50
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: _hasUnreadMessages(otherUserId)
                            ? Border.all(color: Colors.blue.shade200, width: 1)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            otherUserName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherUserName,
                                style: TextStyle(
                                  fontWeight: _hasUnreadMessages(otherUserId)
                                      ? FontWeight.w800
                                      : FontWeight.bold,
                                  fontSize: 16,
                                  color: _hasUnreadMessages(otherUserId)
                                      ? Colors.blue.shade800
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(message.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            // 메시지 타입 아이콘 추가
                            if (messageTypeIcon != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  messageTypeIcon,
                                  size: 14,
                                  color: messageTypeColor,
                                ),
                              ),

                            // 내가 보낸 메시지인 경우 '나: '를 붙임
                            if (isCurrentUserSender)
                              Text(
                                '나: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),

                            Expanded(
                              child: Text(
                                _getPreviewText(message),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            // 읽지 않은 메시지 표시
                            if (_hasUnreadMessages(otherUserId) &&
                                !isCurrentUserSender)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_getUnreadCount(otherUserId)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          // 메시지 상세 화면으로 이동
                          if (!mounted) return; // mounted 체크

                          try {
                            // 대화 상대 ID가 dynamic으로 시작하면 고정 ID로 변환
                            String targetUserId = otherUserId;
                            if (targetUserId.startsWith('dynamic-')) {
                              targetUserId = 'fixed-user-1';
                              debugPrint(
                                  '⚠️ dynamic ID를 고정 ID로 변환: $targetUserId');
                            }

                            Get.to(
                              () => MessageDetailView(userId: targetUserId),
                              transition: Transition.rightToLeft,
                              duration: const Duration(milliseconds: 300),
                            );
                          } catch (e) {
                            debugPrint('⚠️ 메시지 상세 화면으로 이동 중 오류: $e');
                            if (mounted) {
                              Get.snackbar(
                                '오류',
                                '메시지 상세 화면을 열 수 없습니다',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: Colors.red.shade400,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(12),
                                borderRadius: 10,
                              );
                            }
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // 사용자 검색 다이얼로그
  void _showUserSearchDialog() {
    final searchController = TextEditingController();
    final scrollController = ScrollController();

    // 다이얼로그가 닫힐 때 컨트롤러를 dispose하기 위한 플래그
    bool isDialogActive = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '대화 상대 검색',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.grey.shade600,
                  onPressed: () {
                    isDialogActive = false;
                    searchController.dispose();
                    scrollController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9, // 화면 너비의 90%로 고정
              height: 500, // 고정 높이 설정 (적당한 크기)
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7, // 최대 높이 제한
                maxWidth: 400, // 최대 너비 제한
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 검색 입력 필드
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '이메일 또는 닉네임 검색',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.blue.shade600,
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                color: Colors.grey.shade600,
                                onPressed: () {
                                  searchController.clear();
                                  _messageService.searchResults.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // 지우기 버튼 상태 업데이트

                        if (value.length >= 2) {
                          // 검색 실행
                          _messageService.searchUsers(value);
                        } else if (value.isEmpty) {
                          // 검색 결과 초기화
                          _messageService.searchResults.clear();
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  // 구분선 추가
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  // 결과 목록 (스크롤 가능)
                  Expanded(
                    child: Obx(() {
                      if (_messageService.isSearching.value) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  color: Colors.blue.shade600,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '검색 중...',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '사용자 정보를 찾고 있습니다',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final results = _messageService.searchResults;
                      if (results.isEmpty) {
                        // 결과가 없을 때 스크롤 가능한 상태 유지
                        return SingleChildScrollView(
                          controller: scrollController,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: searchController.text.length >= 2
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 60,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '\'${searchController.text}\'에 대한\n검색 결과가 없습니다.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '다른 검색어로 시도해보세요',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search,
                                        size: 60,
                                        color: Colors.blue.shade200,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '이메일이나 닉네임을 입력하여\n대화 상대를 검색해보세요.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '최소 2글자 이상 입력하세요',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      }

                      return Scrollbar(
                        controller: scrollController,
                        thickness: 6, // 스크롤바 두께
                        radius: const Radius.circular(10), // 스크롤바 모서리 둥글게
                        thumbVisibility: true, // 스크롤바 항상 표시
                        child: ListView.separated(
                          controller: scrollController,
                          shrinkWrap: false, // 스크롤 가능하도록 설정
                          physics:
                              const AlwaysScrollableScrollPhysics(), // 항상 스크롤 가능
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final user = results[index];
                            String displayName = user.nickname ?? '이름 없음';
                            String firstLetter =
                                displayName.isNotEmpty ? displayName[0] : '?';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              leading: user.profileImageUrl != null
                                  ? CircleAvatar(
                                      backgroundImage:
                                          NetworkImage(user.profileImageUrl!),
                                      backgroundColor: Colors.grey.shade200,
                                      onBackgroundImageError: (_, __) {
                                        // 이미지 로드 오류 시 기본 이니셜 표시
                                      },
                                      child: user.profileImageUrl != null
                                          ? null
                                          : Text(firstLetter),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        firstLetter.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                user.email ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              onTap: () {
                                // 컨트롤러 dispose 후 다이얼로그 닫기
                                isDialogActive = false;
                                searchController.dispose();
                                scrollController.dispose();
                                Navigator.of(context).pop();
                                _startNewConversation(user);
                              },
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '대화하기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hoverColor: Colors.blue.shade50,
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).then((_) {
      // 다이얼로그가 닫히면 컨트롤러 dispose
      if (isDialogActive) {
        searchController.dispose();
        scrollController.dispose();
      }
    });
  }

  // 새 대화 시작
  void _startNewConversation(final user) {
    if (user.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 ID가 없어 대화를 시작할 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Get.to(() => MessageDetailView(userId: user.uid));
  }

  // 새 메시지 다이얼로그 표시
  void _showNewMessageDialog() {
    if (!mounted) return;

    final TextEditingController receiverIdController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    // 임의의 테스트 수신자 ID 생성
    receiverIdController.text =
        'test-${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 메시지 보내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiverIdController,
              decoration: const InputDecoration(
                labelText: '수신자 ID',
                hintText: '메시지를 받을 사용자 ID를 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: '메시지 내용',
                hintText: '보낼 메시지를 입력하세요',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final receiverId = receiverIdController.text.trim();
              final message = messageController.text.trim();

              if (receiverId.isEmpty || message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('수신자 ID와 메시지를 모두 입력해주세요')),
                );
                return;
              }

              // 창 닫기
              Navigator.of(context).pop();

              // 로그인되지 않은 경우 테스트 로그인 시도 (개발용)
              if (_authService.uid == null || _authService.uid!.isEmpty) {
                debugPrint('⚠️ 로그인되지 않음 - 테스트 계정으로 자동 로그인 시도');
                await _authService.login('test@example.com', 'Password1!');
                if (!mounted) return; // 비동기 작업 후 mounted 체크
                debugPrint('✅ 테스트 로그인 완료, 새 UID: ${_authService.uid}');
              }

              // 메시지 전송
              final success = await _messageService.sendMessage(
                receiverId: receiverId,
                content: message,
              );

              if (!mounted) return; // 비동기 작업 후 mounted 체크

              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('메시지 전송에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('메시지가 전송되었습니다'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('보내기'),
          ),
        ],
      ),
    );
  }
}
