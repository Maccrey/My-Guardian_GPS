import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../location_sharing/location_sharing_widget.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 위치 공유 상태 표시 위젯
            LocationSharingStatusWidget(),

            // 기존 내용
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  // 기존 위젯들
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // 기존 bottomNavigationBar 속성
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: '메시지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          // 기존 탭 처리 로직
        },
      ),
    );
  }
}
