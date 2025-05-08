import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class RegisterViewModel extends GetxController {
  // 서비스 의존성
  final AuthService _authService;

  // 컨트롤러
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // UI 상태
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;
  final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);
  final RxString selectedCountry = RxString('');
  final RxString selectedCountryCode = RxString('');
  final RxBool isGuardianMode = false.obs; // 보호자 모드 여부 (기본값: 일반 사용자)

  // 생성자
  RegisterViewModel(this._authService);

  // Getters
  bool get isLoading => _authService.isLoading;
  String? get error => _authService.error;
  List<Map<String, dynamic>> get countries => _authService.getCountries();

  // 자주 사용되는 국가 반환
  List<Map<String, dynamic>> getFrequentlyUsedCountries() {
    final frequentCodes = ['KR', 'US', 'JP', 'CN', 'GB'];
    return countries
        .where((country) => frequentCodes.contains(country['code']))
        .toList();
  }

  // 국가 검색 기능
  List<Map<String, dynamic>> searchCountries(String query) {
    if (query.isEmpty) {
      return getSortedCountries(); // 정렬된 전체 국가 목록 반환
    }

    final filtered = countries.where((country) {
      return country['name'].toLowerCase().contains(query.toLowerCase());
    }).toList();

    // 검색 결과 정렬
    filtered.sort((a, b) => a['name'].compareTo(b['name']));
    return filtered;
  }

  // 국가 목록을 알파벳 순으로 정렬
  List<Map<String, dynamic>> getSortedCountries() {
    final sortedList = List<Map<String, dynamic>>.from(countries);
    sortedList.sort((a, b) => a['name'].compareTo(b['name']));
    return sortedList;
  }

  // 비밀번호 표시/숨김 토글
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // 비밀번호 확인 표시/숨김 토글
  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  // 생년월일 설정
  void setSelectedDate(DateTime date) {
    selectedDate.value = date;
  }

  // 국가 설정
  void setSelectedCountry(String countryName, String countryCode) {
    selectedCountry.value = countryName;
    selectedCountryCode.value = countryCode;
  }

  // 사용자 유형 전환
  void toggleUserType() {
    isGuardianMode.value = !isGuardianMode.value;
  }

  // 현재 선택된 사용자 유형 반환
  String getUserType() {
    return isGuardianMode.value ? 'guardian' : 'regular';
  }

  // 사용자 유형에 따른 텍스트 반환
  String getUserTypeText() {
    return isGuardianMode.value ? '보호자 모드' : '일반 사용자 모드';
  }

  // 회원가입 처리
  Future<bool> register() async {
    final nickname = nicknameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // 입력 유효성 검사
    if (nickname.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        selectedDate.value == null ||
        selectedCountry.value.isEmpty) {
      _authService.setError('모든 필드를 입력해주세요');
      return false;
    }

    if (nickname.length < 2) {
      _authService.setError('닉네임은 최소 2자 이상이어야 합니다');
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _authService.setError('유효한 이메일 주소를 입력해주세요');
      return false;
    }

    if (password.length < 8) {
      _authService.setError('비밀번호는 최소 8자 이상이어야 합니다');
      return false;
    }

    if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
        .hasMatch(password)) {
      _authService.setError('비밀번호는 대소문자, 숫자, 특수문자를 포함해야 합니다');
      return false;
    }

    if (password != confirmPassword) {
      _authService.setError('비밀번호가 일치하지 않습니다');
      return false;
    }

    // 사용자 데이터 생성
    final user = UserModel(
      email: email,
      password: password,
      nickname: nickname,
      birthDate: selectedDate.value,
      country: selectedCountry.value,
      userType: getUserType(),
    );

    // 회원가입 요청
    return await _authService.register(user);
  }

  // 이모지 국기 생성
  String getCountryFlag(String countryCode) {
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  // 리소스 해제
  @override
  void onClose() {
    nicknameController.dispose();
    birthDateController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
