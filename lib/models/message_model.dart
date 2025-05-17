import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final String messageType; // 'text', 'location_request', 'location_share' 등
  final String? replyToMessageId; // 답장 메시지 ID

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.replyToMessageId,
  });

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'messageType': messageType,
      'replyToMessageId': replyToMessageId,
    };
  }

  // JSON에서 객체 생성 (안전한 버전)
  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      // 필수 필드 확인
      if (json['id'] == null) {
        throw FormatException('Missing required field: id');
      }
      if (json['senderId'] == null) {
        throw FormatException('Missing required field: senderId');
      }
      if (json['receiverId'] == null) {
        throw FormatException('Missing required field: receiverId');
      }

      // 타임스탬프 처리
      DateTime timestamp;
      try {
        if (json['timestamp'] is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
        } else if (json['timestamp'] is String) {
          // 문자열 타임스탬프 처리 시도
          timestamp = DateTime.parse(json['timestamp']);
        } else {
          // 타임스탬프가 없거나 인식할 수 없는 형식이면 현재 시간 사용
          timestamp = DateTime.now();
        }
      } catch (e) {
        // 타임스탬프 변환 오류시 현재 시간 사용
        timestamp = DateTime.now();
      }

      // 나머지 필드는 기본값 제공
      return Message(
        id: json['id'],
        senderId: json['senderId'],
        receiverId: json['receiverId'],
        content: json['content'] ?? '',
        timestamp: timestamp,
        isRead: json['isRead'] ?? false,
        messageType: json['messageType'] ?? 'text',
        replyToMessageId: json['replyToMessageId'],
      );
    } catch (e) {
      // 포맷 오류시 예외 발생
      throw FormatException('Invalid message format: $e');
    }
  }

  // Firestore 문서로부터 객체 생성 (안전한 버전)
  factory Message.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      // 타임스탬프 처리
      DateTime timestamp;
      try {
        if (data['timestamp'] is Timestamp) {
          timestamp = (data['timestamp'] as Timestamp).toDate();
        } else if (data['timestamp'] is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        } else {
          timestamp = DateTime.now();
        }
      } catch (e) {
        // 타임스탬프 변환 오류시 현재 시간 사용
        timestamp = DateTime.now();
      }

      return Message(
        id: doc.id,
        senderId: data['senderId'] ?? '',
        receiverId: data['receiverId'] ?? '',
        content: data['content'] ?? '',
        timestamp: timestamp,
        isRead: data['isRead'] ?? false,
        messageType: data['messageType'] ?? 'text',
        replyToMessageId: data['replyToMessageId'],
      );
    } catch (e) {
      // 포맷 오류시 예외 발생
      throw FormatException('Invalid Firestore document format: $e');
    }
  }

  // 읽음 상태 변경 복사본 생성
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? messageType,
    String? replyToMessageId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      messageType: messageType ?? this.messageType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    );
  }

  // 디버깅용 문자열 표현
  @override
  String toString() {
    return 'Message{id: $id, senderId: $senderId, receiverId: $receiverId, content: ${content.length > 20 ? content.substring(0, 20) + "..." : content}, timestamp: $timestamp, isRead: $isRead, messageType: $messageType, replyToMessageId: $replyToMessageId}';
  }
}
