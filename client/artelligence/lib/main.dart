import 'package:flutter/material.dart' hide ImageProvider;
import 'package:provider/provider.dart';
import 'config/theme_config.dart';
import 'providers/image_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ArtelligenceApp());
}

class ArtelligenceApp extends StatelessWidget {
  const ArtelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ImageProvider())],
      child: MaterialApp(
        title: 'Artelligence',
        debugShowCheckedModeBanner: false,
        theme: ThemeConfig.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
