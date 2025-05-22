// ****************************************************************************
// ******** 중요: 이 파일은 보호된 긴급 연락처 모델 코드입니다. 절대 수정하지 마세요. *******
// ****************************************************************************

import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final String? description;
  final bool isDefault; // 기본 제공 연락처 여부 (119, 112 등)
  final bool isActive; // 활성화 상태 여부

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.description,
    this.isDefault = false,
    this.isActive = true,
  });

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'description': description,
      'isDefault': isDefault,
      'isActive': isActive,
    };
  }

  // JSON에서 변환
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      relationship: json['relationship'],
      description: json['description'],
      isDefault: json['isDefault'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }

  // Firestore DocumentSnapshot에서 변환
  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      relationship: data['relationship'],
      description: data['description'],
      isDefault: data['isDefault'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }

  // 기본 긴급 연락처 생성
  static List<EmergencyContact> getDefaultContacts() {
    return [
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000001',
        name: '긴급 신고',
        phoneNumber: '119',
        description: '화재, 구조, 구급 등 긴급 상황',
        isDefault: true,
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000002',
        name: '경찰청',
        phoneNumber: '112',
        description: '범죄 신고 및 위급 상황',
        isDefault: true,
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000003',
        name: '해양경찰청',
        phoneNumber: '122',
        description: '해상 긴급 상황',
        isDefault: true,
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000004',
        name: '마약 신고',
        phoneNumber: '1301',
        description: '마약 범죄 신고 및 제보',
        isDefault: true,
      ),
      EmergencyContact(
        id: '00000000-0000-0000-0000-000000000005',
        name: '중앙재난안전상황실',
        phoneNumber: '044-205-1542',
        description: '자연재해 및 대형 사고',
        isDefault: true,
      ),
    ];
  }

  // 속성 업데이트
  EmergencyContact copyWith({
    String? name,
    String? phoneNumber,
    String? relationship,
    String? description,
    bool? isActive,
  }) {
    return EmergencyContact(
      id: this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      description: description ?? this.description,
      isDefault: this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }
}
