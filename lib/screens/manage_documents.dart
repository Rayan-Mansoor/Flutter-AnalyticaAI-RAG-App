import 'dart:io';
import 'package:analytica_ai/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

class ManageDocumentsScreen extends StatefulWidget {
  const ManageDocumentsScreen({Key? key}) : super(key: key);

  @override
  _ManageDocumentsScreenState createState() => _ManageDocumentsScreenState();
}

class _ManageDocumentsScreenState extends State<ManageDocumentsScreen> {
  List<DocumentDetail> _documents = [];
  bool _isProcessingPdf = false;

  @override
  void initState() {
    super.initState();
    _fetchDocumentDetails();
  }

  Future<void> _fetchDocumentDetails() async {
    try {
      final data = await AuthService.getDocumentAccessLevels() ?? [];
      setState(() {
        _documents = data
            .map<DocumentDetail>((json) => DocumentDetail.fromJson(json))
            .where((doc) => doc.sourceType.toLowerCase() == 'pdf')
            .toList();
      });
    } catch (e) {
      print("Error fetching document details: $e");
    }
  }

  Future<void> _updateDocumentAccess(DocumentDetail doc, AccessLevel newLevel) async {
    try {
      await AuthService.updateDocumentAccessLevel(doc.documentId, newLevel.name);
      setState(() {
        doc.accessLevel = newLevel;
      });
    } catch (e) {
      print("Error updating document access level: $e");
    }
  }

  Future<void> _pickAndProcessPdf() async {
    // Open file picker for PDFs.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File pdfFile = File(result.files.single.path!);
      setState(() {
        _isProcessingPdf = true;
      });
      // Call the processPdf API; premiumMode can be toggled as needed.
      final response = await AuthService.processPdf(pdfFile, false);
      setState(() {
        _isProcessingPdf = false;
      });
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF processed successfully: ${response['filename'] ?? ''}')),
        );
        // Optionally refresh the document list if processing adds a new document.
        _fetchDocumentDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process PDF')),
        );
      }
    }
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return ListTile(
          title: Text(doc.title),
          subtitle: Text(
            doc.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Documents'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Document Access Levels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _buildDocumentList(),
            const Divider(height: 40),
            _isProcessingPdf
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _pickAndProcessPdf,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Add PDF for Processing'),
                  ),
          ],
        ),
      ),
    );
  }
}
