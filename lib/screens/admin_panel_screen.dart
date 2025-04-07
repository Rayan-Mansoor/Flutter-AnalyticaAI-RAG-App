import 'package:analytica_ai/screens/manage_documents.dart';
import 'package:analytica_ai/screens/manage_llm_provider.dart';
import 'package:analytica_ai/screens/manage_sql_database.dart';
import 'package:analytica_ai/screens/manage_users_screen.dart';
import 'package:analytica_ai/screens/manage_webpages.dart';
import 'package:analytica_ai/utils/colors.dart';
import 'package:flutter/material.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: kPrimaryColor),
        titleTextStyle: TextStyle(
          color: kPrimaryColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Two columns layout.
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          children: [
            AdminOptionCard(
              icon: Icons.group,
              title: 'Manage Users',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
                );
              },
            ),
            AdminOptionCard(
              icon: Icons.storage,
              title: 'Manage LLM Provider',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageLLMProviderScreen()),
                );
              },
            ),
            AdminOptionCard(
              icon: Icons.storage,
              title: 'Manage SQL DB',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageSqlScreen()),
                );
              },
            ),
            AdminOptionCard(
              icon: Icons.picture_as_pdf,
              title: 'Manage Documents',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageDocumentsScreen()),
                );
              },
            ),
            AdminOptionCard(
              icon: Icons.cloud_upload_rounded,
              title: 'Manage Webpages',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageWebpagesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AdminOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const AdminOptionCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular container for the icon with a subtle background accent
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      kPrimaryColor.withOpacity(0.1),
                      kSecondaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Icon(
                  icon,
                  size: 32,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
