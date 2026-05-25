import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vrgccbnlxvmhmruphgfe.supabase.co',
    anonKey:
    'sb_publishable_07JQnhrIHM3HN0X20Yk9iQ_8aWTiCk2', // replace with your real anon key
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rental App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}