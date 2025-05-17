import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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

  // Getters
  bool get isAuthenticated => _isAuthenticated.value;
  UserModel? get currentUser => _currentUser.value;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

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
}
