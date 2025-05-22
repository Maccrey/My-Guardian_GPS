import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';
import '../services/auth_service.dart';

class UserSearchContactView extends StatefulWidget {
  const UserSearchContactView({Key? key}) : super(key: key);

  @override
  State<UserSearchContactView> createState() => _UserSearchContactViewState();
}

class _UserSearchContactViewState extends State<UserSearchContactView> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = Get.find<AuthService>();
  final EmergencyContactService _contactService =
      Get.find<EmergencyContactService>();

  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 사용자 검색 함수
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 이름, 이메일 또는 전화번호로 검색
      final nameQuery = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .get();

      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: query + 'z')
          .get();

      final phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isGreaterThanOrEqualTo: query)
          .where('phoneNumber', isLessThan: query + 'z')
          .get();

      // 결과 병합 및 중복 제거
      final results = <UserModel>{};

      for (var doc in nameQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid != _authService.currentUser?.uid) {
          results.add(user);
        }
      }

      for (var doc in emailQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid != _authService.currentUser?.uid) {
          results.add(user);
        }
      }

      for (var doc in phoneQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid != _authService.currentUser?.uid) {
          results.add(user);
        }
      }

      setState(() {
        _searchResults = results.toList();
        _isSearching = false;
      });
    } catch (e) {
      print('사용자 검색 오류: $e');
      setState(() {
        _isSearching = false;
      });
      Get.snackbar(
        '검색 오류',
        '사용자 검색 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  // 긴급 연락처로 추가
  Future<void> _addAsEmergencyContact(UserModel user) async {
    try {
      // 앱 사용자를 긴급 연락처로 변환
      final contact = EmergencyContact.fromAppUser(
        userId: user.uid,
        name: user.displayName ?? '이름 없음',
        email: user.email,
        phoneNumber: user.phoneNumber ?? '',
        relationship: '앱 사용자',
      );

      // 서비스를 통해 연락처 추가
      await _contactService.addContact(contact);

      Get.back(); // 화면 닫기
      Get.snackbar(
        '연락처 추가됨',
        '${user.displayName ?? '이름 없음'}님이 긴급 연락처로 추가되었습니다.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      print('긴급 연락처 추가 오류: $e');
      Get.snackbar(
        '추가 오류',
        '긴급 연락처 추가 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 사용자 검색'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이름, 이메일 또는 전화번호로 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  _searchUsers(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),

          // 검색 상태 표시
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // 검색 안내 메시지
          if (!_isSearching &&
              _searchResults.isEmpty &&
              _searchController.text.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '이름, 이메일 또는 전화번호로\n앱 사용자를 검색하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 검색 결과 없음
          if (!_isSearching &&
              _searchResults.isEmpty &&
              _searchController.text.isNotEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '검색 결과가 없습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '다른 검색어로 다시 시도해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 검색 결과 목록
          if (!_isSearching && _searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.displayName?.substring(0, 1) ?? '?'),
                    ),
                    title: Text(user.displayName ?? '이름 없음'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.email != null && user.email!.isNotEmpty)
                          Text(user.email!),
                        if (user.phoneNumber != null &&
                            user.phoneNumber!.isNotEmpty)
                          Text(user.phoneNumber!),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _addAsEmergencyContact(user),
                      child: const Text('추가'),
                    ),
                    isThreeLine: user.email != null && user.phoneNumber != null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
