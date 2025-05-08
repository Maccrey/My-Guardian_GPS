import 'dart:async';
import 'package:get/get.dart';
import '../models/user_model.dart';

class AuthService extends GetxController {
  final RxBool _isAuthenticated = false.obs;
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final RxBool _isLoading = false.obs;
  final Rx<String?> _error = Rx<String?>(null);

  // Getters
  bool get isAuthenticated => _isAuthenticated.value;
  UserModel? get currentUser => _currentUser.value;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  // Login 메소드
  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);

    try {
      // API 호출을 시뮬레이션
      await Future.delayed(const Duration(seconds: 2));

      // 테스트용 로그인 검증
      if (email == 'test@example.com' && password == 'Password1!') {
        _currentUser.value = UserModel(
          email: email,
          nickname: '테스트유저',
        );
        _isAuthenticated.value = true;
        setLoading(false);
        return true;
      } else {
        setError('이메일 또는 비밀번호가 올바르지 않습니다');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('로그인 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // 회원가입 메소드
  Future<bool> register(UserModel user) async {
    setLoading(true);
    setError(null);

    try {
      // API 호출을 시뮬레이션
      await Future.delayed(const Duration(seconds: 2));

      // 실제 서비스에서는 서버에 회원가입 요청을 보냄
      print('사용자 등록: ${user.toJson()}');

      // 회원가입 성공 시뮬레이션
      _currentUser.value = user;
      _isAuthenticated.value = false; // 회원가입 후 로그인은 별도로 진행
      setLoading(false);
      return true;
    } catch (e) {
      setError('회원가입 중 오류가 발생했습니다: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // 로그아웃 메소드
  Future<void> logout() async {
    setLoading(true);

    try {
      await Future.delayed(const Duration(seconds: 1));

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
