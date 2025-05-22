import 'package:cloud_firestore/cloud_firestore.dart';

/// 위치 공유 관련 메시지 모델
class LocationMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String type;
  final String action; // 'start' 또는 'stop'
  final String? locationId;
  final DateTime timestamp;
  final bool isRead;

  LocationMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.action,
    this.locationId,
    required this.timestamp,
    required this.isRead,
  });

  /// Firestore 문서에서 LocationMessage 객체 생성
  factory LocationMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LocationMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'location_sharing',
      action: data['action'] ?? 'unknown',
      locationId: data['locationId'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  /// LocationMessage 객체를 Firestore에 저장할 수 있는 Map으로 변환
  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type,
      'action': action,
      'locationId': locationId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  /// 메시지 읽음 상태 변경
  LocationMessage copyWithReadStatus(bool readStatus) {
    return LocationMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: type,
      action: action,
      locationId: locationId,
      timestamp: timestamp,
      isRead: readStatus,
    );
  }
}
