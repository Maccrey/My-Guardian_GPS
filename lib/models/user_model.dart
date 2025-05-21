class UserModel {
  String? uid;
  String? email;
  String? password;
  String? nickname;
  DateTime? birthDate;
  String? country;
  String? countryCode;
  String? userType;
  String? profileImageUrl;
  DateTime? lastActive;
  DateTime? profileImageUploadDate;

  UserModel({
    this.uid,
    this.email,
    this.password,
    this.nickname,
    this.birthDate,
    this.country,
    this.countryCode,
    this.userType,
    this.profileImageUrl,
    this.lastActive,
    this.profileImageUploadDate,
  });

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
      'profileImageUrl': profileImageUrl,
      'lastActive': lastActive?.toIso8601String(),
      'profileImageUploadDate': profileImageUploadDate?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      country: json['country'],
      countryCode: json['countryCode'],
      userType: json['userType'],
      profileImageUrl: json['profileImageUrl'],
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : null,
      profileImageUploadDate: json['profileImageUploadDate'] != null
          ? DateTime.parse(json['profileImageUploadDate'])
          : null,
    );
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
