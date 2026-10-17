import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/ui/main_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: CompanionApp(),
    ),
  );
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLSDB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, 
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
