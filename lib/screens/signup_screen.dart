import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for all fields
  final orgNameController = TextEditingController();
  final adminNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Focus nodes for sequential focus management
  final orgNameFocusNode = FocusNode();
  final adminNameFocusNode = FocusNode();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  bool isLoading = false;
  bool _obscurePassword = true;

  // Regular expression for email validation
  final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });
      // Pass organization name, admin name, email, and password to signup
      final response = await AuthService.signup(
        orgNameController.text,
        adminNameController.text,
        emailController.text,
        passwordController.text,
      );
      setState(() {
        isLoading = false;
      });
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup successful. Please login.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Signup failed')));
      }
    }
  }

  @override
  void dispose() {
    orgNameController.dispose();
    adminNameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    orgNameFocusNode.dispose();
    adminNameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Organization Name
              TextFormField(
                controller: orgNameController,
                focusNode: orgNameFocusNode,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Organization Name'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter organization name'
                    : null,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(adminNameFocusNode);
                },
              ),
              // Admin Name
              TextFormField(
                controller: adminNameController,
                focusNode: adminNameFocusNode,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Admin Name'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter admin name'
                    : null,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(emailFocusNode);
                },
              ),
              // Email Field
              TextFormField(
                controller: emailController,
                focusNode: emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(passwordFocusNode);
                },
              ),
              // Password Field with visibility toggle and done action
              TextFormField(
                controller: passwordController,
                focusNode: passwordFocusNode,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter password'
                    : null,
                onFieldSubmitted: (_) {
                  _signup();
                },
              ),
              SizedBox(height: 20),
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(onPressed: _signup, child: Text("Sign Up")),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: Text("Already have an account? Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
