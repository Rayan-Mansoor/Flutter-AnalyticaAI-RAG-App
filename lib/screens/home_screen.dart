import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:analytica_ai/widgets/report_overlay.dart';
import 'package:analytica_ai/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // List of messages in the chat.
  // Each message is a map that can contain:
  //   - 'sender': either 'user' or 'bot'
  //   - 'text': the text message
  //   - 'chart': optional chart configuration (Map) to render a chart bubble.
  List<Map<String, dynamic>> _messages = [];

  // Stores the current session id for the active conversation.
  String? _sessionId;

  // Stores the last request id received from the AI response.
  String? _lastRequestId;

  // Sends the user message to the query endpoint.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // Add the user's message.
      _messages.add({'sender': 'user', 'text': text});
    });

    // Clear the input field.
    _messageController.clear();

    // Scroll to the bottom.
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Send the query to the backend.
    final response = await AuthService.query(text, sessionId: _sessionId);

    if (response != null && response['text_response'] != null) {
      // Update session id if a new conversation started.
      if (response['session_id'] != null) {
        _sessionId = response['session_id'];
      }
      // Save the request id for report generation.
      if (response['request_id'] != null) {
        _lastRequestId = response['request_id'];
      }
      setState(() {
        // Add the bot's text response.
        _messages.add({'sender': 'bot', 'text': response['text_response']});

        // If chart_configs (aka json_content) is provided, add a separate bubble.
        if (response['chart_configs'] != null) {
          _messages.add({'sender': 'bot', 'chart': response['chart_configs']});
        }
      });

      // Scroll to the bottom again.
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else {
      setState(() {
        // In case of error, display an error message.
        _messages.add({'sender': 'bot', 'text': 'Error: No response from server.'});
      });
    }
  }

  // Log out the user.
  void _logout() async {
    await AuthService.deleteToken();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Starts a new conversation by resetting the session id and clearing the chat.
  void _startNewConversation() {
    setState(() {
      _sessionId = null;
      _messages = [];
      _lastRequestId = null;
    });
  }

  // Loads conversation history for a given session id.
  Future<void> _loadConversationHistory(String sessionId) async {
    final history = await AuthService.fetchConversationHistory(sessionId);
    if (history != null) {
      // Clear current messages.
      List<Map<String, dynamic>> loadedMessages = [];

      // Iterate through each message in the history.
      // Assuming each message has 'role', 'text_content' and 'json_content'
      for (var msg in history) {
        final String role = msg['role'].toString().toLowerCase();
        final String textContent = msg['text_content'] ?? '';
        final dynamic jsonContent = msg['json_content'];

        // Add the text message.
        loadedMessages.add({
          'sender': role == 'user' ? 'user' : 'bot',
          'text': textContent,
        });

        // If it's an AI message and there's chart data, add a separate chart bubble.
        if (role == 'ai' && jsonContent != null) {
          loadedMessages.add({
            'sender': 'bot',
            'chart': jsonContent,
          });
        }
      }

      setState(() {
        _sessionId = sessionId;
        _messages = loadedMessages;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversation history')),
      );
    }
  }

  // Drawer widget that displays the list of past conversations.
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              child: Text('Conversations', style: TextStyle(fontSize: 24)),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>?>(
                future: AuthService.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error loading conversations'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No conversations found'));
                  } else {
                    final conversations = snapshot.data!;
                    return ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final sessionId = conversation['id'].toString();
                        return ListTile(
                          title: Text(
                            conversation['title'] ?? "Conversation: ${conversation['id']}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Messages: ${conversation['total_messages'] ?? 0}'),
                          onTap: () {
                            Navigator.pop(context); // Close the drawer.
                            _loadConversationHistory(sessionId);
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a chat bubble for text messages.
  Widget _buildTextBubble(Map<String, dynamic> message) {
    bool isUser = message['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message['text'] ?? '',
          style: TextStyle(color: isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  // Builds a chat bubble that renders a chart from the provided config.
  Widget _buildChartBubble(Map<String, dynamic> chartConfig) {
    return ChartBubble(chartConfig: chartConfig);
  }

  // Builds a message bubble – either text or chart bubble.
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    if (message.containsKey('chart')) {
      return _buildChartBubble(message['chart']);
    } else {
      return _buildTextBubble(message);
    }
  }

  // Function to generate report and display in an overlay.
  Future<void> _generateReport() async {
    if (_lastRequestId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No report available yet.')));
      return;
    }
    final reportResponse = await AuthService.generateReport(_lastRequestId!);
    if (reportResponse != null && reportResponse['html'] != null) {
      final String reportHtml = reportResponse['html'];
      // Navigate to the full-screen ReportOverlay.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ReportOverlay(initialHtml: reportHtml, requestId: _lastRequestId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to generate report.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          // Generate Report button.
          IconButton(
            icon: Icon(Icons.description),
            tooltip: "Generate Report",
            onPressed: _generateReport,
          ),
          // New Conversation button.
          IconButton(
            icon: Icon(Icons.chat_bubble_outline),
            tooltip: "Start New Conversation",
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                        InputDecoration.collapsed(hintText: "Type your message..."),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget to render a chart based on provided configuration.
class ChartBubble extends StatelessWidget {
  final Map<String, dynamic> chartConfig;

  const ChartBubble({Key? key, required this.chartConfig}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For this example, we will render the first primary chart.
    if (chartConfig['primary_charts'] == null ||
        chartConfig['primary_charts'].isEmpty) {
      return SizedBox();
    }
    final primaryChart = chartConfig['primary_charts'][0];
    final int csvIndex = primaryChart['csv_index'];
    final csvCollection = chartConfig['csv_collection'];
    final List<dynamic> csvs = csvCollection['csvs'];
    Map<String, dynamic>? selectedCSV;
    for (var csv in csvs) {
      if (csv['csv_index'] == csvIndex) {
        selectedCSV = csv;
        break;
      }
    }
    if (selectedCSV == null) {
      return SizedBox(child: Text("CSV data not found"));
    }
    final String csvContent = selectedCSV['content'] as String;
    // Parse the CSV content.
    List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
    if (csvData.isEmpty) return SizedBox(child: Text("No CSV data"));
    // Assume the first row is header.
    final List<String> header =
        csvData.first.map((e) => e.toString()).toList();
    // Get the mapping for label and value columns.
    final String labelColumn = primaryChart['mapping']['label_column'];
    final String valueColumn = primaryChart['mapping']['value_column'];
    final int labelIndex = header.indexOf(labelColumn);
    final int valueIndex = header.indexOf(valueColumn);
    if (labelIndex < 0 || valueIndex < 0) {
      return SizedBox(child: Text("Invalid CSV mapping"));
    }
    // Create bar chart data from CSV rows (skipping header row).
    List<BarChartGroupData> barGroups = [];
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      final double value =
          double.tryParse(row[valueIndex].toString()) ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: value, color: Colors.blue)],
          showingTooltipIndicators: [0],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryChart['title'] ?? 'Chart',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.7,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt() - 1;
                        if (index < 0 || index >= csvData.length - 1) {
                          return SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            csvData[index + 1][labelIndex].toString(),
                            style: TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
