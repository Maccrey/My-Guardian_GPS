import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 메시지를 통해 공유된 위치 정보를 저장하는 모델 클래스
class SharedLocationModel {
  final String id; // 고유 ID
  final String senderId; // 보낸 사람 ID
  final String senderName; // 보낸 사람 이름
  final double latitude; // 위도
  final double longitude; // 경도
  final String message; // 위치에 대한 메시지
  final DateTime timestamp; // 공유 시간
  final String messageId; // 관련 메시지 ID (원본 메시지 참조용)

  SharedLocationModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.latitude,
    required this.longitude,
    required this.message,
    required this.timestamp,
    required this.messageId,
  });

  // LatLng 객체로 변환
  LatLng toLatLng() => LatLng(latitude, longitude);

  // 파이어스토어 데이터로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'timestamp': timestamp,
      'messageId': messageId,
    };
  }

  // 파이어스토어 데이터에서 생성
  factory SharedLocationModel.fromJson(Map<String, dynamic> json) {
    return SharedLocationModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      message: json['message'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      messageId: json['messageId'] as String,
    );
  }

  // Firestore DocumentSnapshot에서 생성
  factory SharedLocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SharedLocationModel(
      id: doc.id,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      message: data['message'] as String,
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      messageId: data['messageId'] as String,
    );
  }

  @override
  String toString() {
    return 'SharedLocationModel(id: $id, senderId: $senderId, senderName: $senderName, '
        'coordinates: ($latitude, $longitude), message: $message, timestamp: $timestamp)';
  }
}
