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

  // 스캐폴드 키를 저장할 변수 - dispose에서 안전하게 액세스하기 위함
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();

    // 로깅 추가
    debugPrint('🔄 MessageDetailView initState 시작: ${widget.userId}');

    // 화면이 로드되면 읽지 않은 메시지를 읽음 상태로 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 위젯 생성 직후에만 실행되도록 보장
      if (!mounted) {
        debugPrint('⚠️ 위젯이 이미 dispose되어 초기화를 중단합니다.');
        return;
      }

      try {
        debugPrint('🔄 메시지 화면 초기화 - 대화 상대 ID: ${widget.userId}');

        // 비어있는 대화인지 확인
        List<Message> conversation = [];

        // 안전한 메시지 가져오기 시도
        try {
          conversation = _messageService.getConversationWith(widget.userId);
          debugPrint('🔄 대화 목록 불러오기 성공: ${conversation.length}개 메시지');
        } catch (e) {
          debugPrint('⚠️ 대화 목록 불러오기 오류: $e');
          conversation = [];
        }

        if (conversation.isEmpty) {
          debugPrint('⚠️ 대화가 비어있습니다. 테스트 메시지 생성합니다.');
          // 대화가 비어있으면 테스트 메시지 자동 생성
          if (mounted) {
            _createTestMessages();
          }
        } else {
          debugPrint('✅ 대화 ${conversation.length}개 메시지 로드됨.');
          // 읽음 상태로 변경 (내부에서 mounted 체크)
          if (mounted) {
            _markMessagesAsRead();
            // 스크롤 이동 (내부에서 mounted 체크)
            _safelyScrollToBottom();
          }
        }
      } catch (e) {
        debugPrint('⚠️ 초기화 중 오류 발생: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 현재 스캐폴드 메신저 저장 - dispose에서 안전하게 접근 가능
    try {
      _scaffoldMessenger = ScaffoldMessenger.of(context);
      debugPrint('✅ ScaffoldMessenger 참조 저장 성공');
    } catch (e) {
      debugPrint('⚠️ ScaffoldMessenger 참조 저장 실패: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 MessageDetailView dispose 시작: ${widget.userId}');

    // mounted 상태 확인 없이 직접 컨트롤러 정리
    try {
      // dispose 메서드에서 BuildContext나 State에 의존하는 코드 제거
      // context나 widget에 접근하지 않음
      _messageController.dispose();
      _scrollController.dispose();

      debugPrint('✅ 컨트롤러 정리 완료');
    } catch (e) {
      debugPrint('⚠️ 컨트롤러 정리 중 오류: $e');
    }

    // 상위 dispose 호출
    super.dispose();

    debugPrint('🧹 MessageDetailView dispose 완료: ${widget.userId}');
  }

  // 메시지 전송
  Future<void> _sendMessage() async {
    // 먼저 mounted 체크
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 메시지 전송을 중단합니다.');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 임시 디버그 메시지
    debugPrint('🔄 메시지 전송 시도: $text');
    debugPrint('👤 현재 사용자 UID: ${_authService.uid}');
    debugPrint('👥 수신자 ID: ${widget.userId}');

    // 메시지 컨트롤러의 텍스트를 임시 저장 (비동기 작업 후에도 사용 가능하도록)
    final messageText = text;

    try {
      // 전송 중 상태 표시
      if (mounted) {
        setState(() {
          // 필요하면 UI에 전송 중 표시
        });
      }

      // 로그인되지 않은 경우 테스트 로그인 시도 (개발용)
      if (_authService.uid == null || _authService.uid!.isEmpty) {
        debugPrint('⚠️ 로그인되지 않음 - 테스트 계정으로 자동 로그인 시도');
        await _authService.login('test@example.com', 'Password1!');

        // 로그인 후 mounted 체크
        if (!mounted) {
          debugPrint('⚠️ 로그인 후 위젯이 dispose되어 중단');
          return;
        }

        debugPrint('✅ 테스트 로그인 완료, 새 UID: ${_authService.uid}');
      }

      // 전송 전 현재 메시지 수 확인
      final beforeCount =
          _messageService.getConversationWith(widget.userId).length;
      debugPrint('📊 전송 전 메시지 수: $beforeCount');

      // 메시지 전송
      final success = await _messageService.sendMessage(
        receiverId: widget.userId,
        content: messageText, // 임시 저장한 텍스트 사용
      );

      // 전송 후 위젯 상태 체크
      if (!mounted) {
        debugPrint('⚠️ 메시지 전송 후 위젯이 dispose되어 UI 업데이트를 중단합니다.');
        return;
      }

      // 전송 후 메시지 수 확인
      final afterCount =
          _messageService.getConversationWith(widget.userId).length;
      debugPrint('📊 전송 후 메시지 수: $afterCount');
      debugPrint(
          '📱 메시지 ${success ? "전송 성공" : "전송 실패"} ($beforeCount → $afterCount)');

      if (success) {
        // 텍스트 필드 비우기
        if (mounted && _messageController.text == messageText) {
          _messageController.clear();
        }

        // 스크롤을 맨 아래로 이동 - 별도 메서드로 추출하여 mounted 체크와 함께 호출
        _safelyScrollToBottom();
      } else if (mounted) {
        // 전송 실패 시 사용자에게 알림
        _showErrorSnackBar('메시지 전송에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 전송 중 예외 발생: $e');
      if (mounted) {
        _showErrorSnackBar('메시지 전송 중 오류가 발생했습니다.');
      }
    }
  }

  // 안전하게 스크롤을 아래로 이동하는 메서드 (mounted 확인 포함)
  void _safelyScrollToBottom() {
    if (!mounted) return;

    // 약간의 딜레이 후 스크롤 (메시지 렌더링 시간 확보)
    Future.delayed(const Duration(milliseconds: 300), () {
      // 딜레이 후 다시 mounted 체크
      if (!mounted) {
        debugPrint('⚠️ 스크롤 시도 시 위젯이 dispose되어 중단');
        return;
      }

      debugPrint('🔄 스크롤 맨 아래로 이동 시도');
      _scrollToBottom();
    });
  }

  // 에러 스낵바 표시 헬퍼 메서드
  void _showErrorSnackBar(String message) {
    if (!mounted) {
      debugPrint('⚠️ 위젯이 mounted 상태가 아니라 스낵바를 표시할 수 없습니다: $message');
      return;
    }

    // 일반 ScaffoldMessenger.of(context) 대신 Get.snackbar 사용 - context 의존성 제거
    Get.snackbar(
      '알림',
      message,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  // 위치 공유 요청 보내기
  Future<void> _sendLocationRequest() async {
    // 먼저 mounted 체크
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 위치 공유 요청을 중단합니다.');
      return;
    }

    try {
      // 로그인되지 않은 경우 테스트 로그인 시도 (개발용)
      if (_authService.uid == null || _authService.uid!.isEmpty) {
        debugPrint('⚠️ 로그인되지 않음 - 테스트 계정으로 자동 로그인 시도');
        await _authService.login('test@example.com', 'Password1!');

        // 로그인 후 mounted 체크
        if (!mounted) {
          debugPrint('⚠️ 로그인 후 위젯이 dispose되어 중단');
          return;
        }

        debugPrint('✅ 테스트 로그인 완료, 새 UID: ${_authService.uid}');
      }

      // 위치 공유 요청 전송
      final success = await _messageService.sendLocationRequest(
        receiverId: widget.userId,
      );

      // 전송 후 위젯 상태 체크
      if (!mounted) {
        debugPrint('⚠️ 위치 공유 요청 후 위젯이 dispose되어 UI 업데이트를 중단합니다.');
        return;
      }

      if (!success && mounted) {
        // 전송 실패 시 사용자에게 알림
        _showErrorSnackBar('위치 공유 요청 전송에 실패했습니다.');
      } else if (success) {
        // 성공한 경우 스크롤 이동
        _safelyScrollToBottom();
      }
    } catch (e) {
      debugPrint('⚠️ 위치 공유 요청 중 예외 발생: $e');
      if (mounted) {
        _showErrorSnackBar('위치 공유 요청 중 오류가 발생했습니다.');
      }
    }
  }

  // 읽지 않은 메시지를 읽음 상태로 변경
  Future<void> _markMessagesAsRead() async {
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 읽음 상태 변경을 중단합니다.');
      return;
    }

    try {
      final conversation = _messageService.getConversationWith(widget.userId);
      final currentUserId = _authService.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 현재 로그인된 사용자가 없어 읽음 상태 변경을 중단합니다.');
        return;
      }

      // 읽지 않은 메시지만 필터링 (수신한 메시지만)
      final unreadMessageIds = conversation
          .where((m) => !m.isRead && m.receiverId == currentUserId)
          .map((m) => m.id)
          .toList();

      if (unreadMessageIds.isEmpty) {
        debugPrint('✅ 읽지 않은 메시지가 없습니다.');
        return;
      }

      debugPrint('🔄 ${unreadMessageIds.length}개의 메시지를 읽음 상태로 변경합니다.');
      await _messageService.markMultipleMessagesAsRead(unreadMessageIds);

      // 읽음 처리 후 위젯 상태 확인은 필요 없음 - UI가 자동으로 갱신됨
    } catch (e) {
      debugPrint('⚠️ 메시지 읽음 상태 변경 중 오류 발생: $e');
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
        final maxScroll = _scrollController.position.maxScrollExtent;
        debugPrint('🔄 스크롤 이동: maxScrollExtent=$maxScroll');

        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        debugPrint('⚠️ 스크롤 컨트롤러에 클라이언트 없음');
      }
    } catch (e) {
      debugPrint('⚠️ 스크롤 이동 중 오류 발생: $e');
    }
  }

  // 테스트 메시지 생성
  Future<void> _createTestMessages() async {
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 테스트 메시지 생성을 중단합니다.');
      return;
    }

    try {
      debugPrint('🧪 테스트 메시지 생성 시도: ${widget.userId}');
      _messageService.createTestMessagesForUser(widget.userId);

      // 메시지 생성 후 스크롤 이동
      _safelyScrollToBottom();

      if (mounted) {
        // ScaffoldMessenger 대신 Get.snackbar 사용
        Get.snackbar(
          '알림',
          '테스트 메시지가 생성되었습니다',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 테스트 메시지 생성 중 오류: $e');
      if (mounted) {
        _showErrorSnackBar('테스트 메시지 생성 중 오류가 발생했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getRecipientName(widget.userId)),
        actions: [
          // 테스트 메시지 생성 버튼 (개발용)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _createTestMessages,
            tooltip: '테스트 메시지 생성',
          ),
          // 로컬 스토리지 디버깅 버튼 (개발용)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              await _messageService.debugLocalStorage();
              if (mounted) {
                Get.snackbar(
                  '로컬 스토리지 디버깅',
                  '로그를 확인하세요',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              }
            },
            tooltip: '스토리지 디버깅',
          ),
          // 모든 메시지 삭제 버튼 (개발용)
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await _messageService.clearAllMessages();
              if (mounted) {
                Get.snackbar(
                  '메시지 삭제',
                  '모든 메시지가 삭제되었습니다',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              }
            },
            tooltip: '모든 메시지 삭제',
          ),
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
              List<Message> conversation = [];

              try {
                conversation =
                    _messageService.getConversationWith(widget.userId);
                debugPrint('🔄 UI 갱신: 대화 목록 ${conversation.length}개');
              } catch (e) {
                debugPrint('⚠️ 대화 목록 가져오기 오류: $e');
                // 오류 발생 시 빈 목록 사용
                conversation = [];
              }

              if (conversation.isEmpty) {
                debugPrint('⚠️ 대화 목록이 비어 있습니다. 시작 메시지 표시');

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('대화를 시작해보세요!'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          _messageController.text = '안녕하세요!';
                          _sendMessage();
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('첫 메시지 보내기'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _createTestMessages,
                        icon: const Icon(Icons.add_comment),
                        label: const Text('테스트 메시지 생성'),
                      ),
                    ],
                  ),
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
                    debugPrint('⚠️ 대화 목록 인덱스 $index에 메시지가 null입니다');
                    return const SizedBox.shrink();
                  }

                  // 메시지 정보 로깅 (문제 발생 시 확인용)
                  if (index == 0) {
                    try {
                      debugPrint(
                          '🔍 첫 번째 메시지: ID=${message.id.substring(0, 6)}... | 보낸이=${message.senderId} | 받는이=${message.receiverId}');
                    } catch (e) {
                      debugPrint('⚠️ 메시지 로깅 오류: $e');
                    }
                  }

                  // 안전하게 발신자 확인
                  bool isCurrentUserSender = false;
                  try {
                    isCurrentUserSender =
                        message.senderId == _authService.uid ||
                            message.senderId.startsWith('test-');
                  } catch (e) {
                    debugPrint('⚠️ 발신자 확인 오류: $e');
                  }

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
