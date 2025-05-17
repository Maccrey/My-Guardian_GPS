class UserModel {
  String? uid;
  String? email;
  String? password;
  String? nickname;
  DateTime? birthDate;
  String? country;
  String? userType;
  String? uid; // Firebase 사용자 ID

  UserModel({
    this.uid,
    this.email,
    this.password,
    this.nickname,
    this.birthDate,
    this.country,
    this.userType,
    this.uid,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'password': password,
      'nickname': nickname,
      'birthDate': birthDate?.toIso8601String(),
      'country': country,
      'userType': userType,
      'uid': uid,
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
      userType: json['userType'],
      uid: json['uid'],
    );
  }
}
