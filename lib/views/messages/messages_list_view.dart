import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../models/message_model.dart';
import 'message_detail_view.dart';

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

    // Firebase에서 데이터 다시 로드
    try {
      await _messageService.refreshMessages();
    } catch (e) {
      debugPrint('⚠️ 메시지 새로고침 오류: $e');
    }

    // 상태 갱신
    if (mounted) {
      setState(() {
        // 대화 목록 새로고침
      });
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

  // 메시지 미리보기 텍스트 만들기
  String _getPreviewText(Message message) {
    if (message.messageType == 'text') {
      // 일반 텍스트 메시지
      return message.content;
    } else if (message.messageType == 'location_request') {
      // 위치 공유 요청
      return '🔍 위치 공유 요청';
    } else if (message.messageType == 'location_share') {
      // 위치 공유
      return '📍 위치 공유됨';
    } else {
      // 기타 메시지 타입
      return message.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메시지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMessages,
          ),
          // 테스트 계정 버튼 추가
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showUserSearchDialog,
            tooltip: '대화 상대 검색',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUserSearchDialog,
        child: const Icon(Icons.edit),
      ),
      body: Builder(
        builder: (context) {
          if (_messageService.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_messageService.hasError.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_messageService.errorMessage.value}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshMessages,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          // 대화 목록 가져오기
          final conversations = _messageService.getConversationList();
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.message, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    '메시지가 없습니다',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '위치 공유 요청이나 메시지를 보내면\n여기에 표시됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showUserSearchDialog,
                    icon: const Icon(Icons.search),
                    label: const Text('대화 상대 검색'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshMessages,
            child: ListView.builder(
              itemCount: conversations.length,
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
                final String otherUserId =
                    isCurrentUserSender ? message.receiverId : message.senderId;

                // 대화 상대 이름
                final otherUserName = _getRecipientName(otherUserId);

                return Dismissible(
                  key: Key('conversation-${message.id}'),
                  background: Container(
                    color: Colors.red,
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
                          content: const Text('이 대화를 삭제하시겠습니까?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('$otherUserName님과의 대화가 삭제되었습니다')),
                      );

                      // 데이터 변경 후 메시지 목록을 갱신하기 위해 인위적으로 새로고침
                      _refreshMessages();
                    } catch (e) {
                      debugPrint('⚠️ 대화 삭제 오류: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('대화 삭제 중 오류가 발생했습니다'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.8),
                      child: Text(
                        otherUserName.substring(0, 1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          _formatDate(message.timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        // 내가 보낸 메시지인 경우 '나: '를 붙임
                        if (isCurrentUserSender)
                          const Text('나: ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            _getPreviewText(message),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!message.isRead && !isCurrentUserSender)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(5),
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
                          debugPrint('⚠️ dynamic ID를 고정 ID로 변환: $targetUserId');
                        }

                        Get.to(() => MessageDetailView(userId: targetUserId));
                      } catch (e) {
                        debugPrint('⚠️ 메시지 상세 화면으로 이동 중 오류: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('메시지 상세 화면을 열 수 없습니다'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              },
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('대화 상대 검색'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '이메일 또는 닉네임 검색',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
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
                  const SizedBox(height: 16),
                  Flexible(
                    child: Obx(() {
                      if (_messageService.isSearching.value) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final results = _messageService.searchResults;
                      if (results.isEmpty) {
                        if (searchController.text.length >= 2) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade400,
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
                            ],
                          );
                        } else {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 48,
                                color: Colors.grey.shade400,
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
                            ],
                          );
                        }
                      }

                      return Scrollbar(
                        controller: scrollController,
                        child: ListView.separated(
                          controller: scrollController,
                          shrinkWrap: true,
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
                                      backgroundColor: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.8),
                                      child: Text(
                                        firstLetter,
                                        style: const TextStyle(
                                            color: Colors.white),
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
                                Navigator.of(context).pop();
                                _startNewConversation(user);
                              },
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
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
    );
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
