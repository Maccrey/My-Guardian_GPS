import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 앱 정보 화면
///
/// 사용자에게 앱의 상세 정보를 보여주는 화면입니다.
/// 아키텍처 설계에 따라 프레젠테이션 계층의 view로 구현되었습니다.
class AppInfoView extends StatefulWidget {
  const AppInfoView({Key? key}) : super(key: key);

  @override
  State<AppInfoView> createState() => _AppInfoViewState();
}

class _AppInfoViewState extends State<AppInfoView> {
  bool _isKorean = true;

  void _toggleLanguage() {
    setState(() {
      _isKorean = !_isKorean;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isKorean ? '앱 정보' : 'App Information'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: _isKorean ? 'Switch to English' : '한국어로 전환',
            onPressed: _toggleLanguage,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _isKorean ? 'EN' : 'KO',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _isKorean ? _buildKoreanContent() : _buildEnglishContent(),
        ),
      ),
    );
  }

  // 한국어 콘텐츠
  Widget _buildKoreanContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogoSection(),
        const SizedBox(height: 24),
        _buildSectionTitle('앱 정보'),
        _buildInfoRow('앱 이름', 'GPS Search'),
        _buildInfoRow('버전', '1.0.0'),
        _buildInfoRow('출시일', '2023년 1월 1일'),
        _buildInfoRow('개발자', '임석훈'),
        _buildInfoRow('라이선스', 'MIT'),
        const SizedBox(height: 24),
        _buildSectionTitle('앱 소개'),
        _buildParagraph(
          'GPS Search는 정확한 위치 기반 검색을 제공하여 사용자가 필요한 정보를 빠르게 찾을 수 있도록 도와주는 앱입니다. 위치 추적, 위치 공유, 긴급 상황 알림 등의 다양한 기능을 제공합니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('주요 기능'),
        _buildBulletPoint('정확한 위치 기반 검색'),
        _buildBulletPoint('실시간 위치 추적 및 공유'),
        _buildBulletPoint('긴급 상황 시 지정된 연락처로 알림 전송'),
        _buildBulletPoint('사용자 간 위치 정보 공유'),
        _buildBulletPoint('지도 기반 내비게이션'),
        const SizedBox(height: 24),
        _buildSectionTitle('기술 스택'),
        _buildBulletPoint('프레임워크: Flutter'),
        _buildBulletPoint('상태 관리: GetX'),
        _buildBulletPoint('데이터베이스: Firebase'),
        _buildBulletPoint('지도 서비스: Google Maps API'),
        _buildBulletPoint('위치 서비스: Geolocation'),
        const SizedBox(height: 24),
        _buildSectionTitle('연락처'),
        _buildParagraph('앱에 관한 문의사항이나 피드백은 아래 연락처로 보내주세요:'),
        _buildInfoRow('이메일', 'm01071630214@gmail.com'),
        _buildInfoRow('웹사이트', 'https://gpssearch.app'),
        const SizedBox(height: 24),
        _buildSectionTitle('감사의 말'),
        _buildParagraph(
          '이 앱을 개발하는 데 도움을 주신 모든 분들께 감사드립니다. 특히 테스트와 피드백에 참여해 주신 사용자 여러분께 진심으로 감사드립니다.',
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            '© 2023 GPS Search. All rights reserved.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 영어 콘텐츠
  Widget _buildEnglishContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogoSection(),
        const SizedBox(height: 24),
        _buildSectionTitle('App Information'),
        _buildInfoRow('App Name', 'GPS Search'),
        _buildInfoRow('Version', '1.0.0'),
        _buildInfoRow('Release Date', 'January 1, 2023'),
        _buildInfoRow('Developer', 'Seokhoon Lim'),
        _buildInfoRow('License', 'MIT'),
        const SizedBox(height: 24),
        _buildSectionTitle('App Introduction'),
        _buildParagraph(
          'GPS Search is an app that provides accurate location-based search to help users quickly find the information they need. It offers various features such as location tracking, location sharing, and emergency notifications.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Key Features'),
        _buildBulletPoint('Accurate location-based search'),
        _buildBulletPoint('Real-time location tracking and sharing'),
        _buildBulletPoint('Emergency notifications to designated contacts'),
        _buildBulletPoint('Location information sharing between users'),
        _buildBulletPoint('Map-based navigation'),
        const SizedBox(height: 24),
        _buildSectionTitle('Technology Stack'),
        _buildBulletPoint('Framework: Flutter'),
        _buildBulletPoint('State Management: GetX'),
        _buildBulletPoint('Database: Firebase'),
        _buildBulletPoint('Map Services: Google Maps API'),
        _buildBulletPoint('Location Services: Geolocation'),
        const SizedBox(height: 24),
        _buildSectionTitle('Contact Information'),
        _buildParagraph(
            'For inquiries or feedback about the app, please contact us at:'),
        _buildInfoRow('Email', 'm01071630214@gmail.com'),
        _buildInfoRow('Website', 'https://gpssearch.app'),
        const SizedBox(height: 24),
        _buildSectionTitle('Acknowledgements'),
        _buildParagraph(
          'Thank you to everyone who helped in the development of this app. Special thanks to all users who participated in testing and provided feedback.',
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            '© 2023 GPS Search. All rights reserved.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 로고 섹션
  Widget _buildLogoSection() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.location_on,
              size: 60,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'GPS Search',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _isKorean ? '정확한 위치 기반 서비스' : 'Accurate Location-based Service',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 섹션 제목 위젯
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 문단 텍스트 위젯
  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  // 글머리 기호 항목 위젯
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
