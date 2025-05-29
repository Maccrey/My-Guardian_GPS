import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

// 로깅을 위한 인스턴스
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class AuthService extends GetxController {
  // 웹 환경에서는 Firebase를 사용하지 않고 Mock 데이터를 사용
  final bool _useMockAuth = kIsWeb;

  // Firebase 인스턴스 (웹이 아닌 경우에만 사용)
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  // Mock 데이터를 위한 변수
  final List<UserModel> _mockUsers = [];

  final RxBool _isAuthenticated = false.obs;
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final RxBool _isLoading = false.obs;
  final Rx<String?> _error = Rx<String?>(null);

  // Firebase 사용자 ID와 로그인 상태 관리
  final Rx<String?> _uid = Rx<String?>(null);
  final RxBool _isGoogleSignInInProgress = false.obs; // 구글 로그인 진행 상태

  // Getters
  bool get isAuthenticated => _isAuthenticated.value;
  UserModel? get currentUser => _currentUser.value;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;
  bool get isGoogleSignInInProgress => _isGoogleSignInInProgress.value;

  // Firebase Auth의 UID 가져오기
  String? get uid =>
      _useMockAuth ? _currentUser.value?.uid : _auth.currentUser?.uid;
  User? get firebaseUser => _useMockAuth ? null : _auth.currentUser;

  AuthService() {
    if (!_useMockAuth) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    }
  }

  @override
  void onInit() {
    super.onInit();

    if (!_useMockAuth) {
      // Firebase 인증 상태 변경 감지 (웹이 아닌 경우에만)
      _auth.authStateChanges().listen(_handleAuthStateChange);
    }
  }

  // 인증 상태 변경 처리
  Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      // 로그아웃 상태
      _isAuthenticated.value = false;
      _currentUser.value = null;
    } else {
      // 로그인 상태 - Firestore에서 사용자 정보 가져오기
      _isAuthenticated.value = true;
      await _fetchUserData(firebaseUser.uid);
    }
  }

  // Firestore에서 사용자 정보 가져오기
  Future<void> _fetchUserData(String uid) async {
    if (_useMockAuth) {
      // Mock 데이터에서 사용자 검색
      final user = _mockUsers.firstWhereOrNull((user) => user.uid == uid);
      if (user != null) {
        _currentUser.value = user;
      }
      return;
    }

    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        _currentUser.value = UserModel.fromJson(userData);
      }
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
    }
  }

  // 로그인 메소드
  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);

    try {
      if (_useMockAuth) {
        // Mock 인증 처리
        final user = _mockUsers.firstWhereOrNull((user) => user.email == email);

        // 사용자 찾기 (웹에서 테스트를 위해 간단한 조건으로 검증)
        if (user != null) {
          // 비밀번호 검증 (실제로는 암호화되어야 함)
          _currentUser.value = user;
          _isAuthenticated.value = true;
          setLoading(false);
          return true;
        } else {
          setError('이메일 또는 비밀번호가 올바르지 않습니다');
          setLoading(false);
          return false;
        }
      }

      // Firebase 인증으로 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 성공
      if (userCredential.user != null) {
        // 사용자 정보 가져오기
        await _fetchUserData(userCredential.user!.uid);
        setLoading(false);
        return true;
      } else {
        setError('로그인에 실패했습니다');
        setLoading(false);
        return false;
      }
    } catch (e) {
      // Firebase 오류 메시지 처리
      String errorMessage = '로그인 중 오류가 발생했습니다';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = '해당 이메일로 등록된 사용자가 없습니다';
            break;
          case 'wrong-password':
            errorMessage = '비밀번호가 올바르지 않습니다';
            break;
          case 'invalid-email':
            errorMessage = '유효하지 않은 이메일 형식입니다';
            break;
          case 'user-disabled':
            errorMessage = '해당 계정은 비활성화되었습니다';
            break;
        }
      }

      setError(errorMessage);
      setLoading(false);
      return false;
    }
  }

  // Firestore에 사용자 정보 저장
  Future<void> _saveUserData(String uid, UserModel user) async {
    if (_useMockAuth) {
      return; // Mock 모드에서는 저장 필요 없음
    }

    try {
      // 비밀번호 제외하고 Firestore에 저장
      Map<String, dynamic> userData = user.toJson();
      userData.remove('password'); // 보안을 위해 비밀번호 제거

      // 사용자 문서 생성 또는 업데이트
      await _firestore.collection('users').doc(uid).set(userData);
      debugPrint('✅ Firestore에 사용자 정보 저장 성공: $uid');
    } catch (e) {
      // 권한 오류가 발생해도 회원가입은 성공한 것으로 처리 (Firebase Auth에는 등록됨)
      debugPrint('⚠️ Firestore 사용자 정보 저장 오류: $e');
      debugPrint('⚠️ Firestore 권한 문제로 인해 데이터 저장에 실패했지만, 인증 정보는 저장되었습니다.');
      // 오류를 던지지 않고 로그만 남김 (회원가입 과정에서 실패하지 않도록)
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserData(UserModel updatedUser) async {
    setLoading(true);
    setError(null);

    try {
      if (_useMockAuth) {
        // Mock 데이터 업데이트
        final index =
            _mockUsers.indexWhere((user) => user.uid == updatedUser.uid);
        if (index != -1) {
          _mockUsers[index] = updatedUser;
          _currentUser.value = updatedUser;
          setLoading(false);
          return true;
        } else {
          setError('사용자를 찾을 수 없습니다');
          setLoading(false);
          return false;
        }
      }

      // 현재 로그인한 사용자의 UID 확인
      final String? currentUid = _auth.currentUser?.uid;
      if (currentUid == null) {
        setError('로그인되어 있지 않습니다');
        setLoading(false);
        return false;
      }

      // Firestore에 사용자 정보 업데이트
      Map<String, dynamic> userData = updatedUser.toJson();
      userData.remove('password'); // 보안을 위해 비밀번호 제거

      await _firestore.collection('users').doc(currentUid).update(userData);

      // 현재 사용자 정보 업데이트
      _currentUser.value = updatedUser;

      debugPrint('✅ 사용자 정보 업데이트 성공: $currentUid');
      setLoading(false);
      return true;
    } catch (e) {
      String errorMessage = '사용자 정보 업데이트 중 오류가 발생했습니다';
      debugPrint('⚠️ 사용자 정보 업데이트 오류: $e');
      setError(errorMessage);
      setLoading(false);
      return false;
    }
  }

  // 프로필 이미지 업로드 및 URL 업데이트
  Future<String?> uploadProfileImage(String uid, Uint8List imageData) async {
    if (_useMockAuth) {
      // Mock 이미지 URL 반환
      return 'https://mock-image-url.com/${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      // Firebase Storage 참조 생성
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      // 이미지 업로드
      final uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 업로드 완료 대기
      final snapshot = await uploadTask;

      // 이미지 다운로드 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 프로필 이미지 업로드 날짜 업데이트
      final userData = await _firestore.collection('users').doc(uid).get();
      if (userData.exists) {
        await _firestore.collection('users').doc(uid).update({
          'profileImageUploadDate': DateTime.now().toIso8601String(),
        });

        // 현재 사용자인 경우 로컬 정보도 업데이트
        if (_currentUser.value?.uid == uid) {
          _currentUser.value?.profileImageUploadDate = DateTime.now();
        }
      }

      debugPrint('✅ 프로필 이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('⚠️ 프로필 이미지 업로드 오류: $e');
      return null;
    }
  }

  // 회원가입 메소드
  Future<bool> register(UserModel user) async {
    if (user.email == null || user.password == null) {
      setError('이메일과 비밀번호는 필수 항목입니다');
      return false;
    }

    setLoading(true);
    setError(null);

    try {
      if (_useMockAuth) {
        // Mock 회원가입 처리
        debugPrint('🔧 Mock 회원가입 처리 중...');

        // 중복 이메일 체크
        if (_mockUsers.any((u) => u.email == user.email)) {
          setError('이미 사용 중인 이메일입니다');
          setLoading(false);
          return false;
        }

        // Mock UID 생성
        final String mockUid =
            'mock-user-${DateTime.now().millisecondsSinceEpoch}';
        user.uid = mockUid;

        // 비밀번호는 저장하지 않음 (실제로는 해싱 처리해야 함)
        final savedUser = UserModel(
          uid: user.uid,
          email: user.email,
          nickname: user.nickname,
          birthDate: user.birthDate,
          country: user.country,
          userType: user.userType,
        );

        // Mock 사용자 목록에 추가
        _mockUsers.add(savedUser);

        debugPrint('✅ Mock 회원가입 성공: ${savedUser.uid}');
        setLoading(false);
        return true;
      } else {
        // Firebase Auth로 사용자 생성
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: user.email!,
          password: user.password!,
        );

        // 사용자 생성 성공
        if (userCredential.user != null) {
          // UID를 사용자 모델에 저장
          user.uid = userCredential.user!.uid;

          // Firestore에 사용자 정보 저장
          await _saveUserData(userCredential.user!.uid, user);

          // 비밀번호는 저장하지 않음
          user.password = null;
          _currentUser.value = user;

          debugPrint('✅ Firebase 회원가입 성공: ${user.uid}');
          setLoading(false);
          return true;
        } else {
          setError('회원가입에 실패했습니다');
          setLoading(false);
          return false;
        }
      }
    } on FirebaseAuthException catch (e) {
      // Firebase Auth 오류 처리
      String errorMessage = '회원가입 중 오류가 발생했습니다';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다';
          break;
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다';
          break;
        default:
          errorMessage = '회원가입 중 오류가 발생했습니다: ${e.code}';
      }

      setError(errorMessage);
      debugPrint('❌ Firebase 회원가입 오류: ${e.code} - $errorMessage');
      setLoading(false);
      return false;
    } catch (e) {
      // 기타 오류 처리
      setError('회원가입 중 오류가 발생했습니다: ${e.toString()}');
      debugPrint('❌ 회원가입 오류: $e');
      setLoading(false);
      return false;
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    if (_useMockAuth) {
      if (_currentUser.value == null) {
        setError('로그인이 필요한 기능입니다');
        return false;
      }

      setLoading(true);
      setError(null);

      try {
        // 현재 사용자 찾기
        final index = _mockUsers
            .indexWhere((user) => user.uid == _currentUser.value!.uid);
        if (index >= 0) {
          // 비밀번호는 변경하지 않음
          final String? oldPassword = _mockUsers[index].password;
          updatedUser.password = oldPassword;

          // 사용자 정보 업데이트
          _mockUsers[index] = updatedUser;
          _currentUser.value = updatedUser;
        }

        setLoading(false);
        return true;
      } catch (e) {
        setError('프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}');
        setLoading(false);
        return false;
      }
    }

    if (_auth.currentUser == null) {
      setError('로그인이 필요한 기능입니다');
      return false;
    }

    setLoading(true);
    setError(null);

    try {
      String uid = _auth.currentUser!.uid;

      // 비밀번호 제외하고 Firestore에 저장
      Map<String, dynamic> userData = updatedUser.toJson();
      userData.remove('password');

      // 사용자 문서 업데이트
      await _firestore.collection('users').doc(uid).update(userData);

      // 현재 사용자 정보 업데이트
      _currentUser.value = updatedUser;

      setLoading(false);
      return true;
    } catch (e) {
      setError('프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // 로그아웃 메소드
  Future<void> logout() async {
    setLoading(true);

    try {
      if (!_useMockAuth) {
        await _auth.signOut();
      }

      _currentUser.value = null;
      _isAuthenticated.value = false;
      _uid.value = null; // uid 초기화
      setLoading(false);
    } catch (e) {
      setError('로그아웃 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
    }
  }

  // 유틸리티 메소드
  void setLoading(bool value) {
    _isLoading.value = value;
  }

  void setError(String? value) {
    _error.value = value;
  }

  // 비밀번호 재설정 메서드
  Future<bool> sendPasswordResetEmail(String email) async {
    setLoading(true);
    setError(null);

    try {
      if (_useMockAuth) {
        // Mock 환경에서는 지연만 시뮬레이션
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('✅ Mock 비밀번호 재설정 이메일 전송 (가상): $email');
        setLoading(false);
        return true;
      } else {
        // Firebase를 사용하여 실제 비밀번호 재설정 이메일 전송
        await _auth.sendPasswordResetEmail(email: email);
        debugPrint('✅ Firebase 비밀번호 재설정 이메일 전송: $email');
        setLoading(false);
        return true;
      }
    } catch (e) {
      // 오류 처리
      String errorMessage = '비밀번호 재설정 이메일 전송 중 오류가 발생했습니다';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = '해당 이메일로 등록된 사용자가 없습니다';
            break;
          case 'invalid-email':
            errorMessage = '유효하지 않은 이메일 형식입니다';
            break;
          default:
            errorMessage = '비밀번호 재설정 요청 중 오류가 발생했습니다: ${e.code}';
        }
      }

      setError(errorMessage);
      debugPrint('❌ 비밀번호 재설정 이메일 전송 오류: $e');
      setLoading(false);
      return false;
    }
  }

  // 국가 리스트 제공 메소드
  List<Map<String, dynamic>> getCountries() {
    return [
      {'name': '대한민국', 'code': 'KR'},
      {'name': '미국', 'code': 'US'},
      {'name': '일본', 'code': 'JP'},
      {'name': '중국', 'code': 'CN'},
      {'name': '영국', 'code': 'GB'},
      {'name': '프랑스', 'code': 'FR'},
      {'name': '독일', 'code': 'DE'},
      {'name': '캐나다', 'code': 'CA'},
      {'name': '호주', 'code': 'AU'},
      {'name': '뉴질랜드', 'code': 'NZ'},
      {'name': '이탈리아', 'code': 'IT'},
      {'name': '스페인', 'code': 'ES'},
      {'name': '러시아', 'code': 'RU'},
      {'name': '브라질', 'code': 'BR'},
      {'name': '인도', 'code': 'IN'},
      {'name': '싱가포르', 'code': 'SG'},
      {'name': '말레이시아', 'code': 'MY'},
      {'name': '태국', 'code': 'TH'},
      {'name': '베트남', 'code': 'VN'},
      {'name': '인도네시아', 'code': 'ID'},
      {'name': '아프가니스탄', 'code': 'AF'},
      {'name': '알바니아', 'code': 'AL'},
      {'name': '알제리', 'code': 'DZ'},
      {'name': '안도라', 'code': 'AD'},
      {'name': '앙골라', 'code': 'AO'},
      {'name': '앤티가 바부다', 'code': 'AG'},
      {'name': '아르헨티나', 'code': 'AR'},
      {'name': '아르메니아', 'code': 'AM'},
      {'name': '오스트리아', 'code': 'AT'},
      {'name': '아제르바이잔', 'code': 'AZ'},
      {'name': '바하마', 'code': 'BS'},
      {'name': '바레인', 'code': 'BH'},
      {'name': '방글라데시', 'code': 'BD'},
      {'name': '바베이도스', 'code': 'BB'},
      {'name': '벨라루스', 'code': 'BY'},
      {'name': '벨기에', 'code': 'BE'},
      {'name': '벨리즈', 'code': 'BZ'},
      {'name': '베냉', 'code': 'BJ'},
      {'name': '부탄', 'code': 'BT'},
      {'name': '볼리비아', 'code': 'BO'},
      {'name': '보스니아 헤르체고비나', 'code': 'BA'},
      {'name': '보츠와나', 'code': 'BW'},
      {'name': '브루나이', 'code': 'BN'},
      {'name': '불가리아', 'code': 'BG'},
      {'name': '부르키나파소', 'code': 'BF'},
      {'name': '브룬디', 'code': 'BI'},
      {'name': '카보베르데', 'code': 'CV'},
      {'name': '캄보디아', 'code': 'KH'},
      {'name': '카메룬', 'code': 'CM'},
      {'name': '중앙아프리카공화국', 'code': 'CF'},
      {'name': '차드', 'code': 'TD'},
      {'name': '칠레', 'code': 'CL'},
      {'name': '콜롬비아', 'code': 'CO'},
      {'name': '코모로', 'code': 'KM'},
      {'name': '콩고', 'code': 'CG'},
      {'name': '콩고민주공화국', 'code': 'CD'},
      {'name': '코스타리카', 'code': 'CR'},
      {'name': '코트디부아르', 'code': 'CI'},
      {'name': '크로아티아', 'code': 'HR'},
      {'name': '쿠바', 'code': 'CU'},
      {'name': '키프로스', 'code': 'CY'},
      {'name': '체코', 'code': 'CZ'},
      {'name': '덴마크', 'code': 'DK'},
      {'name': '지부티', 'code': 'DJ'},
      {'name': '도미니카', 'code': 'DM'},
      {'name': '도미니카 공화국', 'code': 'DO'},
      {'name': '에콰도르', 'code': 'EC'},
      {'name': '이집트', 'code': 'EG'},
      {'name': '엘살바도르', 'code': 'SV'},
      {'name': '적도 기니', 'code': 'GQ'},
      {'name': '에리트레아', 'code': 'ER'},
      {'name': '에스토니아', 'code': 'EE'},
      {'name': '에스와티니', 'code': 'SZ'},
      {'name': '에티오피아', 'code': 'ET'},
      {'name': '피지', 'code': 'FJ'},
      {'name': '핀란드', 'code': 'FI'},
      {'name': '가봉', 'code': 'GA'},
      {'name': '감비아', 'code': 'GM'},
      {'name': '조지아', 'code': 'GE'},
      {'name': '가나', 'code': 'GH'},
      {'name': '그리스', 'code': 'GR'},
      {'name': '그레나다', 'code': 'GD'},
      {'name': '과테말라', 'code': 'GT'},
      {'name': '기니', 'code': 'GN'},
      {'name': '기니비사우', 'code': 'GW'},
      {'name': '가이아나', 'code': 'GY'},
      {'name': '아이티', 'code': 'HT'},
      {'name': '온두라스', 'code': 'HN'},
      {'name': '헝가리', 'code': 'HU'},
      {'name': '아이슬란드', 'code': 'IS'},
      {'name': '이란', 'code': 'IR'},
      {'name': '이라크', 'code': 'IQ'},
      {'name': '아일랜드', 'code': 'IE'},
      {'name': '이스라엘', 'code': 'IL'},
      {'name': '자메이카', 'code': 'JM'},
      {'name': '요르단', 'code': 'JO'},
      {'name': '카자흐스탄', 'code': 'KZ'},
      {'name': '케냐', 'code': 'KE'},
      {'name': '키리바시', 'code': 'KI'},
      {'name': '북한', 'code': 'KP'},
      {'name': '코소보', 'code': 'XK'},
      {'name': '쿠웨이트', 'code': 'KW'},
      {'name': '키르기스스탄', 'code': 'KG'},
      {'name': '라오스', 'code': 'LA'},
      {'name': '라트비아', 'code': 'LV'},
      {'name': '레바논', 'code': 'LB'},
      {'name': '레소토', 'code': 'LS'},
      {'name': '라이베리아', 'code': 'LR'},
      {'name': '리비아', 'code': 'LY'},
      {'name': '리히텐슈타인', 'code': 'LI'},
      {'name': '리투아니아', 'code': 'LT'},
      {'name': '룩셈부르크', 'code': 'LU'},
      {'name': '마다가스카르', 'code': 'MG'},
      {'name': '말라위', 'code': 'MW'},
      {'name': '몰디브', 'code': 'MV'},
      {'name': '말리', 'code': 'ML'},
      {'name': '몰타', 'code': 'MT'},
      {'name': '마셜 제도', 'code': 'MH'},
      {'name': '모리타니', 'code': 'MR'},
      {'name': '모리셔스', 'code': 'MU'},
      {'name': '멕시코', 'code': 'MX'},
      {'name': '미크로네시아', 'code': 'FM'},
      {'name': '몰도바', 'code': 'MD'},
      {'name': '모나코', 'code': 'MC'},
      {'name': '몽골', 'code': 'MN'},
      {'name': '몬테네그로', 'code': 'ME'},
      {'name': '모로코', 'code': 'MA'},
      {'name': '모잠비크', 'code': 'MZ'},
      {'name': '미얀마', 'code': 'MM'},
      {'name': '나미비아', 'code': 'NA'},
      {'name': '나우루', 'code': 'NR'},
      {'name': '네팔', 'code': 'NP'},
      {'name': '네덜란드', 'code': 'NL'},
      {'name': '니카라과', 'code': 'NI'},
      {'name': '니제르', 'code': 'NE'},
      {'name': '나이지리아', 'code': 'NG'},
      {'name': '북마케도니아', 'code': 'MK'},
      {'name': '노르웨이', 'code': 'NO'},
      {'name': '오만', 'code': 'OM'},
      {'name': '파키스탄', 'code': 'PK'},
      {'name': '팔라우', 'code': 'PW'},
      {'name': '팔레스타인', 'code': 'PS'},
      {'name': '파나마', 'code': 'PA'},
      {'name': '파푸아뉴기니', 'code': 'PG'},
      {'name': '파라과이', 'code': 'PY'},
      {'name': '페루', 'code': 'PE'},
      {'name': '필리핀', 'code': 'PH'},
      {'name': '폴란드', 'code': 'PL'},
      {'name': '포르투갈', 'code': 'PT'},
      {'name': '카타르', 'code': 'QA'},
      {'name': '루마니아', 'code': 'RO'},
      {'name': '르완다', 'code': 'RW'},
      {'name': '세인트키츠 네비스', 'code': 'KN'},
      {'name': '세인트루시아', 'code': 'LC'},
      {'name': '세인트빈센트 그레나딘', 'code': 'VC'},
      {'name': '사모아', 'code': 'WS'},
      {'name': '산마리노', 'code': 'SM'},
      {'name': '상투메 프린시페', 'code': 'ST'},
      {'name': '사우디아라비아', 'code': 'SA'},
      {'name': '세네갈', 'code': 'SN'},
      {'name': '세르비아', 'code': 'RS'},
      {'name': '세이셸', 'code': 'SC'},
      {'name': '시에라리온', 'code': 'SL'},
      {'name': '슬로바키아', 'code': 'SK'},
      {'name': '슬로베니아', 'code': 'SI'},
      {'name': '솔로몬 제도', 'code': 'SB'},
      {'name': '소말리아', 'code': 'SO'},
      {'name': '남아프리카 공화국', 'code': 'ZA'},
      {'name': '남수단', 'code': 'SS'},
      {'name': '스리랑카', 'code': 'LK'},
      {'name': '수단', 'code': 'SD'},
      {'name': '수리남', 'code': 'SR'},
      {'name': '스웨덴', 'code': 'SE'},
      {'name': '스위스', 'code': 'CH'},
      {'name': '시리아', 'code': 'SY'},
      {'name': '타지키스탄', 'code': 'TJ'},
      {'name': '탄자니아', 'code': 'TZ'},
      {'name': '동티모르', 'code': 'TL'},
      {'name': '토고', 'code': 'TG'},
      {'name': '통가', 'code': 'TO'},
      {'name': '트리니다드 토바고', 'code': 'TT'},
      {'name': '튀니지', 'code': 'TN'},
      {'name': '터키', 'code': 'TR'},
      {'name': '투르크메니스탄', 'code': 'TM'},
      {'name': '투발루', 'code': 'TV'},
      {'name': '우간다', 'code': 'UG'},
      {'name': '우크라이나', 'code': 'UA'},
      {'name': '아랍에미리트', 'code': 'AE'},
      {'name': '우루과이', 'code': 'UY'},
      {'name': '우즈베키스탄', 'code': 'UZ'},
      {'name': '바누아투', 'code': 'VU'},
      {'name': '바티칸 시국', 'code': 'VA'},
      {'name': '베네수엘라', 'code': 'VE'},
      {'name': '예멘', 'code': 'YE'},
      {'name': '잠비아', 'code': 'ZM'},
      {'name': '짐바브웨', 'code': 'ZW'},
    ];
  }

  // 구글 로그인 메서드
  Future<bool> signInWithGoogle() async {
    setLoading(true);
    setError(null);

    try {
      if (_useMockAuth) {
        // Mock 환경에서는 지연만 시뮬레이션
        await Future.delayed(const Duration(seconds: 2));
        final mockGoogleUser = UserModel(
          uid: 'google-mock-${DateTime.now().millisecondsSinceEpoch}',
          email: 'google-user@example.com',
          nickname: 'Google 사용자',
        );
        _currentUser.value = mockGoogleUser;
        _isAuthenticated.value = true;
        logger.i('✅ Mock Google 로그인 성공');
        setLoading(false);
        return true;
      } else {
        // 실제 Google 로그인 처리
        logger.i('✅ Google 로그인 시작...');

        if (_isGoogleSignInInProgress.value) {
          logger.w('⚠️ 이미 구글 로그인이 진행 중입니다');
          setLoading(false);
          return false; // 중복 실행 방지
        }
        _isGoogleSignInInProgress.value = true;

        try {
          // Firebase Console에서 가져온 웹 클라이언트 ID
          // iOS와 Android 모두 동일한 클라이언트 ID 사용
          final String? webClientId = (defaultTargetPlatform ==
                      TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
              ? "1071355933777-m0h2ud9umafo496iptjf5fln8i0vjdsc.apps.googleusercontent.com"
              : null;

          logger.d("Using webClientId for Google Sign-In: $webClientId");
          logger.d("Current platform: $defaultTargetPlatform");

          // 구글 로그인 인스턴스 생성 시 옵션 설정 추가
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
            serverClientId: webClientId,
            // iOS에서 사파리로 인증할 때 앱으로 돌아오기 위한 설정
            signInOption: SignInOption.standard,
          );

          // 기존 세션 확인 및 정리
          bool wasSignedIn = false;
          try {
            wasSignedIn = await googleSignIn.isSignedIn();
            if (wasSignedIn) {
              logger.i("기존 Google 세션이 있어 로그아웃 시도...");
              await googleSignIn.signOut();
              // 세션 정리 후 잠시 대기 (iOS에서 문제 방지)
              await Future.delayed(const Duration(milliseconds: 300));
              logger.i("기존 Google 세션 로그아웃 완료");
            }
          } catch (e) {
            logger.w("기존 Google 세션 확인/로그아웃 중 오류 (진행 계속): $e");
            // 오류가 발생해도 계속 진행
          }

          // Google 계정 선택 및 로그인 시도
          logger.i("Google 계정 선택 화면 표시 시도...");
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

          if (googleUser == null) {
            logger.w('⚠️ Google 로그인이 사용자에 의해 취소되었거나 실패했습니다');
            setError('Google 로그인이 취소되었습니다.');
            _isGoogleSignInInProgress.value = false;
            setLoading(false);
            return false;
          }

          logger.i('✅ Google 계정 선택 완료: ${googleUser.email}');

          // 인증 정보 가져오기 시도
          logger.i('Google 인증 정보 요청 중...');
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          // 토큰 검증 로직 강화
          if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
            logger.e('❌ Google ID 토큰을 가져오지 못했습니다.');
            logger.d(
                'Google Auth Details: accessToken: ${googleAuth.accessToken != null ? "있음" : "없음"}, '
                'idToken: ${googleAuth.idToken != null ? "있음" : "없음"}, '
                'serverAuthCode: ${googleAuth.serverAuthCode != null ? "있음" : "없음"}');

            setError('Google 로그인 인증에 실패했습니다. 네트워크 연결을 확인하고 다시 시도해주세요.');
            _isGoogleSignInInProgress.value = false;
            setLoading(false);

            // 문제 해결을 위해 세션 정리 시도
            try {
              await googleSignIn.signOut();
              logger.i("문제 해결을 위해 Google 세션 정리 완료");
            } catch (e) {
              logger.w("Google 세션 정리 중 오류: $e");
            }

            return false;
          }

          // Firebase 인증 자격 증명 생성
          logger.i('Firebase 인증 자격 증명 생성 중...');
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Firebase에 로그인 시도
          logger.i('Firebase에 Google 자격 증명으로 로그인 시도...');
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          final User? user = userCredential.user;

          if (user == null) {
            logger.e('❌ Firebase 사용자 정보 획득 실패');
            setError('Google 계정으로 Firebase 로그인에 실패했습니다.');
            _isGoogleSignInInProgress.value = false;
            setLoading(false);
            return false;
          }

          logger.i('✅ Firebase 로그인 성공: ${user.uid}');

          // Firestore에서 사용자 정보 확인/등록
          final docSnapshot =
              await _firestore.collection('users').doc(user.uid).get();

          if (!docSnapshot.exists) {
            logger.i('새로운 사용자 Firestore에 등록 중: ${user.uid}');
            final newUser = UserModel(
              uid: user.uid,
              email: user.email,
              nickname: user.displayName ?? user.email?.split('@')[0] ?? '사용자',
              profileImageUrl: user.photoURL,
            );
            await _saveUserData(user.uid, newUser);
            _currentUser.value = newUser;
          } else {
            logger.i('기존 사용자 Firestore 정보 로드: ${user.uid}');
            await _fetchUserData(user.uid);
          }

          _isAuthenticated.value = true;
          logger.i('✅ Google 로그인 전체 프로세스 성공: ${user.uid}');
          _isGoogleSignInInProgress.value = false;
          setLoading(false);
          return true;
        } catch (e) {
          _isGoogleSignInInProgress.value = false;
          logger.e('❌ Google 로그인 중 예외 발생: $e');

          String errorMessage = 'Google 로그인 중 오류가 발생했습니다.';
          String detailedError = e.toString();

          if (e is FirebaseAuthException) {
            errorMessage = 'Firebase 인증 오류: ${e.message} (코드: ${e.code})';
            logger.e('Firebase 오류 코드: ${e.code}, 메시지: ${e.message}');
          } else if (detailedError.contains('PlatformException')) {
            // GoogleSignIn의 PlatformException 처리
            if (detailedError.contains('SIGN_IN_CANCELLED')) {
              errorMessage = 'Google 로그인이 취소되었습니다.';
            } else if (detailedError.contains('NETWORK_ERROR')) {
              errorMessage = '네트워크 오류로 Google 로그인에 실패했습니다. 인터넷 연결을 확인하세요.';
            } else if (detailedError.contains('sign_in_failed')) {
              errorMessage = 'Google 로그인 실패: 인증 과정에서 오류가 발생했습니다.';
            } else if (detailedError.contains('connection')) {
              errorMessage = '네트워크 연결 오류: 인터넷 연결을 확인하고 다시 시도해주세요.';
            } else {
              // 자세한 오류 메시지 포함
              errorMessage =
                  'Google 로그인 실패: ${detailedError.split(',').skip(1).join(',').trim()}';
            }
          } else if (detailedError.contains('connection') ||
              detailedError.contains('network')) {
            errorMessage = '네트워크 연결 오류: 인터넷 연결을 확인하고 다시 시도해주세요.';
          }

          logger.e('오류 상세 정보: $detailedError');
          setError(errorMessage);
          setLoading(false);
          return false;
        }
      }
    } catch (e) {
      _isGoogleSignInInProgress.value = false;
      logger.e('❌ Google 로그인 외부 catch 블록 오류: $e');
      setError('Google 로그인 중 예기치 않은 오류가 발생했습니다. 다시 시도해주세요.');
      setLoading(false);
      return false;
    }
  }

  // 사용자 활동 상태 업데이트 메소드
  Future<void> updateUserActivity() async {
    if (_useMockAuth || uid == null) {
      return; // Mock 모드이거나 로그인되지 않은 경우 업데이트 필요 없음
    }

    try {
      final now = DateTime.now();

      // Firestore에 마지막 활동 시간 업데이트
      await _firestore.collection('users').doc(uid).update({
        'lastActive': now.toIso8601String(),
      });

      // 로컬 사용자 모델 업데이트
      if (_currentUser.value != null) {
        _currentUser.value!.lastActive = now;
      }

      debugPrint('✅ 사용자 활동 상태 업데이트 성공: $uid');
    } catch (e) {
      debugPrint('⚠️ 사용자 활동 상태 업데이트 오류: $e');
    }
  }

  // 다른 사용자의 마지막 활동 시간 조회
  Future<DateTime?> getUserLastActive(String userId) async {
    if (_useMockAuth) {
      return null; // Mock 모드에서는 null 반환
    }

    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        if (userData['lastActive'] != null) {
          return DateTime.parse(userData['lastActive']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ 사용자 마지막 활동 시간 조회 오류: $e');
      return null;
    }
  }

  // 사용자의 온라인 상태 텍스트 반환
  String getUserOnlineStatusText(DateTime? lastActive) {
    if (lastActive == null) {
      return '오프라인';
    }

    final now = DateTime.now();
    final difference = now.difference(lastActive);

    // 5분 이내에 활동했으면 온라인으로 간주
    if (difference.inMinutes < 5) {
      return '온라인';
    }

    // 오늘 활동했으면 시간 표시
    if (lastActive.day == now.day &&
        lastActive.month == now.month &&
        lastActive.year == now.year) {
      return '마지막 활동: ${lastActive.hour.toString().padLeft(2, '0')}:${lastActive.minute.toString().padLeft(2, '0')}';
    }

    // 어제 활동했으면 "어제" 표시
    final yesterday = now.subtract(const Duration(days: 1));
    if (lastActive.day == yesterday.day &&
        lastActive.month == yesterday.month &&
        lastActive.year == yesterday.year) {
      return '마지막 활동: 어제';
    }

    // 일주일 이내면 요일 표시
    if (difference.inDays < 7) {
      final weekday =
          ['월', '화', '수', '목', '금', '토', '일'][lastActive.weekday - 1];
      return '마지막 활동: $weekday요일';
    }

    // 그 외에는 날짜 표시
    return '마지막 활동: ${lastActive.month}/${lastActive.day}';
  }

  // 사용자의 온라인 상태 색상 반환
  Color getUserOnlineStatusColor(DateTime? lastActive) {
    if (lastActive == null) {
      return Colors.grey;
    }

    final now = DateTime.now();
    final difference = now.difference(lastActive);

    // 5분 이내에 활동했으면 온라인(녹색)으로 간주
    if (difference.inMinutes < 5) {
      return Colors.green;
    }

    // 1시간 이내면 주황색
    if (difference.inMinutes < 60) {
      return Colors.orange;
    }

    // 그 외에는 회색
    return Colors.grey;
  }
}
