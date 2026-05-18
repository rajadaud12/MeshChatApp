import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/mesh_network_service.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MeshNetworkService()),
      ],
      child: const MeshChatApp(),
    ),
  );
}

class MeshChatApp extends StatelessWidget {
  const MeshChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        primaryColor: const Color(0xFF00FF88),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF00B8FF),
          surface: Color(0xFF1A1A24),
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
