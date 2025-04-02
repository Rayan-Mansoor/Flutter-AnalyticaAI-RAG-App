import 'package:analytica_ai/services/auth_service.dart';
import 'package:flutter/material.dart';

enum DatabaseType { supabase, postgresql, mysql, sqlserver }
enum AccessLevel { admin, manager, member }

class TableDetail {
  final int id;
  final String tableName;
  AccessLevel accessLevel;

  TableDetail({
    required this.id,
    required this.tableName,
    required this.accessLevel,
  });

  factory TableDetail.fromJson(Map<String, dynamic> json) {
    return TableDetail(
      id: json['id'],
      tableName: json['table_name'],
      accessLevel: _accessLevelFromString(json['access_level']),
    );
  }

  static AccessLevel _accessLevelFromString(String level) {
    switch (level) {
      case 'admin':
        return AccessLevel.admin;
      case 'manager':
        return AccessLevel.manager;
      case 'member':
      default:
        return AccessLevel.member;
    }
  }
}

class ManageSqlScreen extends StatefulWidget {
  const ManageSqlScreen({Key? key}) : super(key: key);

  @override
  _ManageSqlScreenState createState() => _ManageSqlScreenState();
}

class _ManageSqlScreenState extends State<ManageSqlScreen> {
  List<TableDetail> _tables = [];
  DatabaseType? _selectedDbType;
  final _formKey = GlobalKey<FormState>();

  // Controllers for non-Supabase form fields
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _dbnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _driverController = TextEditingController();

  // Controllers for Supabase fields
  final _supabaseUrlController = TextEditingController();
  final _supabaseKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTableDetails();
  }

  Future<void> _fetchTableDetails() async {
    try {
      final data = await AuthService.getTablesAccessLevels() ?? [];
      // Assuming data is a list of JSON objects
      setState(() {
        _tables = data.map<TableDetail>((json) => TableDetail.fromJson(json)).toList();
      });
    } catch (e) {
      // Handle errors, e.g., show a snackbar or log the error
      print("Error fetching table details: $e");
    }
  }

  Future<void> _updateTableAccess(String tableName, AccessLevel newAccess) async {
    try {
      // Call the Auth Service to update the table access level
      await AuthService.updateTableAccessLevel(tableName, newAccess.name);
    } catch (e) {
      // Handle errors accordingly
      print("Error updating table access level: $e");
    }
  }

  Future<void> _submitDatabaseForm() async {
    if (_formKey.currentState?.validate() != true || _selectedDbType == null) return;

    final Map<String, dynamic> payload = {
      'database_type': _selectedDbType.toString().split('.').last,
    };

    if (_selectedDbType == DatabaseType.supabase) {
      payload['supabase_url'] = _supabaseUrlController.text;
      payload['supabase_key'] = _supabaseKeyController.text;
    } else {
      payload['host'] = _hostController.text;
      payload['port'] = int.tryParse(_portController.text);
      payload['dbname'] = _dbnameController.text;
      payload['username'] = _usernameController.text;
      payload['password'] = _passwordController.text;
      if (_selectedDbType == DatabaseType.sqlserver) {
        payload['driver'] = _driverController.text;
      }
    }

    try {
      // Call the Auth Service to set SQL database credentials
      await AuthService.setSqlDatabase(payload);
    } catch (e) {
      // Handle errors accordingly
      print("Error setting SQL database: $e");
    }
  }

  Widget _buildTableList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _tables.length,
      itemBuilder: (context, index) {
        final table = _tables[index];
        return ListTile(
          title: Text(table.tableName),
          trailing: DropdownButton<AccessLevel>(
            value: table.accessLevel,
            items: AccessLevel.values.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(level.name),
              );
            }).toList(),
            onChanged: (newLevel) async {
              if (newLevel != null) {
                setState(() {
                  table.accessLevel = newLevel;
                });
                await _updateTableAccess(table.tableName, newLevel);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDatabaseForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<DatabaseType>(
            value: _selectedDbType,
            decoration: const InputDecoration(labelText: 'Database Type'),
            items: DatabaseType.values.map((dbType) {
              return DropdownMenuItem(
                value: dbType,
                child: Text(dbType.toString().split('.').last),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedDbType = newValue;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a database type' : null,
          ),
          const SizedBox(height: 10),
          if (_selectedDbType == DatabaseType.supabase) ...[
            TextFormField(
              controller: _supabaseUrlController,
              decoration: const InputDecoration(labelText: 'Supabase URL'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter Supabase URL' : null,
            ),
            TextFormField(
              controller: _supabaseKeyController,
              decoration: const InputDecoration(labelText: 'Supabase Key'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter Supabase Key' : null,
            ),
          ] else if (_selectedDbType != null) ...[
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Host'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter host' : null,
            ),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter port' : null,
            ),
            TextFormField(
              controller: _dbnameController,
              decoration: const InputDecoration(labelText: 'Database Name'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter database name' : null,
            ),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter username' : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter password' : null,
            ),
            if (_selectedDbType == DatabaseType.sqlserver)
              TextFormField(
                controller: _driverController,
                decoration: const InputDecoration(labelText: 'ODBC Driver'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Enter driver' : null,
              ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _submitDatabaseForm,
            child: const Text('Save Database Configuration'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers
    _hostController.dispose();
    _portController.dispose();
    _dbnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _driverController.dispose();
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage SQL Database'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Table Access Levels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildTableList(),
            const Divider(height: 40),
            const Text(
              'SQL Database Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildDatabaseForm(),
          ],
        ),
      ),
    );
  }
}
