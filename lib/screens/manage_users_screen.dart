import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:math';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({Key? key}) : super(key: key);

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'member';
  bool _isCreating = false;
  List<dynamic>? _users;

  // Helper method to generate a simple random password.
  String generateRandomPassword({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    Random random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Fetch users from the API.
  Future<void> _loadUsers() async {
    final users = await AuthService.getUsers();
    setState(() {
      _users = users;
    });
  }

  // Handle creating a new user.
  Future<void> _createUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true;
      });
      // Generate a random password.
      String generatedPassword = generateRandomPassword();
      final result = await AuthService.createUser(
        _nameController.text,
        _emailController.text,
        generatedPassword,
        _selectedRole,
      );
      setState(() {
        _isCreating = false;
      });
      if (result != null && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User created successfully. Generated password: $generatedPassword')),
        );
        // Clear form fields.
        _nameController.clear();
        _emailController.clear();
        // Reload the users list.
        await _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // List of existing users.
            const Text(
              'Existing Users',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _users == null
                ? const CircularProgressIndicator()
                : _users!.isEmpty
                    ? const Text('No users found.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users!.length,
                        itemBuilder: (context, index) {
                          final user = _users![index];
                          return Card(
                            child: ListTile(
                              title: Text(user['user_name'] ?? ''),
                              subtitle: Text(user['email'] ?? ''),
                              trailing: Text(user['role'] ?? ''),
                            ),
                          );
                        },
                      ),
            const Divider(height: 40),
            // Form to create a new user.
            const Text(
              'Create New User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // User Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'User Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the user name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        child: Text('Member'),
                        value: 'member',
                      ),
                      DropdownMenuItem(
                        child: Text('Manager'),
                        value: 'manager',
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _isCreating
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _createUser,
                          child: const Text('Create User'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
