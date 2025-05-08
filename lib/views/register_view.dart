import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../view_models/register_view_model.dart';
import '../services/auth_service.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    // GetX 컨트롤러 초기화
    final controller = Get.put(RegisterViewModel(Get.find<AuthService>()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '계정 정보를 입력해주세요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 사용자 유형 선택 스위치
                    Obx(() => Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: controller.isGuardianMode.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: controller.isGuardianMode.value ? 2 : 1,
                            ),
                            color: controller.isGuardianMode.value
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.05)
                                : Colors.transparent,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 아이콘
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: controller.isGuardianMode.value
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1)
                                      : Colors.grey.shade100,
                                ),
                                child: Icon(
                                  controller.isGuardianMode.value
                                      ? Icons.shield_outlined
                                      : Icons.person_outline,
                                  color: controller.isGuardianMode.value
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade700,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // 텍스트 (Expanded로 감싸서 남은 공간을 차지하도록 함)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.getUserTypeText(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: controller.isGuardianMode.value
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      controller.isGuardianMode.value
                                          ? '다른 사용자를 관리할 수 있습니다'
                                          : '일반 사용자로 이용합니다',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),

                              // 스위치 (공간을 확보하기 위해 왼쪽 여백 추가)
                              const SizedBox(width: 8),
                              Switch(
                                value: controller.isGuardianMode.value,
                                onChanged: (value) {
                                  controller.toggleUserType();
                                },
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),

                    // 닉네임 필드
                    TextFormField(
                      controller: controller.nicknameController,
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        hintText: '사용하실 닉네임을 입력하세요',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 국가 선택 필드
                    Obx(() => InkWell(
                          onTap: () => _selectCountry(context, controller),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 15, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    controller.selectedCountry.value.isNotEmpty
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                width:
                                    controller.selectedCountry.value.isNotEmpty
                                        ? 2
                                        : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                controller.selectedCountryCode.value.isNotEmpty
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: Text(
                                          controller.getCountryFlag(controller
                                              .selectedCountryCode.value),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      )
                                    : const Icon(Icons.public,
                                        color: Colors.grey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    controller.selectedCountry.value.isNotEmpty
                                        ? controller.selectedCountry.value
                                        : '국가를 선택해주세요',
                                    style: TextStyle(
                                      color: controller
                                              .selectedCountry.value.isNotEmpty
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down,
                                    color: Colors.grey),
                              ],
                            ),
                          ),
                        )),
                    Obx(() {
                      if (controller.error != null &&
                          controller.selectedCountry.value.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            '국가를 선택해주세요',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                    const SizedBox(height: 16),

                    // 생년월일 필드
                    TextFormField(
                      controller: controller.birthDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: '생년월일',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                      onTap: () => _selectDate(context, controller),
                    ),
                    const SizedBox(height: 16),

                    // 이메일 필드
                    TextFormField(
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        hintText: 'your.email@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 필드
                    Obx(() => TextFormField(
                          controller: controller.passwordController,
                          obscureText: !controller.isPasswordVisible.value,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            hintText: '비밀번호를 입력하세요',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isPasswordVisible.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  controller.togglePasswordVisibility(),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),

                    // 비밀번호 확인 필드
                    Obx(() => TextFormField(
                          controller: controller.confirmPasswordController,
                          obscureText:
                              !controller.isConfirmPasswordVisible.value,
                          decoration: InputDecoration(
                            labelText: '비밀번호 확인',
                            hintText: '비밀번호를 다시 입력하세요',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.isConfirmPasswordVisible.value
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  controller.toggleConfirmPasswordVisibility(),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 32),

                    // 회원가입 버튼
                    Obx(() => ElevatedButton(
                          onPressed: controller.isLoading
                              ? null
                              : () async {
                                  if (await controller.register()) {
                                    Get.snackbar(
                                      '성공',
                                      '회원가입이 완료되었습니다!',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    Future.delayed(const Duration(seconds: 1),
                                        () {
                                      Get.back();
                                    });
                                  } else if (controller.error != null) {
                                    Get.snackbar(
                                      '오류',
                                      controller.error!,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '회원가입',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        )),

                    // 개인정보 이용 약관
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '회원가입 시 이용약관 및 개인정보취급방침에 동의하게 됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (controller.isLoading) {
                return Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
      BuildContext context, RegisterViewModel controller) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = DateTime(now.year - 20, now.month, now.day);
    final DateTime firstDate = DateTime(now.year - 100);
    final DateTime lastDate = DateTime(now.year - 12, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.birthDateController.text =
          DateFormat('yyyy-MM-dd').format(picked);
      controller.setSelectedDate(picked);
    }
  }

  Future<void> _selectCountry(
      BuildContext context, RegisterViewModel controller) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                String searchQuery = '';
                List<Map<String, dynamic>> frequentCountries =
                    controller.getFrequentlyUsedCountries();
                List<Map<String, dynamic>> filteredCountries =
                    searchQuery.isEmpty
                        ? controller.getSortedCountries()
                        : controller.searchCountries(searchQuery);

                void onSearchChanged(String query) {
                  setState(() {
                    searchQuery = query;
                    filteredCountries = query.isEmpty
                        ? controller.getSortedCountries()
                        : controller.searchCountries(query);
                  });
                }

                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: TextField(
                                onChanged: onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: '국가 검색...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                      if (filteredCountries.isNotEmpty)
                        Expanded(
                          child: searchQuery.isEmpty
                              ? CustomScrollView(
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
                                          final country =
                                              frequentCountries[index];
                                          return _buildCountryListTile(
                                              context, country, controller);
                                        },
                                        childCount: frequentCountries.length,
                                      ),
                                    ),
                                    // 구분선
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
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
                                          final country =
                                              filteredCountries[index];
                                          // 자주 사용하는 국가는 이미 상단에 표시했으므로 제외
                                          if (frequentCountries.any((c) =>
                                              c['code'] == country['code'])) {
                                            return const SizedBox.shrink();
                                          }
                                          return _buildCountryListTile(
                                              context, country, controller);
                                        },
                                        childCount: filteredCountries.length,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredCountries.length,
                                  itemBuilder: (context, index) {
                                    final country = filteredCountries[index];
                                    return _buildCountryListTile(
                                        context, country, controller);
                                  },
                                ),
                        ),
                      if (searchQuery.isNotEmpty && filteredCountries.isEmpty)
                        Expanded(
                          child: Center(
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
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCountryListTile(BuildContext context,
      Map<String, dynamic> country, RegisterViewModel controller) {
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
}
