import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';

class MessageDetailView extends StatefulWidget {
  final String userId; // 대화 상대 ID

  const MessageDetailView({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<MessageDetailView> createState() => _MessageDetailViewState();
}

class _MessageDetailViewState extends State<MessageDetailView> {
  final MessageService _messageService = Get.find<MessageService>();
  final AuthService _authService = Get.find<AuthService>();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 화면이 로드되면 읽지 않은 메시지를 읽음 상태로 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (mounted) {
          _markMessagesAsRead();
          _scrollToBottom();
        }
      } catch (e) {
        debugPrint('⚠️ 초기화 중 오류 발생: $e');
      }
    });
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 컨트롤러 정리
    _messageController.dispose();
    _scrollController.dispose();

    // 여기서 상태 업데이트 시도 금지
    // _messageService나 _authService에 접근하지 않음

    super.dispose();
  }

  // 메시지 전송
  Future<void> _sendMessage() async {
    if (!mounted) return; // mounted 체크 추가

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 임시 디버그 메시지
    debugPrint('🔄 메시지 전송 시도: $text');
    debugPrint('👤 현재 사용자 UID: ${_authService.uid}');
    debugPrint('👥 수신자 ID: ${widget.userId}');

    // 로그인되지 않은 경우 테스트 로그인 시도 (개발용)
    if (_authService.uid == null || _authService.uid!.isEmpty) {
      debugPrint('⚠️ 로그인되지 않음 - 테스트 계정으로 자동 로그인 시도');
      await _authService.login('test@example.com', 'Password1!');
      if (!mounted) return; // 비동기 작업 후 mounted 체크
      debugPrint('✅ 테스트 로그인 완료, 새 UID: ${_authService.uid}');
    }

    final success = await _messageService.sendMessage(
      receiverId: widget.userId,
      content: text,
    );

    if (!mounted) return; // 비동기 작업 후 mounted 체크

    debugPrint(success ? '✅ 메시지 전송 성공' : '❌ 메시지 전송 실패');

    if (success) {
      _messageController.clear();

      // 스크롤을 맨 아래로 이동
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // mounted 체크 추가
          _scrollToBottom();
        }
      });
    } else {
      // 전송 실패 시 사용자에게 알림
      if (mounted) {
        // mounted 체크 추가
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지 전송에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 위치 공유 요청 보내기
  Future<void> _sendLocationRequest() async {
    if (!mounted) return; // mounted 체크 추가

    // 로그인되지 않은 경우 테스트 로그인 시도 (개발용)
    if (_authService.uid == null || _authService.uid!.isEmpty) {
      debugPrint('⚠️ 로그인되지 않음 - 테스트 계정으로 자동 로그인 시도');
      await _authService.login('test@example.com', 'Password1!');
      if (!mounted) return; // 비동기 작업 후 mounted 체크
      debugPrint('✅ 테스트 로그인 완료, 새 UID: ${_authService.uid}');
    }

    final success = await _messageService.sendLocationRequest(
      receiverId: widget.userId,
    );

    if (!mounted) return; // 비동기 작업 후 mounted 체크

    if (!success) {
      // 전송 실패 시 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 공유 요청 전송에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 읽지 않은 메시지를 읽음 상태로 변경
  Future<void> _markMessagesAsRead() async {
    if (!mounted) return; // mounted 체크 추가

    final conversation = _messageService.getConversationWith(widget.userId);
    final currentUserId = _authService.uid;

    if (currentUserId == null) return;

    // 읽지 않은 메시지만 필터링 (수신한 메시지만)
    final unreadMessageIds = conversation
        .where((m) => !m.isRead && m.receiverId == currentUserId)
        .map((m) => m.id)
        .toList();

    if (unreadMessageIds.isNotEmpty) {
      await _messageService.markMultipleMessagesAsRead(unreadMessageIds);
      // 비동기 작업 후 mounted 체크는 필요 없음 - 결과를 사용하지 않음
    }
  }

  // 날짜 형식화
  String _formatMessageTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  // 위치 메시지 파싱
  Map<String, dynamic>? _parseLocationMessage(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // 상대방 이름 가져오기 (테스트용)
  String _getRecipientName(String userId) {
    // 실제 서비스에서는 사용자 프로필 서비스에서 이름을 가져와야 합니다
    // 여기서는 테스트용으로 ID의 마지막 4자리를 사용합니다
    if (userId.startsWith('test-')) {
      final shortId =
          userId.length > 5 ? userId.substring(userId.length - 4) : userId;
      return '테스트유저 $shortId';
    } else if (userId == 'admin') {
      return '관리자';
    } else if (userId == _authService.uid) {
      return '나';
    } else {
      // ID의 마지막 4자리를 사용한 이름 생성
      final shortId =
          userId.length > 4 ? userId.substring(userId.length - 4) : userId;
      return '사용자 $shortId';
    }
  }

  // 안전하게 스크롤을 맨 아래로 이동하는 메서드
  void _scrollToBottom() {
    try {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('⚠️ 스크롤 이동 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getRecipientName(widget.userId)),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _sendLocationRequest,
            tooltip: '위치 공유 요청',
          ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: Obx(() {
              final conversation =
                  _messageService.getConversationWith(widget.userId);

              if (conversation.isEmpty) {
                return const Center(
                  child: Text('대화를 시작해보세요!'),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: conversation.length,
                itemBuilder: (context, index) {
                  if (index >= conversation.length) {
                    // 인덱스 범위 체크
                    return const SizedBox.shrink();
                  }

                  final message = conversation[index];
                  if (message == null) {
                    return const SizedBox.shrink();
                  }

                  // AuthService UID null 체크
                  final String? currentUserUid = _authService.uid;
                  final isCurrentUserSender = currentUserUid != null &&
                      message.senderId == currentUserUid;

                  Widget messageContent;

                  if (message.messageType == 'text') {
                    // 일반 텍스트 메시지
                    messageContent = Text(
                      message.content,
                      style: TextStyle(
                        color:
                            isCurrentUserSender ? Colors.white : Colors.black,
                      ),
                    );
                  } else if (message.messageType == 'location_request') {
                    // 위치 공유 요청
                    messageContent = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_searching, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isCurrentUserSender
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    );
                  } else if (message.messageType == 'location_share') {
                    // 위치 공유
                    final locationData = _parseLocationMessage(message.content);

                    if (locationData != null) {
                      messageContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                locationData['message'] ?? '위치가 공유되었습니다',
                                style: TextStyle(
                                  color: isCurrentUserSender
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '좌표: ${locationData['latitude']}, ${locationData['longitude']}',
                            style: TextStyle(
                              color: isCurrentUserSender
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    } else {
                      messageContent = const Text('잘못된 위치 데이터');
                    }
                  } else {
                    // 기타 메시지 타입
                    messageContent = Text(
                      message.content,
                      style: TextStyle(
                        color:
                            isCurrentUserSender ? Colors.white : Colors.black,
                      ),
                    );
                  }

                  return Align(
                    alignment: isCurrentUserSender
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentUserSender
                            ? Colors.blue
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          messageContent,
                          const SizedBox(height: 4),
                          Text(
                            _formatMessageTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isCurrentUserSender
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // 메시지 입력 영역
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
