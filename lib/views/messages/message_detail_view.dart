import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
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

        // 1. 먼저 Firestore 구독 확인하고 실시간 업데이트 활성화
        _messageService.ensureFirestoreSubscription();

        // 2. 그다음 Firebase에서 메시지 새로고침
        _messageService.refreshMessages().then((_) {
          if (!mounted) return;

          // 읽음 상태로 변경 (내부에서 mounted 체크)
          _markMessagesAsRead();
          // 스크롤 이동 (내부에서 mounted 체크)
          _safelyScrollToBottom();
        });
      } catch (e) {
        debugPrint('⚠️ 초기화 중 오류 발생: $e');
      }
    });

    // 메시지 리스트에 변경이 있을 때마다 UI 업데이트 및 읽음 처리
    ever(_messageService.messages, (_) {
      if (mounted) {
        debugPrint('🔔 메시지 리스트 변경 감지 - UI 업데이트');
        _markMessagesAsRead();
        _safelyScrollToBottom();
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      // 오늘 메시지는 시/분만 표시
      return DateFormat('HH:mm').format(date);
    } else {
      // 이전 메시지는 날짜와 시간 표시
      return DateFormat('M/d HH:mm').format(date);
    }
  }

  // 위치 메시지 파싱
  Map<String, dynamic>? _parseLocationMessage(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // 상대방 이름 가져오기 (닉네임 우선 표시로 개선된 버전)
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

    // Firebase user 검색에서 찾기
    try {
      // 1. 메시지 서비스의 검색 결과에서 사용자 먼저 찾기
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

      // 2. 검색 결과에 없는 경우는 로컬 캐시에서 사용자 정보 사용
      // MessageService에 findUserById 메서드가 없으므로 searchUsers로 대체
      if (userId.isNotEmpty) {
        // 검색 쿼리를 통해 사용자 정보 가져오기 시도
        _messageService.searchUsers(
            userId.replaceAll("real-", "").replaceAll("fixed-", ""));
      }
    } catch (e) {
      debugPrint('⚠️ 사용자 정보 검색 처리 중 오류: $e');
    }

    // 고정 테스트 사용자 맵핑 (특정 UID에 대한 이름 하드코딩)
    final Map<String, String> hardcodedNames = {
      'maccrey': '매크레이',
      'real-maccrey': '매크레이',
      'real-john': '존',
      'real-amy': '에이미',
      'fixed-user-1': '사용자1',
      'fixed-user-2': '사용자2',
      'fixed-user-3': '홍길동',
      'fixed-user-4': '김영자',
      'fixed-user-5': '박지수',
      'fixed-user-6': '이철수',
    };

    // 하드코딩된 이름 맵에서 찾기
    if (hardcodedNames.containsKey(userId)) {
      return hardcodedNames[userId]!;
    }

    // ID 접두어 처리하여 사람이 읽기 쉬운 형식으로 변환

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
        : '사용자 ${userId.substring(0, min(userId.length, 8))}';
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
      if (_messageService.isLoading.value) {
        Get.snackbar(
          '로딩 중',
          '메시지를 이미 불러오는 중입니다. 잠시만 기다려주세요.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      debugPrint('🔄 메시지 화면 새로고침 시작');

      // 현재 로그인 상태 확인
      final currentUserId = _authService.uid;
      debugPrint('👤 현재 사용자 ID: $currentUserId');
      debugPrint('🔍 대화 상대 ID: ${widget.userId}');

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 로그인되어 있지 않음 - 테스트 계정으로 자동 로그인 시도');
        await _authService.login('test@example.com', 'Password1!');
      }

      // 현재 메시지 개수 (비교용)
      final beforeCount =
          _messageService.getConversationWith(widget.userId).length;

      // 새로고침 시작 알림
      Get.snackbar(
        '새로고침 중',
        '메시지를 새로고침하는 중입니다...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blue.withOpacity(0.3),
      );

      // Firebase에서 메시지 새로고침 및 구독 활성화
      await _messageService.refreshMessages();

      if (!mounted) return;

      // 새로고침 후 메시지 개수 확인
      final afterCount =
          _messageService.getConversationWith(widget.userId).length;
      final int diff = afterCount - beforeCount;

      // 읽음 상태 갱신 및 스크롤 이동
      _markMessagesAsRead();
      _safelyScrollToBottom();

      // 결과에 따른 피드백
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
      } else if (afterCount == 0) {
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
        // 성공 메시지
        String message = '${afterCount}개 메시지가 있습니다.';
        if (diff > 0) {
          message = '${diff}개의 새로운 메시지를 받았습니다.';
        } else if (diff < 0) {
          message = '${-diff}개의 메시지가 삭제되었습니다.';
        }

        if (mounted) {
          Get.snackbar(
            '새로고침 완료',
            message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.withOpacity(0.7),
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        }
      }

      debugPrint('✅ 메시지 새로고침 완료: $beforeCount → $afterCount');
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
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            // 프로필 아바타
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 20,
              child: Text(
                _getRecipientName(widget.userId).isNotEmpty
                    ? _getRecipientName(widget.userId)[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: Colors.blue.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            // 사용자 이름 및 온라인 상태
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getRecipientName(widget.userId),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '온라인',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 위치 공유 버튼
          IconButton(
            icon: const Icon(Icons.location_on),
            color: Colors.green.shade600,
            onPressed: _sendLocationRequest,
            tooltip: '현재 위치 공유',
          ),
          // 검색 버튼
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: '대화 검색',
          ),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
            tooltip: '메시지 새로고침',
          ),
          // 옵션 메뉴
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') {
                _showClearConversationDialog();
              } else if (value == 'debug') {
                // 디버그 기능
                if (mounted) {
                  try {
                    final currentUserId = _authService.uid ?? 'empty UID';
                    final messageCount = _messageService.messages.length;
                    final filteredCount = _messageService
                        .getConversationWith(widget.userId)
                        .length;

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
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('대화 삭제'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('디버그 정보'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // 채팅 배경 패턴 추가
          color: Colors.grey.shade100,
          image: DecorationImage(
            image: const NetworkImage(
              'https://i.pinimg.com/originals/97/c0/07/97c00759d90d786d9b6096d274ad3e07.png',
            ),
            opacity: 0.1,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Column(
          children: [
            // 답장 UI 표시 - 별도 Obx 위젯으로 분리
            Obx(() => _messageService.replyToMessage.value != null
                ? _buildReplyPreview()
                : const SizedBox.shrink()),

            // 메시지 목록 - Obx 사용하여 메시지 변경에 자동 반응
            Expanded(
              child: Obx(() {
                // 대화 목록 가져오기
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

                if (_messageService.isLoading.value) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('메시지를 불러오는 중...'),
                      ],
                    ),
                  );
                }

                if (_messageService.hasError.value) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          '${_messageService.errorMessage.value}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshMessages,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (conversation.isEmpty) {
                  debugPrint('⚠️ 대화 목록이 비어 있습니다. 시작 메시지 표시');

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 80, color: Colors.blue.shade200),
                        const SizedBox(height: 24),
                        const Text(
                          '대화가 없습니다',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            '${_getRecipientName(widget.userId)}님과의 대화를 시작해보세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            _messageController.text = '안녕하세요!';
                            _sendMessage();
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('첫 메시지 보내기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
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
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _refreshMessages,
                          icon: const Icon(Icons.refresh),
                          label: const Text('대화 다시 불러오기'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshMessages,
                  color: Colors.blue.shade700,
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

                      // 날짜 구분선 표시 로직 추가
                      final bool showDateSeparator = index == 0 ||
                          !_isSameDay(
                            conversation[index].timestamp,
                            conversation[index - 1].timestamp,
                          );

                      // 안전하게 발신자 확인
                      bool isCurrentUserSender = false;
                      try {
                        final currentUserId = _authService.uid ?? '';
                        isCurrentUserSender = message.senderId == currentUserId;
                      } catch (e) {
                        debugPrint('⚠️ 발신자 확인 오류: $e');
                      }

                      return Column(
                        children: [
                          // 날짜 구분선
                          if (showDateSeparator)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _formatMessageDate(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 메시지 슬라이드로 삭제/답장 기능
                          Dismissible(
                            key: Key(message.id),
                            background: Container(
                              color: Colors.red.shade400,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.blue.shade400,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child:
                                  const Icon(Icons.reply, color: Colors.white),
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
                                  await _messageService
                                      .deleteMessage(message.id);
                                }
                                return false; // 삭제 후 Dismissible 효과는 보이지 않도록
                              } else if (direction ==
                                  DismissDirection.startToEnd) {
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
                              child: _buildMessageItem(
                                  message, isCurrentUserSender),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),

            // 메시지 입력 영역
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 위치 공유 버튼
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.location_on,
                        color: Colors.green.shade700,
                      ),
                      onPressed: _sendLocationRequest,
                      tooltip: '현재 위치 공유',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minHeight: 36,
                        minWidth: 36,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 메시지 입력창
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 전송 버튼
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade300.withOpacity(0.5),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                      tooltip: '메시지 보내기',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 같은 날짜인지 확인하는 헬퍼 메서드
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 메시지 날짜 형식화 (YYYY-MM-DD 또는 오늘/어제)
  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '오늘';
    } else if (messageDate == yesterday) {
      return '어제';
    } else {
      return DateFormat('yyyy년 M월 d일').format(date);
    }
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
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$senderName님에게 답장',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  replyMessage.content.length > 50
                      ? '${replyMessage.content.substring(0, 50)}...'
                      : replyMessage.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _messageService.cancelReply(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
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

    // 메시지 타입에 따른 컨텐츠 생성
    if (message.messageType == 'text') {
      // 일반 텍스트 메시지
      messageContent = Text(
        message.content,
        style: TextStyle(
          color: isCurrentUserSender ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    } else if (message.messageType == 'location_request') {
      // 위치 공유 요청
      messageContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_searching,
            size: 18,
            color: isCurrentUserSender ? Colors.white : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isCurrentUserSender ? Colors.white : Colors.black87,
              fontSize: 15,
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
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrentUserSender
                    ? [Colors.blue.shade700, Colors.blue.shade500]
                    : [Colors.teal.shade200, Colors.teal.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 22,
                      color: isCurrentUserSender
                          ? Colors.white
                          : Colors.teal.shade800,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        locationData['message'] ?? '위치가 공유되었습니다',
                        style: TextStyle(
                          color: isCurrentUserSender
                              ? Colors.white
                              : Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '좌표: ${locationData['latitude'].toStringAsFixed(5)}, ${locationData['longitude'].toStringAsFixed(5)}',
                  style: TextStyle(
                    color: isCurrentUserSender
                        ? Colors.white.withOpacity(0.9)
                        : Colors.teal.shade700.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isCurrentUserSender
                        ? Colors.white.withOpacity(0.25)
                        : Colors.teal.shade800.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 16,
                        color: isCurrentUserSender
                            ? Colors.white
                            : Colors.teal.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '지도에서 보기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUserSender
                              ? Colors.white
                              : Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          color: isCurrentUserSender ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }

    return Align(
      alignment:
          isCurrentUserSender ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(Get.context!).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: isCurrentUserSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 발신자 이름 표시 (자신이 아닌 경우만)
              if (!isCurrentUserSender &&
                  message.messageType != 'location_share')
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    _getRecipientName(message.senderId),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // 실제 메시지 컨테이너
              Container(
                padding: message.messageType == 'location_share'
                    ? EdgeInsets.zero // 위치 공유는 자체 패딩 있음
                    : const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                decoration: message.messageType == 'location_share'
                    ? null // 위치 공유는 자체 장식 있음
                    : BoxDecoration(
                        color: isCurrentUserSender
                            ? Colors.blue.shade600
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft:
                              Radius.circular(isCurrentUserSender ? 16 : 4),
                          topRight:
                              Radius.circular(isCurrentUserSender ? 4 : 16),
                          bottomLeft: const Radius.circular(16),
                          bottomRight: const Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyReferenceWidget != null) replyReferenceWidget,
                    messageContent,
                    if (message.messageType != 'location_share')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrentUserSender
                                ? Colors.white.withOpacity(0.7)
                                : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 위치 공유 메시지는 시간 표시를 아래에 별도로
              if (message.messageType == 'location_share')
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8, left: 8),
                  child: Text(
                    _formatMessageTime(message.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
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

      // 지도 화면으로 이동 - 슬라이드 전환 애니메이션 추가
      Get.to(
        () => SharedLocationView(
          latitude: latitude,
          longitude: longitude,
          message: displayMessage,
          timestamp: message.timestamp,
          senderName: senderName,
        ),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );

      // 위치 공유시 진동 피드백 추가 (실제 구현시)
      // HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('⚠️ 위치 정보 파싱 오류: $e');

      if (mounted) {
        Get.snackbar(
          '오류',
          '위치 정보를 불러올 수 없습니다',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
        );
      }
    }
  }

  // 대화 내용 검색 다이얼로그
  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    List<Message> searchResults = [];
    String searchQuery = '';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('대화 검색'),
            content: Container(
              width: 300,
              height: 400,
              child: Column(
                children: [
                  // 검색창
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '검색어 입력...',
                      prefixIcon:
                          Icon(Icons.search, color: Colors.blue.shade700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade200,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          searchQuery = value.trim().toLowerCase();
                          searchResults = _messageService
                              .getConversationWith(widget.userId)
                              .where((msg) => msg.content
                                  .toLowerCase()
                                  .contains(searchQuery))
                              .toList();
                        });
                      } else {
                        setState(() {
                          searchResults = [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 검색 결과
                  Expanded(
                    child: searchQuery.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '검색어를 입력하세요',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '검색 결과가 없습니다',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  final message = searchResults[index];
                                  final isFromMe =
                                      message.senderId == _authService.uid;

                                  // 검색된 텍스트 강조 처리
                                  final String highlightedText =
                                      message.content;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: isFromMe
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade200,
                                      radius: 16,
                                      child: Text(
                                        isFromMe
                                            ? '나'
                                            : _getRecipientName(
                                                    widget.userId)[0]
                                                .toUpperCase(),
                                        style: TextStyle(
                                          color: isFromMe
                                              ? Colors.blue.shade800
                                              : Colors.grey.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      highlightedText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _formatMessageTime(message.timestamp),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _scrollToMessage(message);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // 다이얼로그가 닫힐 때 컨트롤러 해제
      searchController.dispose();
    });
  }

  // 특정 메시지로 스크롤
  void _scrollToMessage(Message message) {
    try {
      final messages = _messageService.getConversationWith(widget.userId);
      final index = messages.indexWhere((m) => m.id == message.id);

      if (index != -1 && mounted) {
        // 역방향 리스트이므로 인덱스 계산 필요
        final reverseIndex = messages.length - 1 - index;

        // UI 갱신을 위해 약간의 딜레이 후 스크롤
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients && mounted) {
            try {
              // 스크롤 위치로 이동
              _scrollController.animateTo(
                index * 100.0, // 대략적인 메시지 높이
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              // 메시지 하이라이트 처리는 생략
            } catch (e) {
              debugPrint('⚠️ 스크롤 오류: $e');
            }
          }
        });

        // 메시지 위치를 알려주는 토스트 표시
        Get.snackbar(
          '메시지 찾음',
          '${index + 1}/${messages.length} 번째 메시지를 표시합니다',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '메시지 찾기 실패',
          '해당 메시지를 찾을 수 없습니다',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 스크롤 오류: $e');
      Get.snackbar(
        '오류',
        '메시지로 이동하는 중 오류가 발생했습니다',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  // 대화 삭제 확인 다이얼로그
  void _showClearConversationDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 삭제'),
        content: const Text(
          '이 대화의 모든 메시지를 삭제하시겠습니까?\n'
          '이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearConversation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 대화 삭제 실행
  Future<void> _clearConversation() async {
    if (!mounted) return;

    try {
      // 로딩 표시
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // 대화 삭제 실행 - clearConversationWith가 없으므로 deleteMessage로 대체
      // 선택한 사용자와의 대화 메시지 가져오기
      final messages = _messageService.getConversationWith(widget.userId);

      // 모든 메시지 삭제
      if (messages.isNotEmpty) {
        for (final message in messages) {
          await _messageService.deleteMessage(message.id);
        }
      }

      // 로딩 닫기
      Get.back();

      // 성공 메시지
      Get.snackbar(
        '대화 삭제 완료',
        '모든 메시지가 삭제되었습니다',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // 메시지 목록 새로고침
      _refreshMessages();
    } catch (e) {
      // 로딩 닫기
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      // 오류 메시지
      Get.snackbar(
        '대화 삭제 실패',
        '오류: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
