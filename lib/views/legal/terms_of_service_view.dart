import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 이용약관 화면
///
/// 사용자에게 앱의 이용약관을 상세하게 보여주는 화면입니다.
/// 아키텍처 설계에 따라 프레젠테이션 계층의 view로 구현되었습니다.
class TermsOfServiceView extends StatefulWidget {
  const TermsOfServiceView({Key? key}) : super(key: key);

  @override
  State<TermsOfServiceView> createState() => _TermsOfServiceViewState();
}

class _TermsOfServiceViewState extends State<TermsOfServiceView> {
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
        title: Text(_isKorean ? '이용약관' : 'Terms of Service'),
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
        _buildSectionTitle('1. 서비스 소개'),
        _buildParagraph(
          'GPS Search(이하 "서비스")는 위치 기반 검색 및 정보 제공 서비스로, 사용자들이 정확한 위치 정보를 통해 필요한 정보를 빠르게 찾을 수 있도록 도와드립니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('2. 약관 동의 및 서비스 이용'),
        _buildParagraph(
          '본 서비스를 이용하기 위해서는 이 이용약관에 동의해야 합니다. 사용자가 서비스에 가입하거나 서비스를 이용하는 것은 본 약관에 동의하는 것으로 간주됩니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('3. 서비스 이용 조건'),
        _buildParagraph(
          '서비스를 이용하기 위해서는 다음 조건을 충족해야 합니다:',
        ),
        _buildBulletPoint('만 14세 이상이어야 합니다'),
        _buildBulletPoint('본인 확인 및 계정 인증 절차를 완료해야 합니다'),
        _buildBulletPoint('정확한 개인 정보를 제공해야 합니다'),
        _buildBulletPoint('위치 정보 이용에 동의해야 합니다'),
        const SizedBox(height: 24),
        _buildSectionTitle('4. 서비스 이용 제한'),
        _buildParagraph(
          '다음과 같은 경우 서비스 이용이 제한될 수 있습니다:',
        ),
        _buildBulletPoint('타인의 권리를 침해하거나 법령을 위반하는 행위'),
        _buildBulletPoint('서비스의 정상적인 운영을 방해하는 행위'),
        _buildBulletPoint('허위 정보를 등록하거나 타인의 정보를 도용하는 행위'),
        _buildBulletPoint('서비스를 이용하여 영리 목적의 활동을 하는 행위'),
        _buildBulletPoint('기타 이용약관에 위배되는 행위'),
        const SizedBox(height: 24),
        _buildSectionTitle('5. 서비스 변경 및 중단'),
        _buildParagraph(
          '회사는 다음과 같은 경우 서비스의 전부 또는 일부를 변경하거나 중단할 수 있습니다:',
        ),
        _buildBulletPoint('서비스 시스템 점검, 보수, 교체 등 기술상의 필요가 있는 경우'),
        _buildBulletPoint('천재지변, 국가비상사태 등 불가항력적 사유가 있는 경우'),
        _buildBulletPoint('서비스 이용량의 폭주로 서비스 제공에 지장이 있는 경우'),
        _buildBulletPoint('기타 회사의 제반 사정으로 서비스 제공이 어려운 경우'),
        const SizedBox(height: 24),
        _buildSectionTitle('6. 개인정보 보호'),
        _buildParagraph(
          '회사는 개인정보 보호법 등 관련 법령에 따라 사용자의 개인정보를 보호하며, 개인정보 처리방침을 통해 자세한 내용을 확인할 수 있습니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('7. 위치정보 이용'),
        _buildParagraph(
          '본 서비스는 위치 기반 서비스 제공을 위해 사용자의 위치정보를 수집 및 이용합니다. 위치정보 수집 및 이용에 대한 자세한 내용은 위치정보 이용약관에서 확인할 수 있습니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('8. 책임 제한'),
        _buildParagraph(
          '회사는 다음과 같은 경우 책임을 지지 않습니다:',
        ),
        _buildBulletPoint('사용자의 귀책사유로 인한 서비스 이용 장애'),
        _buildBulletPoint('제3자가 제공하는 정보, 자료, 사실의 신뢰도 또는 정확성'),
        _buildBulletPoint('사용자 간 또는 사용자와 제3자 간 발생한 분쟁'),
        _buildBulletPoint('기타 회사의 귀책사유가 없는 서비스 이용 관련 손해'),
        const SizedBox(height: 24),
        _buildSectionTitle('9. 약관 변경'),
        _buildParagraph(
          '회사는 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다. 약관이 변경되는 경우에는 변경된 약관의 적용일자 및 사유를 명시하여 적용일자로부터 최소 7일 전에 공지합니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('10. 분쟁 해결 및 관할법원'),
        _buildParagraph(
          '서비스 이용으로 발생한 분쟁에 대해 소송이 제기될 경우 관할법원은 대한민국 법을 따릅니다.',
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            '최종 개정일: 2023년 1월 1일',
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
        _buildSectionTitle('1. Service Introduction'),
        _buildParagraph(
          'GPS Search (hereinafter "Service") is a location-based search and information service that helps users quickly find the necessary information through accurate location data.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('2. Terms Agreement and Service Usage'),
        _buildParagraph(
          'You must agree to these Terms of Service to use this service. When a user signs up for or uses the service, it is considered that they have agreed to these terms.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('3. Conditions for Service Use'),
        _buildParagraph(
          'To use the service, the following conditions must be met:',
        ),
        _buildBulletPoint('Must be at least 14 years of age'),
        _buildBulletPoint(
            'Must complete identity verification and account authentication procedures'),
        _buildBulletPoint('Must provide accurate personal information'),
        _buildBulletPoint('Must agree to the use of location information'),
        const SizedBox(height: 24),
        _buildSectionTitle('4. Service Use Restrictions'),
        _buildParagraph(
          'Service use may be restricted in the following cases:',
        ),
        _buildBulletPoint(
            'Actions that infringe on the rights of others or violate laws'),
        _buildBulletPoint(
            'Actions that interfere with the normal operation of the service'),
        _buildBulletPoint(
            'Registering false information or impersonating others'),
        _buildBulletPoint('Using the service for profit-making activities'),
        _buildBulletPoint('Other actions that violate the terms of service'),
        const SizedBox(height: 24),
        _buildSectionTitle('5. Service Changes and Discontinuation'),
        _buildParagraph(
          'The company may change or discontinue all or part of the service in the following cases:',
        ),
        _buildBulletPoint(
            'When technical needs arise such as system inspection, repair, or replacement'),
        _buildBulletPoint(
            'In case of force majeure such as natural disasters or national emergencies'),
        _buildBulletPoint(
            'When service provision is hindered due to a surge in service usage'),
        _buildBulletPoint(
            'When service provision is difficult due to other company circumstances'),
        const SizedBox(height: 24),
        _buildSectionTitle('6. Personal Information Protection'),
        _buildParagraph(
          'The company protects users\' personal information in accordance with relevant laws such as the Personal Information Protection Act, and details can be found in the Privacy Policy.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('7. Use of Location Information'),
        _buildParagraph(
          'This service collects and uses user location information to provide location-based services. Detailed information on the collection and use of location information can be found in the Location Information Terms of Use.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('8. Limitation of Liability'),
        _buildParagraph(
          'The company is not responsible in the following cases:',
        ),
        _buildBulletPoint('Service usage obstacles caused by user\'s fault'),
        _buildBulletPoint(
            'Reliability or accuracy of information, materials, and facts provided by third parties'),
        _buildBulletPoint(
            'Disputes between users or between users and third parties'),
        _buildBulletPoint(
            'Other service-related damages where the company is not at fault'),
        const SizedBox(height: 24),
        _buildSectionTitle('9. Terms Changes'),
        _buildParagraph(
          'The company may change these terms within the range that does not violate relevant laws. When the terms are changed, the application date and reasons for the changed terms will be specified and announced at least 7 days before the application date.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('10. Dispute Resolution and Jurisdiction'),
        _buildParagraph(
          'In case a lawsuit is filed regarding disputes arising from the use of the service, the jurisdiction follows the laws of the Republic of Korea.',
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'Last revised: January 1, 2023',
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
