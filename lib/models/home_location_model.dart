import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 귀가 알림 기능을 위한 집 위치 정보 모델 클래스
class HomeLocationModel {
  final String id; // 고유 ID
  final String userId; // 사용자 ID
  final double latitude; // 위도
  final double longitude; // 경도
  final String address; // 주소
  final String name; // 위치 이름 (예: '우리집', '회사' 등)
  final DateTime createdAt; // 생성 시간
  final DateTime updatedAt; // 수정 시간
  final bool isDefault; // 기본 위치 여부

  HomeLocationModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });

  // LatLng 객체로 변환
  LatLng toLatLng() => LatLng(latitude, longitude);

  // JSON 형태로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isDefault': isDefault,
    };
  }

  // 복사본 생성 (수정용)
  HomeLocationModel copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? address,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return HomeLocationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  // JSON 데이터에서 생성 (로컬 저장소용)
  factory HomeLocationModel.fromJson(Map<String, dynamic> json) {
    return HomeLocationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      name: json['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'HomeLocationModel(id: $id, name: $name, address: $address, '
        'coordinates: ($latitude, $longitude), isDefault: $isDefault)';
  }
}
