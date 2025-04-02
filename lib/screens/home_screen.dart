import 'package:analytica_ai/widgets/skeleton_chat_bubble.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode(); // Add this

  // Chat messages – when empty, we show the dashboard.
  List<Map<String, dynamic>> _messages = [];
  String? _sessionId;
  String? _lastRequestId;

  // Dashboard data loaded from the company health API.
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _messageFocusNode.dispose();
    super.dispose();
  }

  // Fetch the company health data.
  Future<void> _fetchDashboardData() async {
    final response = await AuthService.getCompanyHealth();
    if (response != null) {
      setState(() {
        _dashboardData = response;
      });
    }
  }

  // Send the user's message and transition from dashboard to chat.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // Add the user's message.
      _messages.add({'sender': 'user', 'text': text});
      // Insert the skeleton loader for the AI response.
      _messages.add({'sender': 'bot', 'loading': true});
    });

    _messageController.clear();
    _messageFocusNode.unfocus();


    // Make the API call.
    final response = await AuthService.query(text, sessionId: _sessionId);

    // Remove the skeleton loader.
    setState(() {
      _messages.removeWhere((msg) => msg['loading'] == true);
    });

    if (response != null && response['text_response'] != null) {
      if (response['session_id'] != null) {
        _sessionId = response['session_id'];
      }
      if (response['request_id'] != null) {
        _lastRequestId = response['request_id'];
      }
      setState(() {
        _messages.add({'sender': 'bot', 'text': response['text_response']});
        if (response['chart_configs'] != null) {
          _messages.add({'sender': 'bot', 'chart': response['chart_configs']});
        }
      });

      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Error: No response from server.'});
      });
    }
  }

  // Log out the user.
  void _logout() async {
    await AuthService.deleteToken();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Start a new conversation.
  void _startNewConversation() {
    setState(() {
      _sessionId = null;
      _messages = [];
      _lastRequestId = null;
    });
    _messageFocusNode.unfocus();
  }

  // Loads conversation history (same as before).
  Future<void> _loadConversationHistory(String sessionId) async {
    final history = await AuthService.fetchConversationHistory(sessionId);
    if (history != null) {
      List<Map<String, dynamic>> loadedMessages = [];

      for (var msg in history) {
        final String role = msg['role'].toString().toLowerCase();
        final String textContent = msg['text_content'] ?? '';
        final dynamic jsonContent = msg['json_content'];

        loadedMessages.add({
          'sender': role == 'user' ? 'user' : 'bot',
          'text': textContent,
        });

        if (role == 'ai' && jsonContent != null) {
          loadedMessages.add({'sender': 'bot', 'chart': jsonContent});
        }
      }

      setState(() {
        _sessionId = sessionId;
        _messages = loadedMessages;
      });

      // Scroll to the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversation history')),
      );
    }
  }

  // Drawer widget that displays past conversations.
Widget _buildDrawer() {
  final user = AuthService.currentUser;
  return Drawer(
    child: SafeArea(
      child: Column(
        children: [
          // User header with name and organization.
          UserAccountsDrawerHeader(
            accountName: Text(user?.userName ?? 'Guest'),
            accountEmail: Text(user?.orgName ?? 'No Organization'),
            currentAccountPicture: CircleAvatar(
              child: Text(
                user != null && user.userName.isNotEmpty
                    ? user.userName.substring(0, 1).toUpperCase()
                    : 'G',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          // List of past conversations.
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
          // If the user's role is admin, show an admin panel option.
          if (user != null && user.role == 'admin')
            ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Go to Admin Panel'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin');
              },
            ),
        ],
      ),
    ),
  );
}

  // Builds a chat text bubble.
  Widget _buildTextBubble(Map<String, dynamic> message) {
    bool isUser = message['sender'] == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser ? Colors.blueAccent : Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: isUser ? Radius.circular(12) : Radius.circular(0),
              topRight: isUser ? Radius.circular(0) : Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Text(
            message['text'] ?? '',
            style: TextStyle(color: isUser ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  // Builds a chat bubble that renders a chart (for backward compatibility).
  Widget _buildChartBubble(Map<String, dynamic> chartConfig) {
    return ChartBubble(chartConfig: chartConfig);
  }

  // Chooses between text or chart bubble.
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    if (message['loading'] == true) {
      return SkeletonChatBubble();
    } else if (message.containsKey('chart')) {
      return _buildChartBubble(message['chart']);
    } else {
      return _buildTextBubble(message);
    }
  }


  // Builds the chat interface list.
  Widget _buildChatInterface() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  // Builds the dashboard view with charts and company health text.
  Widget _buildDashboard() {
    if (_dashboardData == null) {
      return Center(child: CircularProgressIndicator());
    }
    final chartConfigs = _dashboardData!['chart_configs'];
    final primaryCharts = chartConfigs != null ? chartConfigs['primary_charts'] as List<dynamic> : [];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render the first two charts from the primary charts list.
          if (primaryCharts.isNotEmpty) ...[
            DashboardChart(
              chartConfig: primaryCharts[0],
              csvCollection: chartConfigs['csv_collection'],
              isDashboard: true,
            ),
            SizedBox(height: 16),
            if (primaryCharts.length > 1)
              DashboardChart(
                chartConfig: primaryCharts[1],
                csvCollection: chartConfigs['csv_collection'],
                isDashboard: true,
              ),
            SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "Company Health",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          // Display company health status text.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              _dashboardData!['text_response'] ?? '',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  // Main build method with an AnimatedSwitcher to transition between dashboard and chat.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          IconButton(
            icon: Icon(Icons.description),
            tooltip: "Generate Report",
            onPressed: _generateReport,
          ),
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
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _messages.isEmpty ? _buildDashboard() : _buildChatInterface(),
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
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration.collapsed(hintText: "Type your message..."),
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

  // Generate report and display in overlay.
  Future<void> _generateReport() async {
    if (_lastRequestId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No report available yet.')));
      return;
    }
    final reportResponse = await AuthService.generateReport(_lastRequestId!);
    if (reportResponse != null && reportResponse['html'] != null) {
      final String reportHtml = reportResponse['html'];
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
}

// A helper widget for backward compatibility (chat bubble rendering).
class ChartBubble extends StatelessWidget {
  final Map<String, dynamic> chartConfig;

  const ChartBubble({Key? key, required this.chartConfig}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (chartConfig['primary_charts'] == null || chartConfig['primary_charts'].isEmpty) {
      return SizedBox();
    }
    // Reuse DashboardChart for rendering.
    final primaryChart = chartConfig['primary_charts'][0];
    return DashboardChart(
      chartConfig: primaryChart,
      csvCollection: chartConfig['csv_collection'],
    );
  }
}

// New widget to render an individual dashboard chart.
// It supports both bar and line chart types.
class DashboardChart extends StatelessWidget {
  final Map<String, dynamic> chartConfig;
  final Map<String, dynamic> csvCollection;
  final bool isDashboard; // If true, apply dashboard styling.

  const DashboardChart({
    Key? key,
    required this.chartConfig,
    required this.csvCollection,
    this.isDashboard = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int csvIndex = chartConfig['csv_index'];
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
    List<List<dynamic>> csvData =
        const CsvToListConverter().convert(csvContent);
    if (csvData.isEmpty) return SizedBox(child: Text("No CSV data"));

    final List<String> header =
        csvData.first.map((e) => e.toString()).toList();
    final String labelColumn = chartConfig['mapping']['label_column'];
    final String valueColumn = chartConfig['mapping']['value_column'];
    final int labelIndex = header.indexOf(labelColumn);
    final int valueIndex = header.indexOf(valueColumn);
    if (labelIndex < 0 || valueIndex < 0) {
      return SizedBox(child: Text("Invalid CSV mapping"));
    }

    final String chartTitle = chartConfig['title'] ?? 'Chart';
    final String chartType = chartConfig['type'] ?? 'bar';

    Widget chartWidget;
    if (chartType == 'bar') {
      // Build a bar chart.
      List<BarChartGroupData> barGroups = [];
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        final double value =
            double.tryParse(row[valueIndex].toString()) ?? 0.0;
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: value,
                color: Colors.blue,
                width: 20,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
            showingTooltipIndicators: [],
          ),
        );
      }
      chartWidget = BarChart(
        BarChartData(
          barGroups: barGroups,
          gridData: FlGridData(
            drawHorizontalLine: true,
            horizontalInterval: 1,
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
              left: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt() - 1;
                  if (index < 0 || index >= csvData.length - 1) {
                    return SizedBox();
                  }
                  String label = csvData[index + 1][labelIndex].toString();
                  if (label.length > 15) {
                    label = label.substring(0, 15) + "...";
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Transform.rotate(
                      angle: -0.45,
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 60,
                        child: Text(
                          label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.black),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
                reservedSize: 44,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String label = csvData[group.x.toInt()][labelIndex].toString();
                return BarTooltipItem(
                  '$label\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: rod.toY.toString(),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } else if (chartType == 'line') {
      // Build a line chart.
      List<FlSpot> spots = [];
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        final double value =
            double.tryParse(row[valueIndex].toString()) ?? 0.0;
        spots.add(FlSpot(i.toDouble(), value));
      }
      chartWidget = LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: Colors.blue,
              dotData: FlDotData(show: true),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt() - 1;
                  if (index < 0 || index >= csvData.length - 1) {
                    return SizedBox();
                  }
                  String label = csvData[index + 1][labelIndex].toString();
                  if (label.length > 10) {
                    label = label.substring(0, 10) + "...";
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
        ),
      );
    } else {
      chartWidget = Center(child: Text("Chart type not supported"));
    }

    // When used in the chat, align left with a max width constraint.
    // For dashboard, center the chart with increased margins and no width constraint.
    Widget container = Container(
      margin: isDashboard
          ? EdgeInsets.symmetric(vertical: 8, horizontal: 16)
          : EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              chartTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.7,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: chartWidget,
            ),
          ),
        ],
      ),
    );

    return isDashboard
        ? Center(child: container)
        : Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: container,
            ),
          );
  }
}
