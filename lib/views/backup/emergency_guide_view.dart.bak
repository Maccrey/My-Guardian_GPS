// *****************************************************************************
// ******** 중요: 이 파일은 보호된 응급사항 관련 코드입니다. 절대 수정하지 마세요. ********
// *****************************************************************************

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmergencyGuideView extends StatelessWidget {
  const EmergencyGuideView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('응급 상황 가이드'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildEmergencyCard(
            title: '심폐소생술(CPR)',
            description: '심장이 멈춘 사람에게 실시하는 응급처치',
            icon: Icons.favorite,
            color: Colors.red,
            onTap: () => _showGuideDetails(context, 'cpr'),
          ),
          _buildEmergencyCard(
            title: '기도 폐쇄 응급처치',
            description: '이물질로 기도가 막혔을 때의 응급처치',
            icon: Icons.airline_seat_flat,
            color: Colors.orange,
            onTap: () => _showGuideDetails(context, 'choking'),
          ),
          _buildEmergencyCard(
            title: '화상 응급처치',
            description: '화상을 입었을 때의 응급처치',
            icon: Icons.whatshot,
            color: Colors.deepOrange,
            onTap: () => _showGuideDetails(context, 'burn'),
          ),
          _buildEmergencyCard(
            title: '골절 응급처치',
            description: '뼈가 부러졌을 때의 응급처치',
            icon: Icons.healing,
            color: Colors.purple,
            onTap: () => _showGuideDetails(context, 'fracture'),
          ),
          _buildEmergencyCard(
            title: '출혈 응급처치',
            description: '출혈이 심할 때의 응급처치',
            icon: Icons.opacity,
            color: Colors.red.shade800,
            onTap: () => _showGuideDetails(context, 'bleeding'),
          ),
          _buildEmergencyCard(
            title: '뇌졸중 응급처치',
            description: '뇌졸중 증상과 응급처치',
            icon: Icons.psychology,
            color: Colors.blue,
            onTap: () => _showGuideDetails(context, 'stroke'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.emergency,
            size: 60,
            color: Colors.red,
          ),
          SizedBox(height: 16),
          Text(
            '응급 상황 가이드',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '응급 상황 발생 시 참고할 수 있는 기본적인 응급처치 가이드입니다.\n실제 응급 상황에서는 119에 신고하는 것이 가장 중요합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 28,
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuideDetails(BuildContext context, String guideType) {
    String title = '';
    List<Map<String, String>> steps = [];

    switch (guideType) {
      case 'cpr':
        title = '심폐소생술(CPR) 가이드';
        steps = [
          {'title': '1. 반응 확인', 'content': '환자의 어깨를 가볍게 두드리며 의식이 있는지 확인합니다.'},
          {
            'title': '2. 도움 요청',
            'content': '주변 사람에게 119 신고를 요청하고 AED를 가져오도록 합니다.'
          },
          {
            'title': '3. 호흡 확인',
            'content': '환자의 가슴 움직임을 보고, 호흡이 정상인지 10초 이내로 확인합니다.'
          },
          {
            'title': '4. 가슴 압박',
            'content': '양손을 깍지 끼고 가슴 중앙에 놓은 후 분당 100-120회 속도로 5-6cm 깊이로 압박합니다.'
          },
          {
            'title': '5. 가슴 압박 30회 후',
            'content':
                '인공호흡을 2회 실시합니다. (구조자가 인공호흡 방법을 모르거나 꺼려진다면 가슴압박만 계속해도 됩니다.)'
          },
          {
            'title': '6. 반복',
            'content': '119 구급대원이 도착하거나 환자가 회복될 때까지 30:2 비율로 계속합니다.'
          },
        ];
        break;
      case 'choking':
        title = '기도 폐쇄 응급처치';
        steps = [
          {
            'title': '1. 확인',
            'content': '환자가 말을 하지 못하고, 호흡 곤란, 얼굴이 파랗게 변하면 기도 폐쇄를 의심합니다.'
          },
          {
            'title': '2. 등 두드리기',
            'content': '환자의 등 가운데를 손바닥 밑부분으로 5회 강하게 두드립니다.'
          },
          {
            'title': '3. 복부 밀어내기(하임리히법)',
            'content':
                '환자의 뒤에서 양팔로 감싸 안고, 배꼽과 명치 사이에 주먹을 위치시킨 후 다른 손으로 주먹을 감싸고 안쪽 위쪽으로 강하게 밀어 올립니다.'
          },
          {
            'title': '4. 반복',
            'content': '이물질이 나올 때까지 등 두드리기와 복부 밀어내기를 번갈아 5회씩 반복합니다.'
          },
          {'title': '5. 의식 잃을 경우', 'content': '환자가 의식을 잃으면 심폐소생술을 시작합니다.'},
        ];
        break;
      case 'burn':
        title = '화상 응급처치';
        steps = [
          {
            'title': '1. 화상 부위 냉각',
            'content': '화상 부위를 차가운 흐르는 물에 10-20분간 담그거나 씻어냅니다.'
          },
          {'title': '2. 장신구 제거', 'content': '화상 부위의 반지, 시계, 옷 등을 조심스럽게 제거합니다.'},
          {'title': '3. 물집 보호', 'content': '물집은 터뜨리지 말고 깨끗한 거즈나 천으로 덮어줍니다.'},
          {'title': '4. 금기사항', 'content': '화상 부위에 연고, 기름, 치약 등을 바르지 마십시오.'},
          {
            'title': '5. 병원 방문',
            'content': '큰 화상이나 얼굴, 손, 발, 생식기관의 화상은 반드시 병원에 방문해야 합니다.'
          },
        ];
        break;
      case 'fracture':
        title = '골절 응급처치';
        steps = [
          {'title': '1. 안정', 'content': '부상 부위를 움직이지 않도록 합니다.'},
          {'title': '2. 고정', 'content': '부목이나 단단한 물건을 사용해 부상 부위를 고정합니다.'},
          {'title': '3. 냉찜질', 'content': '부상 부위에 얼음팩을 수건으로 감싸 20분씩 적용합니다.'},
          {'title': '4. 거상', 'content': '가능하다면 부상 부위를 심장보다 높게 유지합니다.'},
          {
            'title': '5. 의료기관 방문',
            'content': '고정 후 최대한 빨리 의료기관을 방문하여 정확한 진단과 처치를 받습니다.'
          },
        ];
        break;
      case 'bleeding':
        title = '출혈 응급처치';
        steps = [
          {'title': '1. 직접 압박', 'content': '깨끗한 천이나 거즈로 출혈 부위를 직접 압박합니다.'},
          {'title': '2. 거상', 'content': '가능하다면 출혈 부위를 심장보다 높게 유지합니다.'},
          {'title': '3. 압박 유지', 'content': '출혈이 멈출 때까지 계속 압박을 유지합니다(최소 15분).'},
          {'title': '4. 붕대 감기', 'content': '출혈이 멈추면 깨끗한 붕대로 부위를 감싸줍니다.'},
          {
            'title': '5. 쇼크 징후 관찰',
            'content':
                '환자가 창백해지거나, 차갑고 축축한 피부, 빠른 맥박, 호흡 등의 증상이 나타나면 쇼크를 의심하고 119에 신고합니다.'
          },
        ];
        break;
      case 'stroke':
        title = '뇌졸중 응급처치';
        steps = [
          {
            'title': 'F (Face, 얼굴)',
            'content': '환자에게 웃어보라고 하여 얼굴의 한쪽이 처지는지 확인합니다.'
          },
          {
            'title': 'A (Arms, 팔)',
            'content': '양팔을 들어올리게 하여 한쪽 팔이 내려가는지 확인합니다.'
          },
          {
            'title': 'S (Speech, 말)',
            'content': '간단한 문장을 따라 말하게 하여 말이 어눌한지 확인합니다.'
          },
          {
            'title': 'T (Time, 시간)',
            'content': '위의 증상 중 하나라도 있다면 즉시 119에 신고합니다. 증상이 시작된 시간을 기록해두세요.'
          },
          {
            'title': '응급처치',
            'content': '환자를 편안하게 눕히고 의식과 호흡을 계속 확인하며 구급대원이 도착할 때까지 기다립니다.'
          },
        ];
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: steps.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps[index]['title']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                steps[index]['content']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (index < steps.length - 1)
                                const Divider(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Get.toNamed('/emergency-contacts');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('긴급 연락처 보기'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
