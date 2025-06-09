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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  // Firebase 인스턴스
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
  String? get uid => _auth.currentUser?.uid;
  User? get firebaseUser => _auth.currentUser;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
  }

  @override
  void onInit() {
    super.onInit();
    // Firebase 인증 상태 변경 감지
    _auth.authStateChanges().listen(_handleAuthStateChange);
    // 자동 로그인 시도
    _tryAutoLogin();
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

  // 자동 로그인 시도
  Future<void> _tryAutoLogin() async {
    try {
      final email = await _secureStorage.read(key: 'auth_email');
      final password = await _secureStorage.read(key: 'auth_password');

      if (email != null && password != null) {
        print('✅ 저장된 로그인 정보 발견: 자동 로그인 시도');
        await login(email, password, rememberMe: true);
      }
    } catch (e) {
      print('⚠️ 자동 로그인 시도 중 오류: $e');
    }
  }

  // Firestore에서 사용자 정보 가져오기
  Future<void> _fetchUserData(String uid) async {
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
  Future<bool> login(String email, String password,
      {bool rememberMe = false}) async {
    setLoading(true);
    setError(null);

    try {
      // Firebase 인증으로 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 로그인 성공
      if (userCredential.user != null) {
        // 이메일 인증 여부 확인
        if (!userCredential.user!.emailVerified) {
          debugPrint('❗ 이메일 인증이 완료되지 않았습니다. 인증 메일 재발송 시도');

          // 인증 메일 재발송 시도
          bool emailSent = false;
          try {
            // 기본 설정으로 인증 메일 발송
            await userCredential.user!.sendEmailVerification();
            debugPrint('✅ 로그인 시 이메일 인증 메일 재발송 성공');
            emailSent = true;
          } catch (e) {
            debugPrint('❌ 로그인 시 이메일 인증 메일 재발송 실패: $e');
            emailSent = false;
          }

          // 알림 메시지 설정
          setError('이메일 인증이 필요합니다. 인증 메일을 확인해 주세요.');

          // 사용자에게 알림 표시 (GetX 스낵바)
          Get.snackbar(
            '이메일 인증 필요',
            emailSent
                ? '인증 메일을 발송했습니다. 이메일을 확인해 주세요.'
                : '인증 메일 발송에 실패했습니다. 아래 버튼을 눌러 다시 시도해주세요.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () async {
                try {
                  await userCredential.user!.sendEmailVerification();
                  Get.snackbar(
                    '인증 메일 발송',
                    '인증 메일이 다시 발송되었습니다.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.7),
                    colorText: Colors.white,
                  );
                } catch (e) {
                  debugPrint('❌ 인증 메일 재발송 버튼 클릭 시 오류: $e');
                  Get.snackbar(
                    '오류',
                    '인증 메일 발송에 실패했습니다. 잠시 후 다시 시도해주세요.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.8),
                    colorText: Colors.white,
                  );
                }
              },
              child: const Text('재발송', style: TextStyle(color: Colors.white)),
            ),
          );

          setLoading(false);
          return false;
        }

        // 사용자 정보 가져오기
        await _fetchUserData(userCredential.user!.uid);

        // 자동 로그인 설정 저장
        if (rememberMe) {
          await _saveCredentials(email, password);
        }

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

      debugPrint('❌ 로그인 예외: $e'); // 실제 예외 메시지 출력

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
          case 'requires-recent-login':
            errorMessage = '보안을 위해 다시 로그인해주세요';
            break;
          case 'email-already-in-use':
            errorMessage = '이미 사용 중인 이메일입니다';
            break;
          case 'operation-not-allowed':
            errorMessage = '이 로그인 방식은 현재 허용되지 않습니다';
            break;
          case 'too-many-requests':
            errorMessage = '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요';
            break;
          default:
            errorMessage = '로그인 중 오류가 발생했습니다: ${e.code}';
        }
      }

      setError(errorMessage);
      setLoading(false);
      return false;
    }
  }

  // 인증 정보 저장
  Future<void> _saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: 'auth_email', value: email);
      await _secureStorage.write(key: 'auth_password', value: password);
      print('✅ 로그인 정보 저장 완료');
    } catch (e) {
      print('⚠️ 로그인 정보 저장 오류: $e');
    }
  }

  // 인증 정보 삭제
  Future<void> _clearCredentials() async {
    try {
      await _secureStorage.delete(key: 'auth_email');
      await _secureStorage.delete(key: 'auth_password');
      print('✅ 로그인 정보 삭제 완료');
    } catch (e) {
      print('⚠️ 로그인 정보 삭제 오류: $e');
    }
  }

  // Firestore에 사용자 정보 저장
  Future<void> _saveUserData(String uid, UserModel user) async {
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

        // 이메일 인증 메일 발송 (실패해도 회원가입은 성공으로 처리)
        bool emailSent = false;
        try {
          debugPrint('이메일 인증 메일 발송 시도');

          // 기본 설정으로 이메일 인증 메일 발송 (더 안정적)
          await userCredential.user!.sendEmailVerification();

          debugPrint('✅ 이메일 인증 메일 발송 성공');
          emailSent = true;

          // 성공 메시지 표시
          Get.snackbar(
            '인증 메일 발송',
            '회원가입이 완료되었습니다! 이메일을 확인하고 인증을 완료해주세요.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        } catch (e, stack) {
          debugPrint('❌ 이메일 인증 메일 발송 실패: $e');
          debugPrint('❌ 스택트레이스: $stack');
          setError('회원가입은 완료되었으나, 이메일 인증 메일 발송에 실패했습니다. 로그인 시 다시 발송됩니다.');
        }
        setLoading(false); // 로딩 상태 해제
        if (!emailSent) {
          setError('회원가입은 완료되었으나, 이메일 인증 메일 발송에 실패했습니다. 로그인 시 다시 발송됩니다.');
        }
        return true;
      } else {
        setError('회원가입에 실패했습니다');
        setLoading(false);
        return false;
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
    } catch (e, stack) {
      setError('회원가입 중 오류가 발생했습니다: [31m${e.toString()}[0m');
      debugPrint('❌ 회원가입 오류: $e');
      debugPrint('❌ 스택트레이스: $stack');
      setLoading(false);
      return false;
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    if (_currentUser.value == null) {
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
  Future<void> logout({bool clearSavedCredentials = true}) async {
    setLoading(true);

    try {
      await _auth.signOut();

      // 인증 정보 삭제 (요청된 경우에만)
      if (clearSavedCredentials) {
        await _clearCredentials();
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
      // Firebase를 사용하여 실제 비밀번호 재설정 이메일 전송
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ Firebase 비밀번호 재설정 이메일 전송: $email');
      setLoading(false);
      return true;
    } catch (e) {
      setError('비밀번호 재설정 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // 구글 로그인 메서드
  Future<bool> signInWithGoogle() async {
    setLoading(true);
    setError(null);

    try {
      // 구글 로그인 인스턴스 생성
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // 기존 세션 확인 및 정리
      final isSignedIn = await googleSignIn.isSignedIn();
      if (isSignedIn) {
        await googleSignIn.signOut();
      }

      // 로그인 시도
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setError('Google 로그인이 취소되었습니다.');
        setLoading(false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _fetchUserData(userCredential.user!.uid);
        setLoading(false);
        return true;
      }

      setError('Google 로그인에 실패했습니다.');
      setLoading(false);
      return false;
    } catch (e) {
      print('❌ Google 로그인 오류: $e');
      setError('로그인 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // 사용자 활동 상태 업데이트 메소드
  Future<void> updateUserActivity() async {
    if (uid == null) {
      return; // 로그인되지 않은 경우 업데이트 필요 없음
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

  // 국가 리스트 제공 메서드
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
      // ... 필요시 추가 ...
    ];
  }
}
