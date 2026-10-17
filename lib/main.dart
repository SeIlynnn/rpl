import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: 'https://qqgidnsnnmbvnsvpoifb.supabase.co',
      // ignore: deprecated_member_use
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxZ2lkbnNubm1idm5zdnBvaWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyMTM5NzYsImV4cCI6MjEwNzc4OTk3Nn0.ZfEcDxBm27w-QhoWLorF8zlnS9hqArq5QQf66DN3XCA',
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

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
