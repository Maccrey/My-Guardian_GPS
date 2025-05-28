import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 개인정보 처리방침 화면
///
/// 사용자에게 앱의 개인정보 처리방침을 상세하게 보여주는 화면입니다.
/// 아키텍처 설계에 따라 프레젠테이션 계층의 view로 구현되었습니다.
class PrivacyPolicyView extends StatefulWidget {
  const PrivacyPolicyView({Key? key}) : super(key: key);

  @override
  State<PrivacyPolicyView> createState() => _PrivacyPolicyViewState();
}

class _PrivacyPolicyViewState extends State<PrivacyPolicyView> {
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
        title: Text(_isKorean ? '개인정보 처리방침' : 'Privacy Policy'),
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
        _buildSectionTitle('1. 개인정보의 처리 목적'),
        _buildParagraph(
          'GPS Search(이하 "앱")은 위치 추적, 위치 공유, 긴급 상황 알림 등의 서비스를 제공하기 위해 필요한 최소한의 개인정보를 수집합니다. 수집된 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 개인정보 보호법 제18조에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.',
        ),
        _buildSubSectionTitle('• 서비스 제공 목적'),
        _buildBulletPoint('위치 기반 서비스 제공'),
        _buildBulletPoint('긴급 상황 시 지정된 연락처로 알림 전송'),
        _buildBulletPoint('사용자 간 위치 정보 공유'),
        const SizedBox(height: 24),
        _buildSectionTitle('2. 수집하는 개인정보 항목'),
        _buildParagraph(
          '앱은 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다:',
        ),
        _buildSubSectionTitle('• 필수 항목'),
        _buildBulletPoint('이메일 주소 - 계정 식별 및 인증'),
        _buildBulletPoint('위치 정보 - 위치 기반 서비스 제공'),
        _buildSubSectionTitle('• 선택 항목'),
        _buildBulletPoint('긴급 연락처 - 긴급 상황 알림 전송'),
        _buildBulletPoint('프로필 정보 (이름, 사진) - 서비스 내 사용자 식별'),
        const SizedBox(height: 24),
        _buildSectionTitle('3. 개인정보의 보유 및 이용기간'),
        _buildParagraph(
          '원칙적으로 개인정보는 회원 탈퇴 시까지 보유합니다. 다만, 다음의 경우에는 예외적으로 명시한 기간 동안 개인정보를 보관합니다:',
        ),
        _buildBulletPoint('관계 법령에 따라 보존할 필요가 있는 경우: 관련 법령에서 정한 기간'),
        _buildBulletPoint('분쟁 해결, 민원 처리 등을 위해 필요한 경우: 최대 3년'),
        const SizedBox(height: 24),
        _buildSectionTitle('4. 개인정보의 안전성 확보 조치'),
        _buildParagraph(
          '앱은 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:',
        ),
        _buildBulletPoint('개인정보 암호화 전송 및 저장'),
        _buildBulletPoint('접근 권한 제한 및 관리'),
        _buildBulletPoint('정기적인 보안 업데이트 및 취약점 점검'),
        const SizedBox(height: 24),
        _buildSectionTitle('5. 개인정보의 제3자 제공'),
        _buildParagraph(
          '앱은 원칙적으로 사용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외적으로 제3자에게 제공할 수 있습니다:',
        ),
        _buildBulletPoint('사용자가 명시적으로 동의한 경우'),
        _buildBulletPoint('법령에 의해 제공이 요구되는 경우'),
        _buildBulletPoint('긴급 상황 시 지정된 연락처로 정보 제공'),
        const SizedBox(height: 24),
        _buildSectionTitle('6. 사용자의 권리와 행사 방법'),
        _buildParagraph(
          '사용자는 개인정보에 대한 다음과 같은 권리를 가지며, 앱 내 설정 메뉴 또는 문의 채널을 통해 행사할 수 있습니다:',
        ),
        _buildBulletPoint('개인정보 열람, 정정, 삭제 요청'),
        _buildBulletPoint('개인정보 처리 정지 요청'),
        _buildBulletPoint('동의 철회 (회원 탈퇴)'),
        const SizedBox(height: 24),
        _buildSectionTitle('7. 개인정보 자동 수집 장치의 설치/운영 및 거부'),
        _buildParagraph(
          '앱은 사용자 경험 개선을 위해 쿠키 및 유사 기술을 사용할 수 있습니다. 사용자는 앱 설정에서 이러한 기능을 비활성화할 수 있으나, 일부 서비스의 이용이 제한될 수 있습니다.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('8. 개인정보 보호책임자'),
        _buildParagraph('개인정보 보호에 관한 문의사항은 다음의 연락처로 문의해 주시기 바랍니다:'),
        _buildIndentedText('• 이름: 임석훈'),
        _buildIndentedText('• 직위: 개인정보 보호책임자'),
        _buildIndentedText('• 이메일: m01071630214@gmail.com'),
        const SizedBox(height: 24),
        _buildSectionTitle('9. 개인정보 처리방침 변경'),
        _buildParagraph(
          '이 개인정보 처리방침은 2023년 1월 1일부터 적용됩니다. 법령, 정책 또는 보안 기술의 변경에 따라 내용이 추가, 삭제 및 수정될 수 있습니다. 변경사항이 있는 경우 앱 내 공지사항 또는 별도의 알림을 통해 공지할 예정입니다.',
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
        _buildSectionTitle('1. Purpose of Processing Personal Information'),
        _buildParagraph(
          'GPS Search (hereinafter "App") collects the minimum personal information necessary to provide services such as location tracking, location sharing, and emergency notifications. The collected personal information will not be used for purposes other than those specified below, and necessary measures will be taken, such as obtaining separate consent in accordance with the Personal Information Protection Act Article 18, if the purpose of use changes.',
        ),
        _buildSubSectionTitle('• Service Provision Purpose'),
        _buildBulletPoint('Providing location-based services'),
        _buildBulletPoint(
            'Sending notifications to designated contacts in emergency situations'),
        _buildBulletPoint('Sharing location information between users'),
        const SizedBox(height: 24),
        _buildSectionTitle('2. Personal Information Items Collected'),
        _buildParagraph(
          'The App collects the following personal information to provide services:',
        ),
        _buildSubSectionTitle('• Required Items'),
        _buildBulletPoint(
            'Email address - Account identification and authentication'),
        _buildBulletPoint(
            'Location information - Providing location-based services'),
        _buildSubSectionTitle('• Optional Items'),
        _buildBulletPoint(
            'Emergency contacts - Sending emergency notifications'),
        _buildBulletPoint(
            'Profile information (name, photo) - User identification within the service'),
        const SizedBox(height: 24),
        _buildSectionTitle(
            '3. Retention and Usage Period of Personal Information'),
        _buildParagraph(
          'In principle, personal information is retained until membership withdrawal. However, in the following cases, personal information is kept for the specified period as an exception:',
        ),
        _buildBulletPoint(
            'When there is a need to preserve according to relevant laws: For the period specified by the law'),
        _buildBulletPoint(
            'When necessary for dispute resolution, complaint handling, etc.: Maximum 3 years'),
        const SizedBox(height: 24),
        _buildSectionTitle(
            '4. Measures to Ensure the Security of Personal Information'),
        _buildParagraph(
          'The App takes the following measures to ensure the security of personal information:',
        ),
        _buildBulletPoint(
            'Encryption of personal information during transmission and storage'),
        _buildBulletPoint('Access rights restriction and management'),
        _buildBulletPoint('Regular security updates and vulnerability checks'),
        const SizedBox(height: 24),
        _buildSectionTitle(
            '5. Provision of Personal Information to Third Parties'),
        _buildParagraph(
          'The App does not provide user\'s personal information to third parties in principle. However, in the following cases, it may exceptionally be provided to third parties:',
        ),
        _buildBulletPoint('When the user has explicitly consented'),
        _buildBulletPoint('When the provision is required by law'),
        _buildBulletPoint(
            'When providing information to designated contacts in emergency situations'),
        const SizedBox(height: 24),
        _buildSectionTitle('6. User Rights and Exercise Methods'),
        _buildParagraph(
          'Users have the following rights regarding their personal information and can exercise them through the settings menu or inquiry channels within the App:',
        ),
        _buildBulletPoint(
            'Request for access, correction, and deletion of personal information'),
        _buildBulletPoint(
            'Request for suspension of personal information processing'),
        _buildBulletPoint('Withdrawal of consent (membership withdrawal)'),
        const SizedBox(height: 24),
        _buildSectionTitle(
            '7. Installation/Operation and Rejection of Automatic Personal Information Collection Devices'),
        _buildParagraph(
          'The App may use cookies and similar technologies to improve user experience. Users can disable these features in the App settings, but some services may be limited.',
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('8. Personal Information Protection Officer'),
        _buildParagraph(
            'Please contact the following for inquiries regarding personal information protection:'),
        _buildIndentedText('• Name: Seokhoon Lim'),
        _buildIndentedText(
            '• Position: Personal Information Protection Officer'),
        _buildIndentedText('• Email: m01071630214@gmail.com'),
        const SizedBox(height: 24),
        _buildSectionTitle('9. Changes to the Privacy Policy'),
        _buildParagraph(
          'This privacy policy is effective from January 1, 2023. Content may be added, deleted, or modified in accordance with changes in laws, policies, or security technologies. Any changes will be announced through in-app notices or separate notifications.',
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

  // 소제목 위젯
  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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

  // 들여쓰기 텍스트 위젯
  Widget _buildIndentedText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}
