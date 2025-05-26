import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/message_model.dart';
import '../../models/shared_location_model.dart'; // SharedLocation 모델
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/message_service.dart';
import '../../utils/url_handler.dart';
import 'shared_location_view.dart';

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
  final LocationService _locationService = Get.find<LocationService>();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 스크롤 위치 유지를 위한 변수 추가
  bool _isUserScrolling = false;
  bool _shouldAutoScroll = true;
  double _lastScrollPosition = 0.0;

  // 스캐폴드 키를 저장할 변수 - dispose에서 안전하게 액세스하기 위함
  ScaffoldMessengerState? _scaffoldMessenger;

  // 사용자 온라인 상태 관련 변수
  Timer? _activityUpdateTimer; // 주기적으로 사용자 활동 업데이트를 위한 타이머
  Timer? _statusCheckTimer; // 상대방 상태 확인 타이머
  final RxString _recipientStatusText = '오프라인'.obs; // 상대방 상태 텍스트
  final Rx<Color> _recipientStatusColor = Colors.grey.obs; // 상대방 상태 색상

  // 검색으로 강조된 마지막 메시지 ID
  String? _lastHighlightedMessageId;

  @override
  void initState() {
    super.initState();

    // 로깅 추가
    debugPrint('🔄 MessageDetailView initState 시작: ${widget.userId}');

    // 스크롤 리스너 추가
    _scrollController.addListener(_handleScrollListener);

    // 화면이 로드되면 즉시 읽지 않은 메시지를 읽음 상태로 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 위젯 생성 직후에만 실행되도록 보장
      if (!mounted) {
        debugPrint('⚠️ 위젯이 이미 dispose되어 초기화를 중단합니다.');
        return;
      }

      try {
        debugPrint('🔄 메시지 화면 초기화 - 대화 상대 ID: ${widget.userId}');

        // 1. 메시지를 읽음 처리하기 전에 먼저 메시지 서비스에서 데이터 확인
        final currentMessages =
            _messageService.getConversationWith(widget.userId);
        debugPrint('📊 초기화 시 현재 메시지 수: ${currentMessages.length}');

        // 2. 먼저 Firebase에서 메시지 새로고침 - 데이터 로드 우선
        _messageService.refreshMessages().then((_) {
          if (!mounted) return;

          // 3. 새로고침 후에 읽음 처리 수행 (새로 로드된 메시지 포함)
          _safelyMarkMessagesAsRead();

          // 4. 스크롤 이동
          _safelyScrollToBottom();
        }).catchError((error) {
          // Firebase 오류 처리
          debugPrint('⚠️ 메시지 새로고침 오류: $error');

          // 권한 오류 확인
          if (error.toString().contains('permission-denied')) {
            _handleFirebasePermissionError();
          }
        });

        // 5. 현재 사용자의 활동 상태 업데이트
        _updateCurrentUserActivity();

        // 6. 상대방의 상태 확인
        _checkRecipientStatus();

        // 7. 주기적으로 현재 사용자의 활동 상태를 업데이트하는 타이머 설정 (1분마다)
        _activityUpdateTimer = Timer.periodic(
            const Duration(minutes: 1), (_) => _updateCurrentUserActivity());

        // 8. 주기적으로 상대방의 상태를 확인하는 타이머 설정 (30초마다)
        _statusCheckTimer = Timer.periodic(
            const Duration(seconds: 30), (_) => _checkRecipientStatus());
      } catch (e) {
        debugPrint('⚠️ 초기화 중 오류 발생: $e');

        // 권한 오류 확인
        if (e.toString().contains('permission-denied')) {
          _handleFirebasePermissionError();
        }
      }
    });

    // 메시지 리스트에 변경이 있을 때마다 UI 업데이트 및 읽음 처리
    ever(_messageService.messages, (_) {
      if (mounted) {
        debugPrint('🔔 메시지 리스트 변경 감지 - UI 업데이트');

        // 읽음 처리는 이미 리스트가 로드된 후에만 처리
        _safelyMarkMessagesAsRead();

        // 사용자가 스크롤 중이거나 스크롤 위치가 하단에서 멀리 떨어져 있다면 자동 스크롤하지 않음
        if (_scrollController.hasClients) {
          if (_shouldAutoScroll) {
            // 사용자가 하단 근처에 있거나 자동 스크롤이 활성화된 경우에만 스크롤
            debugPrint('🔄 메시지 변경 감지 - 자동 스크롤 수행');
            _safelyScrollToBottom();
          } else {
            // 사용자가 위쪽을 보고 있는 경우 스크롤 위치 유지
            debugPrint('🔒 스크롤 위치 유지 - 사용자가 이전 메시지를 보는 중');

            // 지연 후 마지막으로 보던 위치로 복원
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted && _scrollController.hasClients) {
                // 현재 스크롤 위치보다 _lastScrollPosition이 더 크면 (더 아래에 있으면) 해당 위치로 복원
                final currentPos = _scrollController.position.pixels;
                if (_lastScrollPosition > currentPos &&
                    _lastScrollPosition <=
                        _scrollController.position.maxScrollExtent) {
                  _scrollController.jumpTo(_lastScrollPosition);
                  debugPrint('🔄 이전 스크롤 위치로 복원: $_lastScrollPosition');
                }
              }
            });
          }
        } else {
          // 클라이언트가 없는 경우(초기 로딩)에는 스크롤 이동
          _safelyScrollToBottom();
        }
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

    // 타이머 취소
    _activityUpdateTimer?.cancel();
    _statusCheckTimer?.cancel();

    // 스크롤 리스너 제거
    _scrollController.removeListener(_handleScrollListener);

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

  // 스크롤 이벤트 처리 메서드
  void _handleScrollListener() {
    if (!mounted) return;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // 사용자가 스크롤 중인지 확인
      if (_scrollController.position.isScrollingNotifier.value) {
        _isUserScrolling = true;
        _lastScrollPosition = currentScroll;

        // 사용자가 스크롤하는 동안에는 자동 스크롤 비활성화
        // 맨 아래에 가까운 경우에만 자동 스크롤 활성화
        final threshold = maxScroll * 0.95;
        _shouldAutoScroll = currentScroll >= threshold;

        debugPrint(
            '🖱️ 사용자 스크롤 감지: 위치=$currentScroll, 자동스크롤=${_shouldAutoScroll ? '활성화' : '비활성화'}');
      } else {
        // 스크롤이 멈춘 상태
        if (_isUserScrolling) {
          _isUserScrolling = false;
          _lastScrollPosition = currentScroll;
          debugPrint('🖱️ 사용자 스크롤 종료: 위치=$currentScroll');
        }
      }
    }
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

        // 새 메시지 전송 시에는 항상 스크롤을 맨 아래로 이동
        // (사용자가 직접 메시지를 보냈으므로 스크롤을 맨 아래로 이동시키는 것이 자연스러움)
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

    // 스크롤 지연 시간을 더 다양하게 변경하여 여러 시도를 통해 성공률 높임
    for (int delay in [50, 150, 300, 600]) {
      Future.delayed(Duration(milliseconds: delay), () {
        // 딜레이 후 다시 mounted 체크
        if (!mounted) {
          debugPrint('⚠️ 스크롤 시도 시 위젯이 dispose되어 중단');
          return;
        }

        debugPrint('🔄 스크롤 맨 아래로 이동 시도 (delay: ${delay}ms)');
        _scrollToBottom();

        // 마지막 스크롤 시도 후 추가로 한번 더 시도 (일부 장치에서 늦게 렌더링되는 경우 대비)
        if (delay == 600) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              debugPrint('🔄 스크롤 맨 아래로 마지막 추가 이동 시도');
              _scrollToBottom();
            }
          });
        }
      });
    }
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

  // Firebase 권한 오류 처리 메서드
  void _handleFirebasePermissionError() {
    if (!mounted) return;

    // 로컬 전용 모드로 전환
    _messageService.enableLocalOnlyMode();

    // 사용자에게 안내 메시지 표시
    Get.snackbar(
      '서버 연결 제한',
      '메시지 서버 접근 권한이 제한되어 로컬 모드로 작동합니다. 메시지 읽음 상태가 서버에 저장되지 않지만 앱 사용에는 지장이 없습니다.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
      icon: const Icon(Icons.sync_disabled, color: Colors.white),
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      isDismissible: true,
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

      // 위치 서비스 권한 확인 및 실제 위치 가져오기
      _locationService.isLoading.value = true;
      Get.snackbar(
        '위치 확인 중',
        '현재 위치를 확인하는 중입니다...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      await _locationService.getCurrentLocation();

      // 위치 서비스에서 오류가 있는지 확인
      if (_locationService.errorMsg.value.isNotEmpty) {
        throw Exception(_locationService.errorMsg.value);
      }

      // 현재 위치 가져오기
      final currentLatLng = _locationService.currentLocation.value;

      if (currentLatLng == null) {
        throw Exception('현재 위치를 가져올 수 없습니다.');
      }

      final double latitude = currentLatLng.latitude;
      final double longitude = currentLatLng.longitude;

      debugPrint('🔍 실제 GPS 위치 확인됨: $latitude, $longitude');

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
        _showErrorSnackBar('위치 공유 중 오류가 발생했습니다: ${e.toString()}');
      }
    } finally {
      _locationService.isLoading.value = false;
    }
  }

  // 안전하게 메시지 읽음 처리하는 메서드
  Future<void> _safelyMarkMessagesAsRead() async {
    // 메시지 데이터가 로드되었는지 확인
    if (_messageService.messages.isEmpty) {
      debugPrint('⚠️ 메시지 목록이 비어있어 읽음 처리를 연기합니다.');
      return;
    }

    // 충분한 지연 후 읽음 처리 시도
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _markMessagesAsRead();
      }
    });
  }

  // 읽지 않은 메시지를 읽음 상태로 변경
  Future<void> _markMessagesAsRead() async {
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 읽음 상태 변경을 중단합니다.');
      return;
    }

    try {
      final currentUserId = _authService.uid;

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('⚠️ 현재 로그인된 사용자가 없어 읽음 상태 변경을 중단합니다.');
        return;
      }

      // 읽지 않은 메시지만 가져오기
      final unreadMessages = _messageService.messages
          .where((m) =>
              !m.isRead &&
              m.receiverId == currentUserId &&
              m.senderId == widget.userId)
          .toList();

      if (unreadMessages.isEmpty) {
        debugPrint('✅ 읽지 않은 메시지가 없습니다.');
        return;
      }

      debugPrint(
          '🔄 현재 대화 상대의 ${unreadMessages.length}개 읽지 않은 메시지를 읽음 상태로 변경합니다.');

      // 읽지 않은 메시지 ID 목록 추출
      final unreadMessageIds = unreadMessages.map((m) => m.id).toList();

      // 다수의 메시지를 한 번에 처리하는 메서드 사용
      await _messageService.markMultipleMessagesAsRead(unreadMessageIds);

      // 메시지 목록 강제 갱신 (읽음 상태 즉시 반영)
      _messageService.messages.refresh();

      // 읽지 않은 메시지 수 강제 업데이트
      _messageService.updateUnreadCount();

      debugPrint('🔄 읽음 처리 후 UI 업데이트 완료');
    } catch (e) {
      debugPrint('⚠️ 메시지 읽음 상태 변경 오류: $e');
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
      final Map<String, dynamic> result = jsonDecode(content);
      debugPrint('✅ 위치 메시지 파싱 성공: $result');
      return result;
    } catch (e) {
      debugPrint('⚠️ 위치 메시지 파싱 오류: $e');
      return null;
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
        : '사용자 ${userId.substring(0, math.min(userId.length, 8))}';
  }

  // 안전하게 스크롤을 맨 아래로 이동하는 메서드
  void _scrollToBottom() {
    try {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        debugPrint('🔄 스크롤 이동: maxScrollExtent=$maxScroll');

        // 스크롤 위치를 확인하여 즉시 이동할지 애니메이션 이동할지 결정
        if (_scrollController.position.pixels >= maxScroll - 150) {
          // 이미 거의 아래에 있으면 즉시 이동
          _scrollController.jumpTo(maxScroll);
        } else {
          // 그렇지 않으면 애니메이션으로 부드럽게 이동
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        debugPrint('⚠️ 스크롤 컨트롤러에 클라이언트 없음');
        // 클라이언트가 없는 경우 지연 후 다시 시도 (3번까지 재시도)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _scrollToBottom();
        });
      }
    } catch (e) {
      debugPrint('⚠️ 스크롤 이동 중 오류 발생: $e');
      // 오류 발생 시에도 지연 후 다시 시도
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _scrollToBottom();
        });
      }
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

      // Firebase에서 메시지 새로고침 - 타임아웃 처리 추가
      bool refreshCompleted = false;

      // 5초 타임아웃 설정
      Future.delayed(const Duration(seconds: 5), () {
        if (!refreshCompleted && mounted) {
          debugPrint('⚠️ 메시지 새로고침 타임아웃');
          // 타임아웃 처리
          Get.snackbar(
            '새로고침 지연',
            '메시지 로드가 지연되고 있습니다. 잠시 기다려주세요.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange.withOpacity(0.7),
          );
        }
      });

      try {
        await _messageService.refreshMessages();
        refreshCompleted = true;
      } catch (e) {
        refreshCompleted = true;
        if (mounted) {
          Get.snackbar(
            '새로고침 오류',
            '메시지 로드 중 오류가 발생했습니다. 다시 시도해주세요.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red.withOpacity(0.7),
          );
        }
        rethrow; // 상위 catch 블록에서 처리
      }

      if (!mounted) return;

      // 새로고침 후 메시지 개수 확인
      final afterCount =
          _messageService.getConversationWith(widget.userId).length;
      final int diff = afterCount - beforeCount;

      // 읽음 상태 처리 (적은 양의 메시지만 있는 경우)
      if (afterCount <= 50) {
        // 적은 양의 메시지는 즉시 처리
        _markMessagesAsRead();
      } else {
        // 많은 양의 메시지는 지연 처리
        _safelyMarkMessagesAsRead();
      }

      // 마지막 읽은 위치 기억을 위해 현재 스크롤 위치 확인
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        final threshold = maxScroll * 0.9; // 스크롤이 90% 이상 내려간 경우에만 자동 스크롤

        if (currentScroll >= threshold) {
          // 사용자가 이미 하단 근처에 있을 때만 자동 스크롤
          _safelyScrollToBottom();
        } else {
          debugPrint('🔒 새로고침 후 스크롤 위치 유지: 사용자가 위쪽을 보고 있습니다.');
          // 현재 스크롤 위치의 비율을 계산하여 새로고침 후에도 동일한 비율 유지
          final scrollRatio = maxScroll > 0 ? currentScroll / maxScroll : 0;

          // 약간의 지연 후 스크롤 위치 복원 (새로운 콘텐츠 렌더링을 위한 시간 확보)
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              // 새 maxScroll 기준으로 동일한 비율의 위치로 스크롤
              final newMaxScroll = _scrollController.position.maxScrollExtent;
              final newPosition = scrollRatio * newMaxScroll;
              _scrollController.jumpTo(newPosition.clamp(0.0, newMaxScroll));
            }
          });
        }
      } else {
        // 클라이언트가 없는 경우(초기 로딩)에는 스크롤 이동
        _safelyScrollToBottom();
      }

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
                  Obx(() => Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _recipientStatusColor.value,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _recipientStatusText.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: _recipientStatusColor.value,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 이미지 공유 버튼 추가
          // IconButton(
          //   icon: const Icon(Icons.image),
          //   color: Colors.purple.shade400,
          //   onPressed: _sendImageMessage,
          //   tooltip: '이미지 공유',
          // ),
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
          // PopupMenuButton<String>(
          //   icon: const Icon(Icons.more_vert),
          //   onSelected: (value) {
          //     if (value == 'clear') {
          //       _showClearConversationDialog();
          //     }
          //   },
          //   itemBuilder: (context) => [
          //     const PopupMenuItem<String>(
          //       value: 'clear',
          //       child: Row(
          //         children: [
          //           Icon(Icons.delete_outline, color: Colors.red),
          //           SizedBox(width: 8),
          //           Text('대화 삭제'),
          //         ],
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // 채팅 배경 패턴 추가
          color: Colors.blue.shade50,
          image: DecorationImage(
            image: const NetworkImage(
              'https://i.pinimg.com/originals/97/c0/07/97c00759d90d786d9b6096d274ad3e07.png',
            ),
            opacity: 0.07,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // 스크롤 가능한 최소 영역을 확보하기 위한 투명한 컨테이너
                          Container(
                            height: constraints.maxHeight,
                            color: Colors.transparent,
                          ),
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            // 항상 스크롤 가능하도록 설정 + 바운스 효과 활성화 (더 자연스러운 스크롤 느낌 제공)
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(
                                decelerationRate: ScrollDecelerationRate.fast,
                              ),
                            ),
                            // 리스트 아이템 간 공간을 확보하여 메시지 겹침 방지
                            itemExtent: null, // 가변 높이로 설정하여 메시지가 겹치지 않게 함
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
                                isCurrentUserSender =
                                    message.senderId == currentUserId;
                              } catch (e) {
                                debugPrint('⚠️ 발신자 확인 오류: $e');
                              }

                              return Column(
                                children: [
                                  // 날짜 구분선
                                  if (showDateSeparator)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _formatMessageDate(
                                                message.timestamp),
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
                                      child: const Icon(Icons.delete,
                                          color: Colors.white),
                                    ),
                                    secondaryBackground: Container(
                                      color: Colors.blue.shade400,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(Icons.reply,
                                          color: Colors.white),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        // 왼쪽으로 스와이프: 삭제
                                        final bool? result =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('메시지 삭제'),
                                              content: const Text(
                                                  '이 메시지를 삭제하시겠습니까?'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('취소'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
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
                                        _messageService
                                            .setReplyToMessage(message);
                                        return false; // Dismissible 효과는 보이지 않도록
                                      }
                                      return false;
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        // 메시지 클릭 시 답장 모드
                                        _messageService
                                            .setReplyToMessage(message);
                                      },
                                      child: _buildMessageItem(
                                          message, isCurrentUserSender),
                                    ),
                                  ),
                                ],
                              );
                            },
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
    // 검색으로 찾은 메시지인지 확인
    final bool isHighlighted = _lastHighlightedMessageId == message.id;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 지도에서 보기 버튼
                    GestureDetector(
                      onTap: () => _openInExternalMap(locationData),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUserSender
                              ? Colors.white.withOpacity(0.25)
                              : Colors.teal.shade800.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                    ),

                    // 내 지도에 저장 버튼 추가
                    GestureDetector(
                      onTap: () => _saveLocationToMap(
                          message, locationData, isCurrentUserSender),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUserSender
                              ? Colors.white.withOpacity(0.25)
                              : Colors.teal.shade800.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_outline,
                              size: 16,
                              color: isCurrentUserSender
                                  ? Colors.white
                                  : Colors.teal.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '지도에 저장',
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      } else {
        // 위치 정보 파싱 실패 시 기본 텍스트 표시
        messageContent = Text(
          '위치 정보를 표시할 수 없습니다',
          style: TextStyle(
            color: isCurrentUserSender ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        );
      }
    } else if (message.messageType == 'sos') {
      // SOS 메시지 포매팅 및 지도 버튼
      // 위치 정보 파싱 시도
      final RegExp latLngReg = RegExp(r'위도: ([0-9.\-]+)\n경도: ([0-9.\-]+)');
      final match = latLngReg.firstMatch(message.content);
      double? latitude;
      double? longitude;
      if (match != null && match.groupCount == 2) {
        latitude = double.tryParse(match.group(1)!);
        longitude = double.tryParse(match.group(2)!);
      }
      // 주소 추출
      String? address;
      final addressReg = RegExp(r'주소: (.+)');
      final addressMatch = addressReg.firstMatch(message.content);
      if (addressMatch != null && addressMatch.groupCount == 1) {
        address = addressMatch.group(1);
      }
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text('SOS 긴급 메시지',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              color: isCurrentUserSender ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // 내부 지도에서 위치 보기 (SharedLocationView 사용)
                  try {
                    // 위치 정보가 있으면 내부 지도 화면으로 이동
                    Get.to(
                      () => SharedLocationView(
                        latitude: latitude!,
                        longitude: longitude!,
                        message: 'SOS 긴급 상황 위치',
                        timestamp: message.timestamp,
                        senderName: message.senderId == _authService.uid
                            ? '나'
                            : _getRecipientName(message.senderId),
                        address: address,
                        fromMessageDetail: true,
                      ),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 300),
                    );

                    // 성공 알림
                    Get.snackbar(
                      '위치 보기',
                      '앱 내부 지도에서 위치를 확인합니다',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green.shade600,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                    );
                  } catch (e) {
                    debugPrint('⚠️ 지도 화면 열기 오류: $e');
                    Get.snackbar(
                      '오류',
                      '지도 화면을 열 수 없습니다',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red.shade600,
                      colorText: Colors.white,
                    );
                  }
                },
                icon: const Icon(Icons.map, size: 18),
                label: const Text('지도에서 위치 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      );
    } else if (message.messageType == 'arrival_notification' ||
        message.messageType == 'location_arrival') {
      // 귀가 알림 메시지 파싱 및 표시
      final arrivalData = _parseArrivalNotificationMessage(message.content);

      if (arrivalData != null) {
        messageContent = GestureDetector(
          onTap: () {
            // 위치 정보가 있는 경우 지도 화면으로 이동
            _openArrivalLocation(message, arrivalData, isCurrentUserSender);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCurrentUserSender
                    ? [Colors.indigo.shade700, Colors.indigo.shade500]
                    : [Colors.blue.shade200, Colors.blue.shade100],
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
                      Icons.home_filled,
                      size: 22,
                      color: isCurrentUserSender
                          ? Colors.white
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '귀가 알림',
                        style: TextStyle(
                          color: isCurrentUserSender
                              ? Colors.white
                              : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  arrivalData['message'] ?? '안전하게 귀가했습니다',
                  style: TextStyle(
                    color: isCurrentUserSender
                        ? Colors.white
                        : Colors.blue.shade800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                // 주소 표시
                if (arrivalData['address'] != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: isCurrentUserSender
                            ? Colors.white.withOpacity(0.9)
                            : Colors.blue.shade800.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          arrivalData['address'],
                          style: TextStyle(
                            color: isCurrentUserSender
                                ? Colors.white.withOpacity(0.9)
                                : Colors.blue.shade800.withOpacity(0.8),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                // 위치 이름 표시
                if (arrivalData['name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.home,
                          size: 14,
                          color: isCurrentUserSender
                              ? Colors.white.withOpacity(0.9)
                              : Colors.blue.shade800.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          arrivalData['name'],
                          style: TextStyle(
                            color: isCurrentUserSender
                                ? Colors.white.withOpacity(0.9)
                                : Colors.blue.shade800.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // 지도에서 보기 버튼
                Center(
                  child: GestureDetector(
                    onTap: () => _openInExternalMap({
                      'latitude': arrivalData['latitude'],
                      'longitude': arrivalData['longitude'],
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isCurrentUserSender
                            ? Colors.white.withOpacity(0.25)
                            : Colors.blue.shade800.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map,
                            size: 16,
                            color: isCurrentUserSender
                                ? Colors.white
                                : Colors.blue.shade800,
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
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // 데이터 파싱 실패 시 기본 텍스트 표시
        messageContent = Text(
          '귀가 알림 정보를 표시할 수 없습니다',
          style: TextStyle(
            color: isCurrentUserSender ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        );
      }
    } else if (message.messageType == 'location_sharing') {
      // 위치 공유 시작/중지 메시지
      final data = message.data;
      final isStarting = message.extra?['action'] == 'start';
      final locationId = message.extra?['locationId'];
      final senderName =
          isCurrentUserSender ? '나' : _getRecipientName(message.senderId);

      messageContent = Container(
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
            // 메시지 제목 및 아이콘
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isStarting ? Icons.location_on : Icons.location_off,
                  size: 22,
                  color:
                      isCurrentUserSender ? Colors.white : Colors.teal.shade800,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isStarting
                        ? '$senderName님이 위치 공유를 시작했습니다.'
                        : '$senderName님이 위치 공유를 중지했습니다.',
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

            // 위치 정보 (위치 공유 시작 메시지인 경우에만 표시)
            if (isStarting && locationId != null) ...[
              const SizedBox(height: 8),

              // 지도에서 보기 버튼
              GestureDetector(
                onTap: () => _navigateToLocationTracking(
                    message.senderId, locationId, senderName),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isCurrentUserSender
                        ? Colors.white.withOpacity(0.25)
                        : Colors.teal.shade800.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 18,
                        color: isCurrentUserSender
                            ? Colors.white
                            : Colors.teal.shade800,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '지도에서 실시간 위치 보기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUserSender
                              ? Colors.white
                              : Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // 기타 타입의 메시지
      messageContent = Text(
        message.content,
        style: TextStyle(
          color: isCurrentUserSender ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }

    return Row(
      mainAxisAlignment:
          isCurrentUserSender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isCurrentUserSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // 상대방 메시지인 경우 발신자 이름 표시
              if (!isCurrentUserSender)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(
                    _getRecipientName(message.senderId),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // 실제 메시지 컨텐츠 컨테이너
              GestureDetector(
                onTap: () {
                  // 일반 텍스트 메시지인 경우만 링크 감지
                  if (message.messageType == 'text') {
                    _handleTextWithLinks(message.content);
                  }

                  // 위치 공유 메시지인 경우 기존 동작 유지
                  if (message.messageType == 'location_share') {
                    final locationData = _parseLocationMessage(message.content);
                    if (locationData != null) {
                      _openSharedLocation(
                          message, locationData, isCurrentUserSender);
                    }
                  }
                },
                child: Container(
                  padding: message.messageType == 'location_share' ||
                          message.messageType == 'location_sharing'
                      ? EdgeInsets.zero // 위치 공유는 자체 패딩 있음
                      : const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                  decoration: message.messageType == 'location_share' ||
                          message.messageType == 'location_sharing'
                      ? null // 위치 공유는 자체 장식 있음
                      : BoxDecoration(
                          color: isHighlighted
                              ? (isCurrentUserSender
                                  ? Colors.blue.shade800 // 강조된 내 메시지
                                  : Colors.amber.shade100) // 강조된 상대 메시지
                              : (isCurrentUserSender
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade100),
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
                              color: isHighlighted
                                  ? (isCurrentUserSender
                                      ? Colors.blue.shade900.withOpacity(0.3)
                                      : Colors.amber.shade300.withOpacity(0.5))
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: isHighlighted ? 8 : 3,
                              spreadRadius: isHighlighted ? 2 : 0,
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
                      if (message.messageType != 'location_share' &&
                          message.messageType != 'location_sharing')
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
              ),

              // 위치 공유 메시지는 시간 표시를 아래에 별도로
              if (message.messageType == 'location_share' ||
                  message.messageType == 'location_sharing')
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
      ],
    );
  }

  // 위치 추적 화면으로 이동
  void _navigateToLocationTracking(
      String userId, String locationId, String contactName) {
    print('🗺️ [메시지] 위치 추적 화면으로 이동: userId=$userId, locationId=$locationId');

    // 위치 추적 화면으로 이동
    Get.toNamed('/location-tracking', arguments: {
      'userId': userId,
      'contactName': contactName,
      'locationId': locationId,
    });
  }

  // 지도 앱에서 바로 열기
  void _openInExternalMap(Map<String, dynamic> locationData) {
    try {
      final double latitude = double.parse(locationData['latitude'].toString());
      final double longitude =
          double.parse(locationData['longitude'].toString());

      // 지도 앱 열기 - iOS는 Apple Maps, Android는 Google Maps
      final String url = defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://maps.apple.com/?ll=$latitude,$longitude'
          : 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ 외부 지도 앱 열기 오류: $e');
      Get.snackbar(
        '오류',
        '지도를 열 수 없습니다',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // 귀가 알림 위치 정보를 지도에서 표시
  void _openArrivalLocation(Message message, Map<String, dynamic> arrivalData,
      bool isCurrentUserSender) {
    if (!mounted) return;

    try {
      final double latitude = double.parse(arrivalData['latitude'].toString());
      final double longitude =
          double.parse(arrivalData['longitude'].toString());
      final String address = arrivalData['address'] ?? '위치 정보 없음';
      final String locationName = arrivalData['name'] ?? '귀가 위치';

      // 발신자 이름 결정
      final String senderName =
          isCurrentUserSender ? '나' : _getRecipientName(message.senderId);

      // 지도 화면으로 이동
      Get.to(
        () => SharedLocationView(
          latitude: latitude,
          longitude: longitude,
          message: '${senderName}님의 귀가 위치',
          timestamp: message.timestamp,
          senderName: senderName,
          address: address,
          locationName: locationName,
          fromMessageDetail: true,
        ),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      debugPrint('⚠️ 귀가 알림 위치 표시 오류: $e');
      Get.snackbar(
        '오류',
        '귀가 위치를 표시할 수 없습니다',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
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
          fromMessageDetail: true, // 메시지 디테일에서 직접 넘어온 경우
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
    if (!mounted) return;

    // 시작할 때 현재 대화 메시지 목록 미리 가져오기
    final List<Message> messagesSnapshot =
        List.from(_messageService.getConversationWith(widget.userId));

    // 간단한 문자열 변수만 사용
    String searchQuery = '';

    // 지역 변수로 선언하여 dialog가 닫힐 때 자동으로 정리되도록 함
    List<Message> filteredMessages = [];
    int selectedIndex = -1;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            // 검색 실행하는 함수
            void performSearch(String query) {
              searchQuery = query.trim().toLowerCase();
              if (searchQuery.isEmpty) {
                setDialogState(() {
                  filteredMessages = [];
                  selectedIndex = -1;
                });
                return;
              }

              // 미리 가져온 메시지 목록에서 필터링
              setDialogState(() {
                filteredMessages = messagesSnapshot
                    .where((msg) =>
                        msg.content.toLowerCase().contains(searchQuery))
                    .toList();
                selectedIndex = -1;
              });
            }

            // 이전/다음 검색 결과로 이동하는 함수
            void navigateSearchResults(bool next) {
              if (filteredMessages.isEmpty) return;

              setDialogState(() {
                if (next) {
                  // 다음 검색 결과
                  selectedIndex = (selectedIndex + 1) % filteredMessages.length;
                } else {
                  // 이전 검색 결과
                  selectedIndex = selectedIndex <= 0
                      ? filteredMessages.length - 1
                      : selectedIndex - 1;
                }
              });
            }

            return AlertDialog(
              title: const Text('대화 검색', style: TextStyle(fontSize: 18)),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // 검색창 - controller 없이 onChanged만 사용
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '검색어 입력...',
                        prefixIcon:
                            Icon(Icons.search, color: Colors.blue.shade700),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        // 검색어 지우기 버튼 추가
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setDialogState(() {
                                    searchQuery = '';
                                    filteredMessages = [];
                                    selectedIndex = -1;
                                  });
                                },
                              )
                            : null,
                      ),
                      // controller를 사용하지 않고 직접 값 처리
                      onChanged: performSearch,
                    ),

                    // 검색 결과 수와 네비게이션 버튼
                    if (filteredMessages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              '${filteredMessages.length}개 결과 찾음',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            // 이전 버튼
                            IconButton(
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: filteredMessages.length > 1
                                  ? () => navigateSearchResults(false)
                                  : null,
                              tooltip: '이전 결과',
                              iconSize: 20,
                            ),
                            // 다음 버튼
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              onPressed: filteredMessages.length > 1
                                  ? () => navigateSearchResults(true)
                                  : null,
                              tooltip: '다음 결과',
                              iconSize: 20,
                            ),
                          ],
                        ),
                      ),

                    // 선택된 결과 정보
                    if (selectedIndex >= 0 && filteredMessages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '결과 ${selectedIndex + 1}/${filteredMessages.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // 검색 결과
                    Expanded(
                      child: searchQuery.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text('검색어를 입력하세요',
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : filteredMessages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off,
                                          size: 48,
                                          color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text('검색 결과가 없습니다',
                                          style: TextStyle(
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = filteredMessages[index];
                                    final isFromMe =
                                        message.senderId == _authService.uid;

                                    // 현재 선택된 항목 강조 표시
                                    final isSelected = index == selectedIndex;

                                    // 결과 항목
                                    return InkWell(
                                      onTap: () {
                                        // 선택된 메시지 ID 저장
                                        final messageId = message.id;
                                        // 선택 상태 업데이트
                                        setDialogState(() {
                                          selectedIndex = index;
                                        });

                                        // 메시지 ID로 스크롤 (대화창은 그대로 유지)
                                        _scrollToMessageById(messageId);
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.shade100
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
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
                                            message.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _formatMessageTime(
                                                message.timestamp),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          trailing: isSelected
                                              ? Icon(
                                                  Icons.check_circle,
                                                  color: Colors.blue.shade700,
                                                  size: 18,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
                if (selectedIndex >= 0 && filteredMessages.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('보기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final messageId = filteredMessages[selectedIndex].id;
                      Navigator.of(context).pop();
                      _scrollToMessageById(messageId);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ID로 메시지 찾아서 스크롤하는 함수
  void _scrollToMessageById(String messageId) {
    if (!mounted) return;

    try {
      final messages = _messageService.getConversationWith(widget.userId);
      final index = messages.indexWhere((m) => m.id == messageId);

      if (index != -1) {
        // 자동 스크롤 기능 임시 비활성화
        _shouldAutoScroll = false;

        // 메시지 위치로 스크롤하기 위한 지연
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted || !_scrollController.hasClients) return;

          try {
            // 각 메시지 항목의 예상 높이 (실제로는 다양할 수 있음)
            const estimatedMessageHeight = 80.0;
            // 날짜 구분선이 있는 경우 추가 높이
            const estimatedDateSeparatorHeight = 40.0;

            // 해당 메시지 항목의 대략적인 스크롤 위치 계산
            // 이전 메시지들의 높이 합산 + 약간의 여유 공간
            var scrollPosition = index * estimatedMessageHeight;

            // 몇 개의 날짜 구분선이 있을지 대략적으로 추정
            final distinctDates = messages
                .take(index + 1)
                .map((m) => DateTime(
                        m.timestamp.year, m.timestamp.month, m.timestamp.day)
                    .toString())
                .toSet()
                .length;

            scrollPosition += distinctDates * estimatedDateSeparatorHeight;

            // 스크롤 위치가 최대값을 넘지 않도록 제한
            final maxScrollExtent = _scrollController.position.maxScrollExtent;
            final clampedPosition = scrollPosition.clamp(0.0, maxScrollExtent);

            // 메시지 항목이 화면 중앙에 오도록 추가 오프셋 계산
            final screenCenter =
                _scrollController.position.viewportDimension / 2;
            final targetPosition =
                (clampedPosition - screenCenter).clamp(0.0, maxScrollExtent);

            // 스크롤 애니메이션
            _scrollController.animateTo(
              targetPosition,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );

            // 스크롤 후 위치 저장
            _lastScrollPosition = targetPosition;

            // 검색된 메시지 강조 표시 (지연 후)
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                _highlightMessage(messageId);
              }
            });

            // 메시지 찾았다고 알려주기
            Get.snackbar(
              '메시지 찾음',
              '${index + 1}/${messages.length}번째 메시지입니다',
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue.shade700,
              colorText: Colors.white,
            );
          } catch (e) {
            debugPrint('⚠️ 스크롤 오류: $e');
          }
        });
      } else {
        Get.snackbar(
          '메시지 찾기 오류',
          '해당 메시지를 찾을 수 없습니다',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade400,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('⚠️ 메시지 ID로 스크롤 오류: $e');
    }
  }

  // 검색된 메시지 강조 표시
  void _highlightMessage(String messageId) {
    // 임시로 ID 저장 (Widget Tree에서 해당 메시지 식별용)
    _lastHighlightedMessageId = messageId;

    // 화면 갱신
    setState(() {});

    // 3초 후 강조 표시 제거
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _lastHighlightedMessageId == messageId) {
        _lastHighlightedMessageId = null;
        setState(() {});
      }
    });
  }

  // 대화 삭제 확인 다이얼로그
  void _showClearConversationDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('대화 삭제'),
          content: const Text('정말로 이 대화를 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                // 대화 삭제 로직 구현
                debugPrint('대화 삭제');
                Navigator.of(context).pop();
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  // 사진/이미지 공유 기능 추가
  Future<void> _sendImageMessage() async {
    // 먼저 mounted 체크
    if (!mounted) {
      debugPrint('⚠️ 위젯이 이미 dispose되어 이미지 공유를 중단합니다.');
      return;
    }

    // 기능 준비 중 메시지 표시
    Get.snackbar(
      '기능 준비 중',
      '이미지 공유 기능은 현재 준비 중입니다.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  // 이미지 타입 메시지 파싱
  Map<String, dynamic>? _parseImageMessage(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ 이미지 메시지 파싱 오류: $e');
      return null;
    }
  }

  // 현재 사용자의 활동 상태 업데이트
  Future<void> _updateCurrentUserActivity() async {
    if (!mounted) return;

    try {
      await _authService.updateUserActivity();
    } catch (e) {
      debugPrint('⚠️ 사용자 활동 상태 업데이트 중 오류: $e');
    }
  }

  // 상대방의 상태 확인
  Future<void> _checkRecipientStatus() async {
    if (!mounted) return;

    try {
      // 상대방의 마지막 활동 시간 조회
      final lastActive = await _authService.getUserLastActive(widget.userId);

      // 상태 텍스트와 색상 업데이트
      if (mounted) {
        _recipientStatusText.value =
            _authService.getUserOnlineStatusText(lastActive);
        _recipientStatusColor.value =
            _authService.getUserOnlineStatusColor(lastActive);
      }
    } catch (e) {
      debugPrint('⚠️ 상대방 상태 확인 중 오류: $e');
    }
  }

  // 링크를 탐지하고 처리하는 메서드
  void _handleTextWithLinks(String text) {
    if (!mounted) return;

    try {
      // URL 패턴 - Google Maps URL 포함
      final RegExp urlPattern = RegExp(
        r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
        caseSensitive: false,
      );

      final matches = urlPattern.allMatches(text);
      if (matches.isNotEmpty) {
        for (final match in matches) {
          final url = text.substring(match.start, match.end);

          // 특별히 Google Maps URL인지 확인
          if (url.contains('maps.google.com') ||
              url.contains('google.com/maps')) {
            // Watch Over 앱 내에서 열기
            _showOpenInAppMapDialog(url);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ 링크 처리 오류: $e');
    }
  }

  // Google Maps URL 앱 내에서 열기 제안 다이얼로그
  void _showOpenInAppMapDialog(String url) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('지도 링크 감지'),
        content: const Text('Google Maps 링크가 감지되었습니다. Watch Over 앱에서 열겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 외부 브라우저에서 열기
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('브라우저에서 열기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // URL 처리기로 앱 내에서 열기
              UrlHandler.handleUrl(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('앱에서 보기'),
          ),
        ],
      ),
    );
  }

  // 귀가 알림 메시지 파싱
  Map<String, dynamic>? _parseArrivalNotificationMessage(String content) {
    try {
      // JSON 형식인지 확인
      if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
        final Map<String, dynamic> result = jsonDecode(content);
        debugPrint('✅ 귀가 알림 메시지 파싱 성공: $result');
        return result;
      } else {
        // JSON 형식이 아닌 경우 기본 데이터 반환
        debugPrint('⚠️ 귀가 알림 메시지가 JSON 형식이 아닙니다: $content');
        return {
          'message': content,
          'latitude': 0.0,
          'longitude': 0.0,
          'name': '알 수 없는 위치',
          'address': '위치 정보 없음',
        };
      }
    } catch (e) {
      debugPrint('⚠️ 귀가 알림 메시지 파싱 오류: $e');
      debugPrint('⚠️ 오류가 발생한 메시지 내용: $content');

      // 오류 발생 시 기본 데이터 반환
      return {
        'message': '귀가 알림 메시지',
        'latitude': 0.0,
        'longitude': 0.0,
        'name': '알 수 없는 위치',
        'address': '위치 정보를 불러올 수 없습니다',
      };
    }
  }

  // 위치를 지도에 저장
  Future<void> _saveLocationToMap(Message message,
      Map<String, dynamic> locationData, bool isCurrentUserSender) async {
    try {
      // 진동 피드백
      HapticFeedback.mediumImpact();

      // 공유 위치 저장 모델 생성
      final sharedLocation = SharedLocation(
        id: const Uuid().v4(),
        senderId: message.senderId,
        receiverId: _authService.uid ?? '', // 현재 사용자를 수신자로 설정
        latitude: double.parse(locationData['latitude'].toString()),
        longitude: double.parse(locationData['longitude'].toString()),
        timestamp: message.timestamp,
        isActive: true, // 활성 상태로 설정
        startTime: DateTime.now(), // 현재 시간을 시작 시간으로 설정
        message: locationData['message'] ?? '공유된 위치',
        senderName:
            isCurrentUserSender ? '나' : _getRecipientName(message.senderId),
      );

      // 위치 서비스에 저장
      final success = await _locationService.saveSharedLocation(sharedLocation);

      if (success && mounted) {
        Get.snackbar(
          '저장 완료',
          '위치가 지도에 저장되었습니다. 지도 메뉴에서 확인할 수 있습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(8),
          borderRadius: 8,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '저장 실패',
          '위치를 지도에 저장하지 못했습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(8),
          borderRadius: 8,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('⚠️ 위치 저장 오류: $e');

      if (mounted) {
        Get.snackbar(
          '저장 오류',
          '위치를 저장하는 중 오류가 발생했습니다',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(8),
          borderRadius: 8,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }
}
