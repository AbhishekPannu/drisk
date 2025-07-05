import 'package:drisk/models/dream_model.dart';
import 'package:drisk/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register our custom objects (Adapters)
  Hive.registerAdapter(DreamAdapter());
  Hive.registerAdapter(DreamMoodAdapter());
  Hive.registerAdapter(DreamTypeAdapter());

  // Open the box (our database file)
  await Hive.openBox<Dream>('dreams');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dream Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple[300],
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple[300]!,
          secondary: Colors.tealAccent[400]!,
          surface: Colors.grey[900]!,
        ),
        cardTheme: CardTheme(
          color: Colors.black.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
