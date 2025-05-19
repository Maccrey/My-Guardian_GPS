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
    );
  }
}
