import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:printing/printing.dart';
import 'package:analytica_ai/services/auth_service.dart';

class ReportOverlay extends StatefulWidget {
  final String initialHtml;
  final String requestId;

  const ReportOverlay({
    Key? key,
    required this.initialHtml,
    required this.requestId,
  }) : super(key: key);

  @override
  _ReportOverlayState createState() => _ReportOverlayState();
}

class _ReportOverlayState extends State<ReportOverlay> {
  String currentHtml = "";
  final TextEditingController _instructionController = TextEditingController();
  final TextEditingController _selectedTextController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentHtml = widget.initialHtml;
  }

  Future<void> _updateReport() async {
    // If no text is provided in the "Selected Text" field, send as general instruction.
    String? generalInstruction;
    List<Map<String, dynamic>>? specificInstructions;
    if (_selectedTextController.text.trim().isEmpty) {
      generalInstruction = _instructionController.text.trim();
    } else {
      // Build specific instruction from the selected text and the entered instruction.
      specificInstructions = [
        {
          "id": 1,
          "selectedText": _selectedTextController.text.trim(),
          "instruction": _instructionController.text.trim(),
        }
      ];
    }
    if ((generalInstruction == null || generalInstruction.isEmpty) &&
        (specificInstructions == null || specificInstructions.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please provide instructions.")),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    final updatedReport = await AuthService.updateStructuredReport(
      currentHtml,
      generalInstruction,
      specificInstructions,
    );
    setState(() {
      isLoading = false;
    });
    if (updatedReport != null && updatedReport['html'] != null) {
      setState(() {
        currentHtml = updatedReport['html'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Report updated successfully.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update report.")),
      );
    }
  }

  Future<void> _downloadPdf() async {
    final pdfBytes = await AuthService.downloadPdfReport(currentHtml);
    if (pdfBytes != null) {
      await Printing.sharePdf(bytes: pdfBytes, filename: 'report.pdf');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Generated Report"),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: "Download as PDF",
            onPressed: _downloadPdf,
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Column(
        children: [
          // Render the HTML report.
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(8),
                child: Html(
                  data: currentHtml,
                ),
              ),
            ),
          ),
          // Instructions area.
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _instructionController,
                  decoration: InputDecoration(
                    labelText: "Enter instructions for report update",
                  ),
                  maxLines: null,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _selectedTextController,
                  decoration: InputDecoration(
                    labelText: "Selected text (if any)",
                    hintText: "Copy & paste selected text here",
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8),
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _updateReport,
                        child: Text("Update Report"),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
