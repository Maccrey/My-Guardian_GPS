import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String uid;
  String? email;
  String? password;
  String? nickname;
  DateTime? birthDate;
  String? country;
  String? countryCode;
  String? userType;
  String? photoUrl;
  String? profileImageUrl;
  DateTime? lastActive;
  DateTime? profileImageUploadDate;
  DateTime? createdAt;
  bool isActive;
  String? phoneNumber;

  UserModel({
    this.uid = '',
    this.email,
    this.password,
    this.nickname,
    this.birthDate,
    this.country,
    this.countryCode,
    this.userType,
    this.photoUrl,
    this.profileImageUrl,
    this.lastActive,
    this.profileImageUploadDate,
    this.createdAt,
    this.isActive = true,
    this.phoneNumber,
  });

  String? get displayName =>
      nickname ?? email?.split('@').first ?? 'Unknown User';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      email: data['email'],
      nickname: data['nickname'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] is Timestamp
              ? (data['birthDate'] as Timestamp).toDate()
              : DateTime.parse(data['birthDate']))
          : null,
      country: data['country'],
      countryCode: data['countryCode'],
      userType: data['userType'],
      photoUrl: data['photoUrl'] ?? data['profileImageUrl'],
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'],
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] is Timestamp
              ? (data['lastActive'] as Timestamp).toDate()
              : DateTime.parse(data['lastActive']))
          : null,
      profileImageUploadDate: data['profileImageUploadDate'] != null
          ? (data['profileImageUploadDate'] is Timestamp
              ? (data['profileImageUploadDate'] as Timestamp).toDate()
              : DateTime.parse(data['profileImageUploadDate']))
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(data['createdAt']))
          : null,
      isActive: data['isActive'] ?? true,
      phoneNumber: data['phoneNumber'],
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      birthDate: json['birthDate'] != null
          ? (json['birthDate'] is Timestamp
              ? (json['birthDate'] as Timestamp).toDate()
              : DateTime.parse(json['birthDate']))
          : null,
      country: json['country'],
      countryCode: json['countryCode'],
      userType: json['userType'],
      photoUrl: json['photoUrl'] ?? json['profileImageUrl'],
      profileImageUrl: json['profileImageUrl'] ?? json['photoUrl'],
      lastActive: json['lastActive'] != null
          ? (json['lastActive'] is Timestamp
              ? (json['lastActive'] as Timestamp).toDate()
              : DateTime.parse(json['lastActive']))
          : null,
      profileImageUploadDate: json['profileImageUploadDate'] != null
          ? (json['profileImageUploadDate'] is Timestamp
              ? (json['profileImageUploadDate'] as Timestamp).toDate()
              : DateTime.parse(json['profileImageUploadDate']))
          : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : null,
      isActive: json['isActive'] ?? true,
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'password': password,
      'nickname': nickname,
      'birthDate': birthDate?.toIso8601String(),
      'country': country,
      'countryCode': countryCode,
      'userType': userType,
      'photoUrl': photoUrl,
      'profileImageUrl': profileImageUrl ?? photoUrl,
      'lastActive': lastActive?.toIso8601String(),
      'profileImageUploadDate': profileImageUploadDate?.toIso8601String(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
    };
  }

  /// 프로필 이미지 변경 여부 확인
  ///
  /// [cachedUploadDate] 캐시된 업로드 날짜
  /// 현재 사용자의 프로필 이미지 업로드 날짜와 비교하여 변경 여부를 반환합니다.
  bool hasProfileImageChanged(DateTime? cachedUploadDate) {
    // 업로드 날짜가 없거나 캐시된 날짜가 없으면 변경된 것으로 간주
    if (profileImageUploadDate == null || cachedUploadDate == null) {
      return true;
    }

    // 두 날짜를 비교하여 다르면 변경된 것으로 간주
    return !profileImageUploadDate!.isAtSameMomentAs(cachedUploadDate);
  }
}
