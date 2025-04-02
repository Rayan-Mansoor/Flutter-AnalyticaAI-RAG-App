import 'package:analytica_ai/screens/admin_panel_screen.dart';
import 'package:analytica_ai/screens/manage_documents.dart';
import 'package:analytica_ai/screens/manage_llm_provider.dart';
import 'package:analytica_ai/screens/manage_sql_database.dart';
import 'package:analytica_ai/screens/manage_users_screen.dart';
import 'package:analytica_ai/screens/manage_webpages.dart';
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
      theme: ThemeData(primarySwatch: Colors.blue),
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
