import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'core/state/app_state.dart';
import 'core/state/controller.dart';
import 'core/udp/udp_service.dart';
import 'core/record/recorder.dart';
import 'core/camera/camera_service.dart';
import 'core/camera/camera_recorder.dart';
import 'core/utils/logger.dart';
import 'pages/overview_page.dart';
import 'pages/remote_page.dart';
import 'pages/monitor_page.dart';
import 'pages/camera_page.dart';
import 'pages/logs_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize components
  final state = AppState();
  final udpService = UdpService();
  final logger = Logger();

  // Get documents directory for recordings
  final docsDir = await getApplicationDocumentsDirectory();
  final recorder = Recorder('${docsDir.path}/VLA_Records');

  // Initialize camera services
  final cameraService = CameraService();
  final cameraRecorder = CameraRecorder();

  final controller = AppController(
    state: state,
    udpService: udpService,
    recorder: recorder,
    cameraService: cameraService,
    cameraRecorder: cameraRecorder,
    logger: logger,
  );

  await controller.init();

  runApp(FlexPalApp(controller: controller));
}

class FlexPalApp extends StatelessWidget {
  final AppController controller;

  const FlexPalApp({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlexPAL Control',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3498DB),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3498DB),
          secondary: Color(0xFF2ECC71),
          error: Color(0xFFE74C3C),
        ),
        useMaterial3: true,
      ),
      home: MainPage(controller: controller),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  final AppController controller;

  const MainPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<({IconData icon, String label})> _navItems = [
    (icon: FontAwesomeIcons.grip, label: 'Overview'),
    (icon: FontAwesomeIcons.gamepad, label: 'Remote'),
    (icon: FontAwesomeIcons.chartLine, label: 'Monitor'),
    (icon: FontAwesomeIcons.video, label: 'Camera'),
    (icon: FontAwesomeIcons.rectangleList, label: 'Logs'),
    (icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUdp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle
    if (state == AppLifecycleState.paused) {
      // App goes to background
    } else if (state == AppLifecycleState.resumed) {
      // App comes to foreground
    }
  }

  Future<void> _initializeUdp() async {
    try {
      await widget.controller.startUdp();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start UDP: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'FlexPAL Control Suite',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            ListenableBuilder(
              listenable: widget.controller.state,
              builder: (context, _) {
                final state = widget.controller.state;
                return Row(
                  children: [
                    _buildStatusIndicator(
                      state.udpRunning ? 'UDP' : 'DISCONNECTED',
                      state.udpRunning ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    ),
                    if (state.sending) ...[
                      const SizedBox(width: 8),
                      _buildStatusIndicator('SENDING', const Color(0xFF3498DB)),
                    ],
                    if (state.recording) ...[
                      const SizedBox(width: 8),
                      _buildStatusIndicator('REC', const Color(0xFFE74C3C)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 4,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          OverviewPage(controller: widget.controller),
          RemotePage(controller: widget.controller),
          MonitorPage(controller: widget.controller),
          CameraPage(controller: widget.controller),
          LogsPage(controller: widget.controller),
          SettingsPage(controller: widget.controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF2A2A2A),
        indicatorColor: const Color(0xFF3498DB),
        destinations: _navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
