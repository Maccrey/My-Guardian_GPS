import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  // TextEditingController
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

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
        birthDate: user.value.birthDate,
        country: countryController.text.trim(),
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
        TextFormField(
          controller: controller.countryController,
          decoration: InputDecoration(
            hintText: '국가를 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 생년월일 (읽기 전용)
        const Text(
          '생년월일',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: controller.user.value.birthDate != null
              ? DateFormat('yyyy-MM-dd')
                  .format(controller.user.value.birthDate!)
              : '',
          readOnly: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
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
}
