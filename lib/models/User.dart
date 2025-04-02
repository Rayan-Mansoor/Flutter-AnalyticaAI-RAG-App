class User {
  final String userName;
  final String orgName;
  final String role;

  User({required this.userName, required this.orgName, required this.role});

  @override
  String toString() {
    return 'User(username: $userName, orgName: $orgName, role: $role)';
  }
}