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
  final TextEditingController _modelController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLLMConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _hostController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // Fetch the current LLM configuration from the backend.
  Future<void> _loadLLMConfig() async {
    final response = await AuthService.getLLMApiKey();
    if (response != null && response['status'] == 'success') {
      final data = response['data'];
      setState(() {
        _selectedProvider = data['provider'] ?? 'GROQ';
        _modelController.text = data['model'] ?? '';
        // If provider is OLLAMA, use host; otherwise use API key.
        if (_selectedProvider == 'OLLAMA') {
          _hostController.text = data['config']?['host'] ?? '';
        } else {
          _apiKeyController.text = data['config']?['api_key'] ?? '';
        }
      });
    } else {
      // Handle error or leave default values
      print("Failed to load LLM config");
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // Build the payload with the provider, model, and credentials.
      Map<String, dynamic> payload = {
        'provider': _selectedProvider,
        'model': _modelController.text.trim(),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                    // Model field for specifying the model.
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model (e.g., llama-3.3-70b-versatile)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the model name';
                        }
                        return null;
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
