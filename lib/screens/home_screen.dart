import 'package:flutter/material.dart';
import 'dart:ui';
import 'radar_screen.dart';
import 'chat_screen.dart';
import 'walkie_talkie_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RadarScreen(),
    const ChatScreen(),
    const WalkieTalkieScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    Color(0xFF1A2A2A),
                    Color(0xFF0D0D12),
                  ],
                ),
              ),
            ),
          ),
          
          // Current Screen
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _screens[_currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.white54,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.radar),
                  label: 'Radar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Mesh Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.mic_none),
                  activeIcon: Icon(Icons.mic),
                  label: 'Walkie',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
