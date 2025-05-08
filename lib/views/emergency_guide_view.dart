import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmergencyGuideView extends StatelessWidget {
  const EmergencyGuideView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('응급사항 대처 가이드'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        children: [
          _buildHeader(),
          _buildEmergencyCategory(
            context,
            title: '기본 응급처치',
            icon: Icons.health_and_safety,
            color: Colors.blue,
            items: [
              EmergencyItem(
                title: '심폐소생술 (CPR)',
                icon: Icons.favorite,
                description: '1. 의식과 호흡 확인\n'
                    '2. 119에 신고\n'
                    '3. 가슴 중앙에 손을 겹쳐 놓고 분당 100-120회 속도로 5-6cm 깊이로 압박\n'
                    '4. 30회 압박 후 2회 인공호흡 (인공호흡이 불가능하면 가슴압박만 계속)\n'
                    '5. 구조대가 도착하거나 환자가 회복될 때까지 반복',
              ),
              EmergencyItem(
                title: '기도 폐쇄 (하임리히법)',
                icon: Icons.air,
                description: '1. 환자 뒤에 서서 양팔로 허리를 감싸줌\n'
                    '2. 한 손은 주먹을 쥐고 배꼽과 명치 사이에 위치\n'
                    '3. 다른 손으로 주먹 쥔 손을 감싸 안쪽 위로 강하게 당김\n'
                    '4. 이물질이 나올 때까지 반복',
              ),
              EmergencyItem(
                title: '지혈 방법',
                icon: Icons.bloodtype,
                description: '1. 깨끗한 천이나 거즈로 출혈 부위 직접 압박\n'
                    '2. 출혈 부위를 심장보다 높게 유지\n'
                    '3. 압박을 15-20분간 유지\n'
                    '4. 지혈이 안 되면 병원 방문',
              ),
            ],
          ),
          _buildEmergencyCategory(
            context,
            title: '자연재해 대처',
            icon: Icons.storm,
            color: Colors.orange,
            items: [
              EmergencyItem(
                title: '지진 발생 시',
                icon: Icons.vibration,
                description: '1. 테이블 아래나 내부 기둥 근처로 대피\n'
                    '2. 머리를 보호하고 흔들림이 멈출 때까지 기다림\n'
                    '3. 흔들림이 멈추면 신속히 밖으로 대피 (엘리베이터 사용 금지)\n'
                    '4. 건물, 전봇대 등에서 떨어져 넓은 공간으로 이동\n'
                    '5. 여진에 대비하고 라디오나 공식 매체를 통해 정보 확인',
              ),
              EmergencyItem(
                title: '홍수 발생 시',
                icon: Icons.water,
                description: '1. 높은 지대로 대피\n'
                    '2. 흐르는 물에 들어가지 않기 (15cm 깊이의 물도 사람을 쓰러트릴 수 있음)\n'
                    '3. 전자제품, 전기 시설에서 멀리 떨어지기\n'
                    '4. 대피 지시가 있을 경우 즉시 따름\n'
                    '5. 침수된 도로 운전 삼가 (30cm 이상 물에 차량이 떠오를 수 있음)',
              ),
              EmergencyItem(
                title: '태풍/강풍 발생 시',
                icon: Icons.air_outlined,
                description: '1. 튼튼한 건물 안으로 대피\n'
                    '2. 창문에서 멀리 떨어지고 창문이나 출입문 개방 금지\n'
                    '3. 외출 삼가고 필요시 단단한 신발과 두꺼운 옷 착용\n'
                    '4. 정전에 대비해 손전등, 비상식량, 물 등 준비\n'
                    '5. 날아오는 물체에 주의하고 전선 근처 접근 금지',
              ),
            ],
          ),
          _buildEmergencyCategory(
            context,
            title: '생존 기술',
            icon: Icons.hiking,
            color: Colors.green,
            items: [
              EmergencyItem(
                title: '안전한 식수 확보',
                icon: Icons.water_drop,
                description: '1. 끓이기: 물을 1분 이상 완전히 끓여 사용\n'
                    '2. 정수 필터 사용\n'
                    '3. 정수약품(정수약, 요오드, 표백제) 사용: 지시에 따라 적정량 첨가\n'
                    '4. 태양열 소독: 투명 페트병에 물을 채워 6시간 이상 직사광선 노출\n'
                    '5. 빗물 수집: 깨끗한 용기에 빗물 모으기',
              ),
              EmergencyItem(
                title: '방향 찾기',
                icon: Icons.explore,
                description: '1. 나침반 사용법: N(북), S(남), E(동), W(서) 확인\n'
                    '2. 해와 시계 이용: 시계 시침을 태양 방향으로 향하게 하고, 시침과 12시 사이 각도 이등분선이 남쪽\n'
                    '3. 밤에는 북극성 찾기: 북두칠성에서 끝 두 별 사이 거리의 5배 연장선상에 있는 별이 북극성\n'
                    '4. 이끼 관찰: 주로 나무나 바위의, 북쪽 면에 이끼가 많이 자람\n'
                    '5. 지형지물 활용: 산의 능선, 강의 방향 등을 통해 위치 파악',
              ),
              EmergencyItem(
                title: '비상 대피소 만들기',
                icon: Icons.home_outlined,
                description: '1. 자연 대피소 활용: 동굴, 바위 돌출부 등 자연 지형 이용\n'
                    '2. 나뭇가지 대피소: 튼튼한 나뭇가지로 A자 프레임 구조 만들기\n'
                    '3. 눈 동굴: 눈이 많은 지역에서 눈을 파서 대피소 만들기\n'
                    '4. 비닐/천 활용: 방수 천이나 비닐을 나뭇가지로 지지해 간이 텐트 구성\n'
                    '5. 단열 고려: 바닥에 나뭇잎, 솔잎 등을 깔아 땅의 냉기 차단',
              ),
            ],
          ),
          _buildEmergencyCategory(
            context,
            title: '위험한 상황',
            icon: Icons.warning,
            color: Colors.red,
            items: [
              EmergencyItem(
                title: '화재 발생 시',
                icon: Icons.local_fire_department,
                description: '1. 즉시 화재경보기 작동 및 119 신고\n'
                    '2. 작은 화재는 소화기로 진화 시도, 큰 화재는 즉시 대피\n'
                    '3. 연기 속에서는 낮은 자세로 이동 (바닥 가까이 공기가 깨끗함)\n'
                    '4. 닫힌 문을 열기 전 문손잡이 온도 확인, 뜨겁다면 다른 출구 찾기\n'
                    '5. 옷에 불이 붙으면 "멈추고, 엎드리고, 구르기" 실행',
              ),
              EmergencyItem(
                title: '익수 사고 시',
                icon: Icons.pool,
                description: '1. "던지고, 뻗고, 가고, 끌고" 원칙 준수\n'
                    '2. 가능하면 구명도구를 던져 구조\n'
                    '3. 직접 들어가는 것은 최후의 수단 (훈련된 사람만)\n'
                    '4. 구조 후 체온 유지, 필요시 CPR 실시\n'
                    '5. 전문가에게 상태 확인 필요',
              ),
              EmergencyItem(
                title: '교통사고 발생 시',
                icon: Icons.car_crash,
                description: '1. 안전한 곳으로 이동 및 비상등 켜기\n'
                    '2. 2차 사고 방지: 삼각대 설치 (고속도로는 100m 이상 뒤)\n'
                    '3. 119와 112에 신고 (위치, 상황, 부상자 정보 전달)\n'
                    '4. 부상자를 함부로 움직이지 말고 전문가 도착 기다리기\n'
                    '5. 증거 확보: 사고 현장, 차량 번호판 등 사진 촬영',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '※ 본 정보는 기본적인 응급 대처 방법을 안내하며, 전문적인 의료 조언을 대체할 수 없습니다. 응급 상황 시 즉시 119에 연락하세요.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.blue.shade50,
      child: Column(
        children: const [
          Icon(
            Icons.health_and_safety,
            size: 60,
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            '응급 상황 대처 가이드',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '위험한 상황에서 스스로를 보호하고 생존하는 데 필요한 기본 지식',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            '응급 상황 시 항상 가능하면 119에 신고하세요!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCategory(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<EmergencyItem> items,
  }) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      collapsedBackgroundColor: color.withOpacity(0.1),
      backgroundColor: color.withOpacity(0.05),
      children: items.map((item) => _buildEmergencyItemTile(item)).toList(),
    );
  }

  Widget _buildEmergencyItemTile(EmergencyItem item) {
    return ExpansionTile(
      title: Row(
        children: [
          Icon(item.icon, size: 20),
          const SizedBox(width: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            item.description,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class EmergencyItem {
  final String title;
  final IconData icon;
  final String description;

  EmergencyItem({
    required this.title,
    required this.icon,
    required this.description,
  });
}
