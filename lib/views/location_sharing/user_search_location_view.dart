import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/location_sharing_service.dart';
import '../../models/user_model.dart';

class UserSearchLocationView extends StatefulWidget {
  const UserSearchLocationView({Key? key}) : super(key: key);

  @override
  State<UserSearchLocationView> createState() => _UserSearchLocationViewState();
}

class _UserSearchLocationViewState extends State<UserSearchLocationView> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 검색어로 사용자 검색
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUserUid = _auth.currentUser?.uid;
      if (currentUserUid == null) {
        setState(() {
          _errorMessage = '로그인 상태를 확인할 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      // 이메일로 검색
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // 닉네임으로 검색
      final nicknameQuery = await _firestore
          .collection('users')
          .where('nickname', isGreaterThanOrEqualTo: query)
          .where('nickname', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // 결과 합치기 (중복 제거)
      final Map<String, UserModel> userMap = {};

      // 이메일 검색 결과 추가
      for (var doc in emailQuery.docs) {
        if (doc.id != currentUserUid) {
          // 자기 자신 제외
          userMap[doc.id] = UserModel.fromFirestore(doc);
        }
      }

      // 닉네임 검색 결과 추가
      for (var doc in nicknameQuery.docs) {
        if (doc.id != currentUserUid) {
          // 자기 자신 제외
          userMap[doc.id] = UserModel.fromFirestore(doc);
        }
      }

      setState(() {
        _searchResults = userMap.values.toList();
        _isLoading = false;

        if (_searchResults.isEmpty) {
          _errorMessage = '검색 결과가 없습니다.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = '검색 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
      print('사용자 검색 오류: $e');
    }
  }

  // 위치 공유 시작
  Future<void> _startLocationSharing(UserModel user) async {
    try {
      final result =
          await _locationService.startLocationSharingWithUser(user.uid);
      if (result) {
        Get.back(); // 검색 화면 닫기
        Get.snackbar(
          '위치 공유 시작',
          '${user.nickname ?? user.email}님과 실시간 위치 공유가 시작되었습니다',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          '위치 공유 실패',
          '위치 공유를 시작할 수 없습니다. 다시 시도해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      print('위치 공유 시작 오류: $e');
      Get.snackbar(
        '위치 공유 오류',
        '위치 공유 중 오류가 발생했습니다. 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 검색'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이메일 또는 닉네임으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _errorMessage = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onSubmitted: _searchUsers,
              textInputAction: TextInputAction.search,
            ),
          ),

          // 검색 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _searchUsers(_searchController.text),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('검색'),
              ),
            ),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // 오류 메시지
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          // 검색 결과 목록
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 사용자 카드 위젯
  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(user.nickname ?? '사용자'),
        subtitle: Text(user.email ?? ''),
        trailing: ElevatedButton(
          onPressed: () => _startLocationSharing(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: const Text(
            '위치 공유',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
