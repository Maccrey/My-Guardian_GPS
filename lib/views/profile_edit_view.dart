import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ProfileEditController 바인딩 클래스
class ProfileEditBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProfileEditController>(() => ProfileEditController());
  }
}

class ProfileEditController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final formKey = GlobalKey<FormState>();

  final Rx<UserModel> user = UserModel().obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isSuccess = false.obs;

  // 프로필 이미지 관련 변수
  final Rx<File?> profileImage = Rx<File?>(null);
  final RxBool isImageSelected = false.obs;

  // 국가 선택 관련 변수
  final RxString selectedCountry = RxString('');
  final RxString selectedCountryCode = RxString('');

  // 생년월일 관련 변수
  final Rx<DateTime?> selectedBirthDate = Rx<DateTime?>(null);

  // TextEditingController
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    try {
      // AuthService가 등록되어 있는지 확인
      if (!Get.isRegistered<AuthService>()) {
        debugPrint('⚠️ AuthService가 등록되어 있지 않습니다.');
        Get.put(AuthService(), permanent: true);
      }

      initUserData();
    } catch (e) {
      debugPrint('⚠️ ProfileEditController 초기화 오류: $e');
      errorMessage.value = '사용자 정보를 불러오는 중 오류가 발생했습니다.';
    }
  }

  @override
  void onClose() {
    nicknameController.dispose();
    countryController.dispose();
    birthDateController.dispose();
    super.onClose();
  }

  void initUserData() {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        user.value = currentUser;

        // TextEditingController 초기화
        nicknameController.text = currentUser.nickname ?? '';
        countryController.text = currentUser.country ?? '';

        // 생년월일 초기화
        if (currentUser.birthDate != null) {
          selectedBirthDate.value = currentUser.birthDate;
          birthDateController.text =
              DateFormat('yyyy-MM-dd').format(currentUser.birthDate!);
        }

        // 국가 코드 초기화 시도
        if (currentUser.country != null && currentUser.country!.isNotEmpty) {
          final countries = _authService.getCountries();
          final countryData = countries.firstWhere(
            (c) => c['name'] == currentUser.country,
            orElse: () => {'name': currentUser.country, 'code': ''},
          );

          selectedCountry.value = countryData['name'];
          selectedCountryCode.value = countryData['code'];
        }
      } else {
        debugPrint('⚠️ 현재 로그인된 사용자가 없습니다.');
        errorMessage.value = '로그인 후 이용해주세요.';

        // 로그인 페이지로 리디렉션
        Future.delayed(const Duration(seconds: 1), () {
          Get.offAllNamed('/');
        });
      }
    } catch (e) {
      debugPrint('⚠️ 사용자 데이터 초기화 오류: $e');
      errorMessage.value = '사용자 정보를 불러오는 중 오류가 발생했습니다.';
    }
  }

  // 국가 목록 가져오기
  List<Map<String, dynamic>> getCountries() {
    return _authService.getCountries();
  }

  // 국가 플래그 가져오기
  String getCountryFlag(String countryCode) {
    if (countryCode.isEmpty) return '🏳️';

    final flagOffset = 0x1F1E6;
    final asciiOffset = 0x41;

    final firstChar = countryCode.codeUnitAt(0) - asciiOffset + flagOffset;
    final secondChar = countryCode.codeUnitAt(1) - asciiOffset + flagOffset;

    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }

  // 선택된 국가 설정
  void setSelectedCountry(String countryName, String countryCode) {
    selectedCountry.value = countryName;
    selectedCountryCode.value = countryCode;
    countryController.text = countryName;
  }

  // 생년월일 설정
  void setBirthDate(DateTime date) {
    selectedBirthDate.value = date;
    birthDateController.text = DateFormat('yyyy-MM-dd').format(date);
  }

  // 갤러리에서 이미지 선택
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      await cropImage(image.path);
    }
  }

  // 카메라로 이미지 촬영
  Future<void> takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      await cropImage(image.path);
    }
  }

  // 이미지 크롭
  Future<void> cropImage(String filePath) async {
    try {
      final cropper = ImageCropper();
      final croppedFile = await cropper.cropImage(
        sourcePath: filePath,
        compressQuality: 50, // 품질 50% 미만으로 설정 (45%)
        compressFormat: ImageCompressFormat.jpg, // JPG 형식으로 압축
        maxHeight: 300, // 최대 높이 100px
        maxWidth: 300, // 최대 너비 100px
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '프로필 이미지 편집',
            toolbarColor: Get.theme.primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square], // 정사각형으로 제한
          ),
          IOSUiSettings(
            title: '프로필 이미지 편집',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square], // 정사각형으로 제한
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile != null) {
        profileImage.value = File(croppedFile.path);
        isImageSelected.value = true;
        debugPrint('✅ 이미지 크롭 성공: ${croppedFile.path} (100x100, 품질: 45%)');
      } else {
        debugPrint('⚠️ 이미지 크롭이 취소되었습니다.');
      }
    } catch (e) {
      debugPrint('❌ 이미지 크롭 오류: $e');
      errorMessage.value = '이미지 편집 중 오류가 발생했습니다.';
    }
  }

  // 프로필 업데이트
  Future<void> updateProfile() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    isSuccess.value = false;

    try {
      // 수정된 사용자 정보 생성
      final updatedUser = UserModel(
        uid: user.value.uid,
        email: user.value.email,
        nickname: nicknameController.text.trim(),
        birthDate: selectedBirthDate.value ?? user.value.birthDate,
        country: selectedCountry.value.isNotEmpty
            ? selectedCountry.value
            : countryController.text.trim(),
        countryCode: selectedCountryCode.value,
        userType: user.value.userType,
        profileImageUrl: user.value.profileImageUrl,
        lastActive: DateTime.now(),
      );

      // 이미지가 선택된 경우 업로드
      if (isImageSelected.value && profileImage.value != null) {
        final imageBytes = await profileImage.value!.readAsBytes();
        final imageUrl = await _authService.uploadProfileImage(
          updatedUser.uid!,
          Uint8List.fromList(imageBytes),
        );

        if (imageUrl != null) {
          updatedUser.profileImageUrl = imageUrl;
        }
      }

      // 사용자 정보 업데이트
      final success = await _authService.updateUserData(updatedUser);

      if (success) {
        isSuccess.value = true;
        Get.snackbar(
          '성공',
          '프로필이 성공적으로 업데이트되었습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          duration: const Duration(seconds: 3),
        );
      } else {
        errorMessage.value = _authService.error ?? '프로필 업데이트에 실패했습니다.';
      }
    } catch (e) {
      errorMessage.value = '오류가 발생했습니다: $e';
    } finally {
      isLoading.value = false;
    }
  }
}

class ProfileEditView extends GetView<ProfileEditController> {
  const ProfileEditView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 프로필 이미지
                  _buildProfileImageWidget(theme),

                  const SizedBox(height: 32),

                  // 프로필 정보 폼
                  _buildProfileForm(),

                  const SizedBox(height: 16),

                  // 에러 메시지
                  if (controller.errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        controller.errorMessage.value,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        controller.updateProfile();
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '저장하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProfileImageWidget(ThemeData theme) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              // 프로필 이미지
              Obx(() {
                Widget image;

                if (controller.isImageSelected.value &&
                    controller.profileImage.value != null) {
                  // 로컬에서 선택한 이미지
                  image = CircleAvatar(
                    radius: 64,
                    backgroundImage: FileImage(controller.profileImage.value!),
                  );
                } else if (controller.user.value.profileImageUrl != null &&
                    controller.user.value.profileImageUrl!.isNotEmpty) {
                  // Firebase에서 가져온 이미지
                  image = CircleAvatar(
                    radius: 64,
                    backgroundImage:
                        NetworkImage(controller.user.value.profileImageUrl!),
                  );
                } else {
                  // 기본 이미지
                  image = CircleAvatar(
                    radius: 64,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                    child: Icon(
                      Icons.person_rounded,
                      size: 64,
                      color: theme.colorScheme.onPrimary,
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 4,
                    ),
                  ),
                  child: image,
                );
              }),

              // 이미지 선택 버튼
              Container(
                margin: const EdgeInsets.only(bottom: 6, right: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _showImageSourceDialog,
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showImageSourceDialog,
          icon: Icon(
            Icons.add_photo_alternate_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            '프로필 사진 변경',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Builder(
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이메일 (읽기 전용)
            _buildFormLabel('이메일'),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: controller.user.value.email,
              readOnly: true,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              decoration: _buildInputDecoration(
                hintText: '이메일',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),

            const SizedBox(height: 20),

            // 닉네임
            _buildFormLabel('닉네임'),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller.nicknameController,
              decoration: _buildInputDecoration(
                hintText: '닉네임을 입력하세요',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '닉네임을 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // 국가
            _buildFormLabel('국가'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showCountrySelectionBottomSheet(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public_rounded, size: 22),
                    const SizedBox(width: 12),
                    Obx(() {
                      final countryCode = controller.selectedCountryCode.value;
                      if (countryCode.isNotEmpty) {
                        return Text(
                          controller.getCountryFlag(countryCode),
                          style: const TextStyle(fontSize: 22),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Obx(() {
                        return Text(
                          controller.selectedCountry.value.isNotEmpty
                              ? controller.selectedCountry.value
                              : controller.countryController.text.isNotEmpty
                                  ? controller.countryController.text
                                  : '국가를 선택하세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: controller
                                        .selectedCountry.value.isNotEmpty ||
                                    controller.countryController.text.isNotEmpty
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 생년월일
            _buildFormLabel('생년월일'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showDatePicker(context),
              borderRadius: BorderRadius.circular(12),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: controller.birthDateController,
                  decoration: _buildInputDecoration(
                    hintText: '생년월일을 선택하세요',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool filled = false,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _showImageSourceDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '프로필 사진 선택',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.photo_library_rounded, color: Colors.blue),
              ),
              title: const Text('갤러리에서 선택'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                Get.back();
                controller.pickImage();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.camera_alt_rounded, color: Colors.green),
              ),
              title: const Text('카메라로 촬영'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                Get.back();
                controller.takePhoto();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('취소'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showCountrySelectionBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final scrollController = ScrollController();
    final textController = TextEditingController();
    final countries = controller.getCountries();
    final RxList<Map<String, dynamic>> filteredCountries =
        RxList<Map<String, dynamic>>(countries);

    // 자주 사용하는 국가 (상위 5개)
    final frequentCountries = countries.take(5).toList();

    void onSearchChanged(String value) {
      if (value.isEmpty) {
        filteredCountries.value = countries;
      } else {
        filteredCountries.value = countries
            .where((country) => country['name']
                .toString()
                .toLowerCase()
                .contains(value.toLowerCase()))
            .toList();
      }
    }

    Get.bottomSheet(
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 바텀시트 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 제목과 검색창
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '국가 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: TextField(
                      controller: textController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '국가 검색...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 국가 목록
            Expanded(
              child: Obx(() {
                if (filteredCountries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (textController.text.isEmpty) {
                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      // 자주 사용하는 국가 섹션
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '자주 사용하는 국가',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final country = frequentCountries[index];
                            return _buildCountryListTile(country, theme);
                          },
                          childCount: frequentCountries.length,
                        ),
                      ),
                      // 구분선
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  '모든 국가',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 전체 국가 목록
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final country = filteredCountries[index];
                            // 자주 사용하는 국가는 이미 상단에 표시했으므로 제외
                            if (frequentCountries
                                .any((c) => c['code'] == country['code'])) {
                              return const SizedBox.shrink();
                            }
                            return _buildCountryListTile(country, theme);
                          },
                          childCount: filteredCountries.length,
                        ),
                      ),
                    ],
                  );
                } else {
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return _buildCountryListTile(country, theme);
                    },
                  );
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryListTile(Map<String, dynamic> country, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Text(
            controller.getCountryFlag(country['code']),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          country['name'],
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          country['code'],
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        onTap: () {
          controller.setSelectedCountry(country['name'], country['code']);
          Get.back();
        },
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 100, 1, 1); // 100년 전
    final DateTime lastDate = DateTime(now.year - 18, 12, 31); // 최소 18세 이상
    final DateTime initialDate = controller.selectedBirthDate.value ??
        controller.user.value.birthDate ??
        DateTime(now.year - 20, now.month, now.day); // 기본값 20년 전

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '확인',
      fieldLabelText: '생년월일 입력',
      fieldHintText: 'YYYY-MM-DD',
      errorFormatText: '올바른 형식이 아닙니다',
      errorInvalidText: '유효한 날짜를 선택해주세요',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 16,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.setBirthDate(picked);
    }
  }
}
