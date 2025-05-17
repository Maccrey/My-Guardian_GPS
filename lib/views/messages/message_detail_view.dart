import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';
import 'shared_location_view.dart'; // 위치 공유 화면 import 추가

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

        // Firebase에서 메시지 새로고침 먼저 실행
        _messageService.refreshMessages().then((_) {
          if (!mounted) return;

          // 새로고침 후 상태 업데이트
          setState(() {});

          // 읽음 상태로 변경 (내부에서 mounted 체크)
          _markMessagesAsRead();
          // 스크롤 이동 (내부에서 mounted 체크)
          _safelyScrollToBottom();
        });
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

      // 답장 메시지 정보 추출
      final String? replyToMessageId = _messageService.replyToMessage.value?.id;

      // 메시지 전송
      final success = await _messageService.sendMessage(
        receiverId: widget.userId,
        content: messageText, // 임시 저장한 텍스트 사용
        replyToMessageId: replyToMessageId,
      );

      // 답장 모드 초기화
      _messageService.cancelReply();

      // 전송 후 위젯 상태 체크
      if (!mounted) {
        debugPrint('⚠️ 메시지 전송 후 위젯이 dispose되어 UI 업데이트를 중단합니다.');
        return;
      }

      // 대화 목록 수동 새로고침
      await Future.delayed(
          const Duration(milliseconds: 100)); // 잠시 대기하여 메시지 저장 완료 확인

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

        // 새로운 대화 목록 가져오기 강제 - 새 메시지가 표시되도록
        if (mounted) {
          setState(() {
            // 상태 갱신하여 대화 목록 다시 불러오기
          });
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

  // 위치 공유 요청 보내기 (현재 위치를 바로 보내도록 수정)
  Future<void> _sendLocationRequest() async {
    // 먼저 mounted 체크
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 위치 공유를 중단합니다.');
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

      // 테스트 위치 정보 생성 (실제 앱에서는 위치 권한 획득 후 실제 현재 위치를 사용)
      final double latitude =
          37.5665 + (DateTime.now().millisecond / 10000); // 서울 위도에 약간의 랜덤성 추가
      final double longitude =
          126.9780 + (DateTime.now().second / 1000); // 서울 경도에 약간의 랜덤성 추가

      // 위치 공유 메시지 전송
      final success = await _messageService.sendLocationShare(
        receiverId: widget.userId,
        latitude: latitude,
        longitude: longitude,
        message: '제 현재 위치입니다.',
      );

      // 전송 후 위젯 상태 체크
      if (!mounted) {
        debugPrint('⚠️ 위치 공유 후 위젯이 dispose되어 UI 업데이트를 중단합니다.');
        return;
      }

      if (!success && mounted) {
        // 전송 실패 시 사용자에게 알림
        _showErrorSnackBar('위치 공유 전송에 실패했습니다.');
      } else if (success) {
        // 성공한 경우 스크롤 이동
        _safelyScrollToBottom();
      }
    } catch (e) {
      debugPrint('⚠️ 위치 공유 중 예외 발생: $e');
      if (mounted) {
        _showErrorSnackBar('위치 공유 중 오류가 발생했습니다.');
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

  // 상대방 이름 가져오기 (개선된 버전)
  String _getRecipientName(String userId) {
    // Firebase auth 사용자 ID인 경우 (이메일 기반으로 개선된 표시)
    if (userId.isNotEmpty && userId != _authService.uid) {
      // 메시지 서비스에서 사용자 정보 찾기 시도
      try {
        // 검색 결과에서 사용자 찾기
        final foundUsers = _messageService.searchResults
            .where((user) => user.uid == userId)
            .toList();

        if (foundUsers.isNotEmpty) {
          // 닉네임이 있으면 닉네임 반환, 없으면 이메일 앞부분 사용
          final user = foundUsers.first;
          if (user.nickname != null && user.nickname!.isNotEmpty) {
            return user.nickname!;
          } else if (user.email != null && user.email!.isNotEmpty) {
            // 이메일 앞부분만 추출 (@ 앞부분)
            return user.email!.split('@')[0];
          }
        }
      } catch (e) {
        debugPrint('⚠️ 사용자 정보 검색 오류: $e');
      }

      // FirebaseAuth 현재 사용자와 비교
      if (_authService.currentUser?.email != null) {
        final currentEmail = _authService.currentUser!.email!;
        if (currentEmail.contains(userId) || userId.contains(currentEmail)) {
          return '나';
        }
      }

      // fixed- 접두사 제거하고 보기 좋게 표시
      if (userId.startsWith('fixed-')) {
        final cleanId = userId.replaceAll('fixed-', '');
        // user- 접두사도 제거
        final finalId = cleanId.replaceAll('user-', '');

        // 숫자로만 구성된 ID인 경우 '사용자'와 함께 표시
        if (finalId.contains(RegExp(r'^[0-9]+$'))) {
          return '사용자 $finalId';
        }

        // 이메일 형식인지 확인
        if (finalId.contains('@')) {
          // 이메일 형식이면 @ 앞부분만 표시
          return finalId.split('@')[0];
        }

        // 그 외의 경우 그대로 표시
        return finalId.capitalize ?? finalId;
      }

      // real- 접두사 제거
      if (userId.startsWith('real-')) {
        final cleanId = userId.replaceAll('real-', '');
        return cleanId.capitalize ?? cleanId;
      }

      // test- 접두사 제거
      if (userId.startsWith('test-')) {
        final cleanId = userId.replaceAll('test-', '');
        return '테스트 $cleanId';
      }
    }

    // 특수 케이스 처리
    if (userId == 'admin') {
      return '관리자';
    } else if (userId == _authService.uid) {
      return '나';
    }

    // ID에서 직접 이름 추출 시도
    if (userId.contains('@')) {
      // 이메일 형식이면 @ 앞부분만 표시
      return userId.split('@')[0];
    }

    // 마지막 대안: ID 자체를 반환하되 가능하면 정리
    return userId.replaceAll(RegExp(r'[0-9-_]+$'), '').capitalize ?? userId;
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

  // 새로고침 버튼 처리 메서드 (로딩 상태 표시)
  Future<void> _refreshMessages() async {
    if (!mounted) return;

    try {
      // 로딩 상태 표시
      setState(() {
        // 새로고침 중 상태 변경
      });

      debugPrint('🔄 메시지 화면 새로고침 시작');

      // 현재 로그인 상태 확인
      final currentUserId = _authService.uid;
      debugPrint('👤 현재 사용자 ID: $currentUserId');
      debugPrint('🔍 대화 상대 ID: ${widget.userId}');

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 로그인되어 있지 않음 - 테스트 계정으로 자동 로그인 시도');
        await _authService.login('test@example.com', 'Password1!');
      }

      // Firebase에서 메시지 새로고침
      await _messageService.refreshMessages();

      if (!mounted) return;

      // 강제로 상태 갱신 (오류가 있더라도)
      setState(() {});

      // 대화 목록 확인
      final conversation = _messageService.getConversationWith(widget.userId);
      debugPrint('🔄 새로고침 후 대화 목록: ${conversation.length}개 메시지');

      // 읽음 상태 갱신 및 스크롤 이동
      _markMessagesAsRead();
      _safelyScrollToBottom();

      // 오류가 있으면 표시
      if (_messageService.hasError.value) {
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
      } else if (conversation.isEmpty) {
        // 메시지가 없는 경우 안내
        if (mounted) {
          Get.snackbar(
            '대화 없음',
            '${_getRecipientName(widget.userId)}님과의 대화가 없습니다. 첫 메시지를 보내보세요.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.withOpacity(0.7),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // 성공
        if (mounted) {
          Get.snackbar(
            '새로고침 완료',
            '${conversation.length}개 메시지가 있습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.withOpacity(0.7),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 새로고침 중 오류 발생: $e');

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getRecipientName(widget.userId)),
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
            tooltip: '메시지 새로고침',
          ),
          // 디버그 버튼 (개발용)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              if (mounted) {
                try {
                  final currentUserId = _authService.uid ?? 'empty UID';
                  final messageCount = _messageService.messages.length;
                  final filteredCount =
                      _messageService.getConversationWith(widget.userId).length;

                  // 메시지 디버깅을 위한 정보 표시
                  Get.snackbar(
                    '메시지 디버깅',
                    '대화 상대: ${widget.userId}\n'
                        '현재 사용자: $currentUserId\n'
                        '총 메시지: $messageCount개\n'
                        '필터링된 메시지: $filteredCount개',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 4),
                  );

                  // 상세 로그 출력
                  debugPrint('===== 메시지 디버깅 정보 =====');
                  debugPrint('🔍 대화 상대 ID: ${widget.userId}');
                  debugPrint('👤 현재 사용자 ID: $currentUserId');
                  debugPrint('📊 총 메시지 수: $messageCount');
                  debugPrint('🔎 필터링된 메시지 수: $filteredCount');

                  // 모든 메시지 로그
                  if (_messageService.messages.isNotEmpty) {
                    debugPrint(
                        '📝 첫 번째 메시지: ${_messageService.messages.first}');

                    // 관련 메시지만 로그
                    final List<Message> related = _messageService.messages
                        .where((m) =>
                            m.senderId == widget.userId ||
                            m.receiverId == widget.userId ||
                            m.senderId == currentUserId ||
                            m.receiverId == currentUserId)
                        .toList();

                    for (var i = 0; i < related.length && i < 5; i++) {
                      debugPrint('📄 관련 메시지 #$i: ${related[i]}');
                    }
                  } else {
                    debugPrint('⚠️ 메시지가 없습니다.');
                  }
                  debugPrint('============================');
                } catch (e) {
                  debugPrint('⚠️ 디버깅 중 오류: $e');
                  Get.snackbar('오류', '디버깅 정보 수집 중 오류 발생: $e');
                }
              }
            },
            tooltip: '메시지 디버깅',
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _sendLocationRequest,
            tooltip: '현재 위치 공유',
          ),
        ],
      ),
      body: Column(
        children: [
          // 답장 UI 표시 - 별도 Obx 위젯으로 분리
          Obx(() => _messageService.replyToMessage.value != null
              ? _buildReplyPreview()
              : const SizedBox.shrink()),

          // 메시지 목록 - Obx 중첩 제거, StatefulBuilder만 사용
          Expanded(
            child: Builder(builder: (context) {
              // 대화 새로고침 버튼 추가
              List<Message> conversation = [];

              try {
                // 대화 목록 가져오기
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
                      const Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '대화가 없습니다',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_getRecipientName(widget.userId)}님과의 대화를 시작해보세요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          _messageController.text = '안녕하세요!';
                          _sendMessage();
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('첫 메시지 보내기'),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _refreshMessages,
                        icon: const Icon(Icons.refresh),
                        label: const Text('대화 다시 불러오기'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshMessages,
                child: ListView.builder(
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

                    // 안전하게 발신자 확인
                    bool isCurrentUserSender = false;
                    try {
                      final currentUserId = _authService.uid ?? '';
                      isCurrentUserSender = message.senderId == currentUserId;
                    } catch (e) {
                      debugPrint('⚠️ 발신자 확인 오류: $e');
                    }

                    // 메시지 슬라이드로 삭제/답장 기능
                    return Dismissible(
                      key: Key(message.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.reply, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // 왼쪽으로 스와이프: 삭제
                          final bool? result = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('메시지 삭제'),
                                content: const Text('이 메시지를 삭제하시겠습니까?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('삭제'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (result == true) {
                            await _messageService.deleteMessage(message.id);
                            // 삭제 후 수동 갱신
                            if (mounted) {
                              setState(() {});
                            }
                          }
                          return false; // 삭제 후 Dismissible 효과는 보이지 않도록
                        } else if (direction == DismissDirection.startToEnd) {
                          // 오른쪽으로 스와이프: 답장
                          _messageService.setReplyToMessage(message);
                          return false; // Dismissible 효과는 보이지 않도록
                        }
                        return false;
                      },
                      child: GestureDetector(
                        onTap: () {
                          // 메시지 클릭 시 답장 모드
                          _messageService.setReplyToMessage(message);
                        },
                        child: _buildMessageItem(message, isCurrentUserSender),
                      ),
                    );
                  },
                ),
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

  // 답장 미리보기 위젯
  Widget _buildReplyPreview() {
    final replyMessage = _messageService.replyToMessage.value;
    if (replyMessage == null) return const SizedBox.shrink();

    final bool isCurrentUserSender =
        replyMessage.senderId == _authService.uid ||
            replyMessage.senderId.startsWith('test-');
    final senderName =
        isCurrentUserSender ? '나' : _getRecipientName(replyMessage.senderId);

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade200,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$senderName님에게 답장',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  replyMessage.content.length > 50
                      ? '${replyMessage.content.substring(0, 50)}...'
                      : replyMessage.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _messageService.cancelReply(),
          ),
        ],
      ),
    );
  }

  // 메시지 아이템 위젯
  Widget _buildMessageItem(Message message, bool isCurrentUserSender) {
    // 답장 참조 메시지 표시
    Widget? replyReferenceWidget;
    if (message.replyToMessageId != null) {
      // 참조된 메시지 찾기
      final referencedMessage = _messageService.messages
          .firstWhereOrNull((m) => m.id == message.replyToMessageId);

      if (referencedMessage != null) {
        final refSenderName = referencedMessage.senderId == _authService.uid
            ? '나'
            : _getRecipientName(referencedMessage.senderId);

        replyReferenceWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isCurrentUserSender
                ? Colors.blue.shade800.withOpacity(0.3)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                refSenderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: isCurrentUserSender ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                referencedMessage.content.length > 30
                    ? '${referencedMessage.content.substring(0, 30)}...'
                    : referencedMessage.content,
                style: TextStyle(
                  fontSize: 11,
                  color: isCurrentUserSender ? Colors.white70 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }
    }

    Widget messageContent;

    if (message.messageType == 'text') {
      // 일반 텍스트 메시지
      messageContent = Text(
        message.content,
        style: TextStyle(
          color: isCurrentUserSender ? Colors.white : Colors.black,
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
              color: isCurrentUserSender ? Colors.white : Colors.black,
            ),
          ),
        ],
      );
    } else if (message.messageType == 'location_share') {
      // 위치 공유
      final locationData = _parseLocationMessage(message.content);

      if (locationData != null) {
        messageContent = GestureDetector(
          onTap: () {
            // 위치 정보가 있는 경우 지도 화면으로 이동
            _openSharedLocation(message, locationData, isCurrentUserSender);
          },
          child: Column(
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
                      color: isCurrentUserSender ? Colors.white : Colors.black,
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
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: isCurrentUserSender
                      ? Colors.white.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '탭하여 지도에서 보기',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrentUserSender
                        ? Colors.white.withOpacity(0.9)
                        : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        messageContent = const Text('잘못된 위치 데이터');
      }
    } else {
      // 기타 메시지 타입
      messageContent = Text(
        message.content,
        style: TextStyle(
          color: isCurrentUserSender ? Colors.white : Colors.black,
        ),
      );
    }

    return Align(
      alignment:
          isCurrentUserSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isCurrentUserSender ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyReferenceWidget != null) replyReferenceWidget,
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
  }

  // 위치 공유 메시지를 지도에서 표시
  void _openSharedLocation(Message message, Map<String, dynamic> locationData,
      bool isCurrentUserSender) {
    if (!mounted) return;

    try {
      final double latitude = double.parse(locationData['latitude'].toString());
      final double longitude =
          double.parse(locationData['longitude'].toString());
      final String displayMessage = locationData['message'] ?? '위치가 공유되었습니다';

      // 발신자 이름 결정
      final String senderName =
          isCurrentUserSender ? '나' : _getRecipientName(message.senderId);

      // 지도 화면으로 이동
      Get.to(() => SharedLocationView(
            latitude: latitude,
            longitude: longitude,
            message: displayMessage,
            timestamp: message.timestamp,
            senderName: senderName,
          ));
    } catch (e) {
      debugPrint('⚠️ 위치 정보 파싱 오류: $e');

      if (mounted) {
        Get.snackbar(
          '오류',
          '위치 정보를 불러올 수 없습니다',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    }
  }
}
