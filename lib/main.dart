import 'package:analytica_ai/screens/admin_panel_screen.dart';
import 'package:analytica_ai/screens/manage_documents.dart';
import 'package:analytica_ai/screens/manage_llm_provider.dart';
import 'package:analytica_ai/screens/manage_sql_database.dart';
import 'package:analytica_ai/screens/manage_users_screen.dart';
import 'package:analytica_ai/screens/manage_webpages.dart';
import 'package:analytica_ai/utils/colors.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth Demo',
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: Colors.white, // Light background for modern sleek UI
        colorScheme: ColorScheme.light(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
          titleLarge: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white, // Use white for app bar for a light look
          foregroundColor: kPrimaryColor, // Accent the text and icons with purple
          elevation: 0,
          iconTheme: IconThemeData(color: kPrimaryColor),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeScreen(),
        '/admin': (context) => AdminPanelScreen(),
        '/manage_users': (context) => ManageUsersScreen(),
        '/manage_sql': (context) => ManageSqlScreen(),
        '/manage_llm': (context) => ManageLLMProviderScreen(),
        '/manage_documents': (context) => ManageDocumentsScreen(),
        '/manage_webpages': (context) => ManageWebpagesScreen(),
      },
    );
  }
}
