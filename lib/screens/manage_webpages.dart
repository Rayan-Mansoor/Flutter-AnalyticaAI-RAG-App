import 'package:flutter/material.dart';
import 'package:analytica_ai/services/auth_service.dart';

enum AccessLevel { admin, manager, member }

class DocumentDetail {
  final String documentId;
  final String path;
  final String sourceType;
  final String title;
  final String summary;
  AccessLevel accessLevel;

  DocumentDetail({
    required this.documentId,
    required this.path,
    required this.sourceType,
    required this.title,
    required this.summary,
    required this.accessLevel,
  });

  factory DocumentDetail.fromJson(Map<String, dynamic> json) {
    return DocumentDetail(
      documentId: json['document_id'].toString(),
      path: json['path'] ?? '',
      sourceType: json['source_type'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
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

class ManageWebpagesScreen extends StatefulWidget {
  const ManageWebpagesScreen({Key? key}) : super(key: key);

  @override
  _ManageWebpagesScreenState createState() => _ManageWebpagesScreenState();
}

class _ManageWebpagesScreenState extends State<ManageWebpagesScreen> {
  List<DocumentDetail> _webpages = [];
  bool _isProcessingWebsite = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWebpageDetails();
  }

  Future<void> _fetchWebpageDetails() async {
    try {
      final data = await AuthService.getDocumentAccessLevels() ?? [];
      setState(() {
        _webpages = data
            .map<DocumentDetail>((json) => DocumentDetail.fromJson(json))
            .where((doc) => doc.sourceType.toLowerCase() == 'webpage')
            .toList();
      });
    } catch (e) {
      print("Error fetching webpage details: $e");
    }
  }

  Future<void> _updateDocumentAccess(DocumentDetail doc, AccessLevel newLevel) async {
    try {
      await AuthService.updateDocumentAccessLevel(doc.documentId, newLevel.name);
      setState(() {
        doc.accessLevel = newLevel;
      });
    } catch (e) {
      print("Error updating webpage access level: $e");
    }
  }

  Future<void> _processWebsite() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a URL')),
      );
      return;
    }

    setState(() {
      _isProcessingWebsite = true;
    });

    // Call the process website API. The headless option is hardcoded here; modify if needed.
    final response = await AuthService.processWebsite(url, true);

    setState(() {
      _isProcessingWebsite = false;
    });

    if (response != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Website processed successfully. Base URL: ${response['base_url'] ?? ''}'),
        ),
      );
      _urlController.clear();
      // Refresh the list in case a new webpage document is added.
      _fetchWebpageDetails();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to process website')),
      );
    }
  }

  Widget _buildWebpageList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _webpages.length,
      itemBuilder: (context, index) {
        final doc = _webpages[index];
        return ListTile(
          title: Text(doc.title),
          subtitle: Text(
            doc.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: DropdownButton<AccessLevel>(
            value: doc.accessLevel,
            items: AccessLevel.values.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(level.name),
              );
            }).toList(),
            onChanged: (newLevel) async {
              if (newLevel != null) {
                await _updateDocumentAccess(doc, newLevel);
              }
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Webpages'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Webpage Access Levels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildWebpageList(),
            const Divider(height: 40),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Enter website URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _isProcessingWebsite
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _processWebsite,
                    icon: const Icon(Icons.public),
                    label: const Text('Process Website'),
                  ),
          ],
        ),
      ),
    );
  }
}
