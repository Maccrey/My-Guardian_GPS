class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isDefault;
  final String? description;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.isDefault = false,
    this.description,
  });

  // JSON 변환을 위한 팩토리 메서드
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      isDefault: json['isDefault'] ?? false,
      description: json['description'],
    );
  }

  // 객체를 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
      'description': description,
    };
  }

  // 객체의 복사본을 생성하는 메서드 (불변성 유지)
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    bool? isDefault,
    String? description,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
      description: description ?? this.description,
    );
  }
}
