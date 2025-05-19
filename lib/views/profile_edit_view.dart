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
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '프로필 이미지 편집',
            toolbarColor: Get.theme.primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '프로필 이미지 편집',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        profileImage.value = File(croppedFile.path);
        isImageSelected.value = true;
        debugPrint('✅ 이미지 크롭 성공: ${croppedFile.path}');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 프로필 이미지
                  _buildProfileImageWidget(),

                  const SizedBox(height: 24),

                  // 프로필 정보 폼
                  _buildProfileForm(),

                  const SizedBox(height: 16),

                  // 에러 메시지
                  if (controller.errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        controller.errorMessage.value,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '저장하기',
                        style: TextStyle(fontSize: 16),
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

  Widget _buildProfileImageWidget() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // 프로필 이미지
            Obx(() {
              if (controller.isImageSelected.value &&
                  controller.profileImage.value != null) {
                // 로컬에서 선택한 이미지
                return CircleAvatar(
                  radius: 60,
                  backgroundImage: FileImage(controller.profileImage.value!),
                );
              } else if (controller.user.value.profileImageUrl != null &&
                  controller.user.value.profileImageUrl!.isNotEmpty) {
                // Firebase에서 가져온 이미지
                return CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      NetworkImage(controller.user.value.profileImageUrl!),
                );
              } else {
                // 기본 이미지
                return const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                );
              }
            }),

            // 이미지 선택 버튼
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: InkWell(
                onTap: _showImageSourceDialog,
                child: const Icon(
                  Icons.camera_alt,
                  size: 24,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '프로필 사진 변경',
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Builder(
      builder: (BuildContext context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이메일 (읽기 전용)
            const Text(
              '이메일',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: controller.user.value.email,
              readOnly: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),

            const SizedBox(height: 16),

            // 닉네임
            const Text(
              '닉네임',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller.nicknameController,
              decoration: InputDecoration(
                hintText: '닉네임을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '닉네임을 입력해주세요';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 국가
            const Text(
              '국가',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showCountrySelectionBottomSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Obx(() {
                      final countryCode = controller.selectedCountryCode.value;
                      return Text(
                        countryCode.isNotEmpty
                            ? controller.getCountryFlag(countryCode)
                            : '🏳️',
                        style: const TextStyle(fontSize: 24),
                      );
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
                                ? Colors.black
                                : Colors.grey.shade600,
                          ),
                        );
                      }),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 생년월일
            const Text(
              '생년월일',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showDatePicker(context),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: controller.birthDateController,
                  decoration: InputDecoration(
                    hintText: '생년월일을 선택하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImageSourceDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('프로필 사진 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Get.back();
                controller.pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
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
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showCountrySelectionBottomSheet(BuildContext context) {
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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '국가 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: textController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '국가 검색...',
                        prefixIcon: const Icon(Icons.search),
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
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (filteredCountries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
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
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            '자주 사용하는 국가',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final country = frequentCountries[index];
                            return _buildCountryListTile(country);
                          },
                          childCount: frequentCountries.length,
                        ),
                      ),
                      // 구분선
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              const Divider(),
                              Text(
                                '모든 국가',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
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
                            return _buildCountryListTile(country);
                          },
                          childCount: filteredCountries.length,
                        ),
                      ),
                    ],
                  );
                } else {
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return _buildCountryListTile(country);
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

  Widget _buildCountryListTile(Map<String, dynamic> country) {
    return ListTile(
      leading: Text(
        controller.getCountryFlag(country['code']),
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(country['name']),
      onTap: () {
        controller.setSelectedCountry(country['name'], country['code']);
        Get.back();
      },
    );
  }

  void _showDatePicker(BuildContext context) async {
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
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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
