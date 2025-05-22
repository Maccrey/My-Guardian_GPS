import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 메시지를 통해 공유된 위치 정보를 저장하는 모델 클래스
class SharedLocation {
  final String id;
  final String senderId;
  final String receiverId;
  final String receiverType; // 'user' 또는 'emergency_contact'
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isActive;
  final DateTime startTime;
  final DateTime? endTime;
  final String message; // 위치 공유 메시지
  final String senderName; // 발신자 이름

  SharedLocation({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.receiverType = 'emergency_contact', // 기본값은 emergency_contact
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isActive,
    required this.startTime,
    this.endTime,
    this.message = '', // 기본값 추가
    this.senderName = '', // 기본값 추가
  });

  // LatLng 객체로 변환
  LatLng toLatLng() => LatLng(latitude, longitude);

  // SharedLocation을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'receiverType': receiverType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isActive': isActive,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'message': message, // 추가
      'senderName': senderName, // 추가
    };
  }

  // JSON에서 SharedLocation으로 변환
  factory SharedLocation.fromJson(Map<String, dynamic> json) {
    return SharedLocation(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      receiverType: json['receiverType'] ?? 'emergency_contact',
      latitude: json['latitude'],
      longitude: json['longitude'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isActive: json['isActive'],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'])
          : null,
      message: json['message'] ?? '', // 추가
      senderName: json['senderName'] ?? '', // 추가
    );
  }

  // Firestore DocumentSnapshot에서 SharedLocation으로 변환
  factory SharedLocation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SharedLocation(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverType: data['receiverType'] ?? 'emergency_contact',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['timestamp']))
          : DateTime.now(),
      isActive: data['isActive'] ?? false,
      startTime: data['startTime'] != null
          ? (data['startTime'] is Timestamp
              ? (data['startTime'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['startTime']))
          : DateTime.now(),
      endTime: data['endTime'] != null
          ? (data['endTime'] is Timestamp
              ? (data['endTime'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['endTime']))
          : null,
      message: data['message'] ?? '', // 추가
      senderName: data['senderName'] ?? '', // 추가
    );
  }

  // 경로 지점 객체
  factory SharedLocation.locationPoint(
      String id, String senderId, String receiverId, double lat, double lng,
      {String receiverType = 'emergency_contact'}) {
    return SharedLocation(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      receiverType: receiverType,
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      isActive: true,
      startTime: DateTime.now(),
    );
  }

  // 새 위치로 객체 업데이트
  SharedLocation copyWithNewLocation(double lat, double lng) {
    return SharedLocation(
      id: this.id,
      senderId: this.senderId,
      receiverId: this.receiverId,
      receiverType: this.receiverType,
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      isActive: this.isActive,
      startTime: this.startTime,
      endTime: this.endTime,
      message: this.message, // 추가
      senderName: this.senderName, // 추가
    );
  }

  // 공유 종료 시 객체 업데이트
  SharedLocation copyWithEndSharing() {
    return SharedLocation(
      id: this.id,
      senderId: this.senderId,
      receiverId: this.receiverId,
      receiverType: this.receiverType,
      latitude: this.latitude,
      longitude: this.longitude,
      timestamp: this.timestamp,
      isActive: false,
      startTime: this.startTime,
      endTime: DateTime.now(),
      message: this.message, // 추가
      senderName: this.senderName, // 추가
    );
  }

  @override
  String toString() {
    return 'SharedLocation(id: $id, senderId: $senderId, receiverId: $receiverId, '
        'coordinates: ($latitude, $longitude), timestamp: $timestamp)';
  }
}
