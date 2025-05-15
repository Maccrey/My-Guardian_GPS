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
    // 이미 MessageService의 onInit에서 메시지를 불러오므로 별도 작업 불필요
    // 하지만 수동 새로고침 필요 시 해당 메소드를 호출
    debugPrint('🔄 메시지 목록 새로고침');
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        child: const Icon(Icons.edit),
      ),
      body: Obx(() {
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

        final conversations = _messageService.getConversationList();
        if (conversations == null) {
          debugPrint('⚠️ 대화 목록이 null입니다');
          return const Center(
            child: Text('메시지를 불러올 수 없습니다'),
          );
        }

        if (conversations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '메시지가 없습니다',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  '위치 공유 요청이나 메시지를 보내면\n여기에 표시됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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
              final isCurrentUserSender =
                  currentUserUid != null && message.senderId == currentUserUid;

              // 대화 상대 ID
              final otherUserId =
                  isCurrentUserSender ? message.receiverId : message.senderId;

              // 대화 상대 이름
              final otherUserName = _getRecipientName(otherUserId);

              return ListTile(
                leading: CircleAvatar(
                  child: Text(otherUserName.substring(0, 1)),
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
                    Get.to(() => MessageDetailView(userId: otherUserId));
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
              );
            },
          ),
        );
      }),
    );
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
