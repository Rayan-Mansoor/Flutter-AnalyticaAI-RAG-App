import 'package:flutter/material.dart';
import 'package:analytica_ai/services/auth_service.dart';

class ManageLLMProviderScreen extends StatefulWidget {
  const ManageLLMProviderScreen({Key? key}) : super(key: key);

  @override
  _ManageLLMProviderScreenState createState() => _ManageLLMProviderScreenState();
}

class _ManageLLMProviderScreenState extends State<ManageLLMProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedProvider = 'GROQ';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // Build the payload using the provided values.
      Map<String, dynamic> payload = {
        'provider': _selectedProvider,
        'gemini_model': 'gemini-2.0-flash',
        'groq_model': 'llama-3.3-70b-versatile',
        'ollama_model': 'gemma3:1b',
      };

      if (_selectedProvider == 'OLLAMA') {
        payload['host'] = _hostController.text.trim();
      } else {
        payload['api_key'] = _apiKeyController.text.trim();
      }

      // Call the AuthService API to set the LLM API key / host.
      final response = await AuthService.setLLMApiKey(payload);

      setState(() {
        _isSubmitting = false;
      });

      if (response != null && response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'LLM provider updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update LLM provider')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage LLM Provider'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Select LLM Provider',
                ),
                items: <String>['GROQ', 'OLLAMA', 'GEMINI'].map((String provider) {
                  return DropdownMenuItem<String>(
                    value: provider,
                    child: Text(provider),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProvider = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _selectedProvider == 'OLLAMA'
                  ? TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host (e.g., http://localhost:11434)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the host URL';
                        }
                        return null;
                      },
                    )
                  : TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the API key';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 24),
              _isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Save'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
