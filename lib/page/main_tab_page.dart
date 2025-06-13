import 'package:firmware_client/page/decrypter_page.dart';
import 'package:flutter/material.dart';
import 'package:firmware_client/page/check_page.dart'; // 导入 MyHomePage

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;

  final List<Widget> _pageList = [
    const MyHomePage(title: '查询/下载'),
    const DecrypterPage(),
  ];

  final List<BottomNavigationBarItem> _bottomNavigationBarItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.download),
      label: 'Download', // 第一个tab的名称为 Download
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.lock_open),
      label: 'Decrypter', // 第二个tab的名称为 Decrypter
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pageList),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _bottomNavigationBarItems,
        type: BottomNavigationBarType.fixed, // 确保tab数量多时也能显示label
      ),
    );
  }
}
