class UserModel {
  String? email;
  String? password;
  String? nickname;
  DateTime? birthDate;
  String? country;
  String? userType;

  UserModel({
    this.email,
    this.password,
    this.nickname,
    this.birthDate,
    this.country,
    this.userType,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      'birthDate': birthDate?.toIso8601String(),
      'country': country,
      'userType': userType,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      country: json['country'],
      userType: json['userType'],
    );
  }
}
