import 'package:drisk/models/dream_model.dart';
import 'package:drisk/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(DreamAdapter());
  Hive.registerAdapter(DreamMoodAdapter());
  Hive.registerAdapter(DreamTypeAdapter());

  await Hive.openBox<Dream>('dreams');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark();

    return MaterialApp(
      title: 'Dream Journal',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
          primaryColor: Colors.deepPurple[300],
          scaffoldBackgroundColor: Colors.black,
          // Apply the custom font to the entire app
          textTheme: GoogleFonts.josefinSansTextTheme(baseTheme.textTheme),
          colorScheme: ColorScheme.dark(
            primary: Colors.deepPurple[300]!,
            secondary: Colors.tealAccent[400]!,
            surface: Colors.grey[900]!,
            background: Colors.black,
          ),
          // We will apply styling directly with our widget, so the theme can be simpler.
          cardTheme: CardTheme(
            color: Colors.transparent, // Make cards transparent for our effect
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          )),
      home: const MainScreen(),
    );
  }
}
