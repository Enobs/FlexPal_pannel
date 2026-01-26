import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/state/controller.dart';
import '../core/models/settings.dart';

/// Settings page - configure network and system parameters
class SettingsPage extends StatefulWidget {
  final AppController controller;

  const SettingsPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _addressController;
  late TextEditingController _sendPortController;
  late TextEditingController _recvPortController;
  late TextEditingController _rateController;
  int _mode = 3;
  String _storagePath = '';

  // Camera settings controllers
  late TextEditingController _cameraBaseIpController;
  late TextEditingController _cameraPortsController;
  late TextEditingController _cameraPathController;
  late TextEditingController _cameraOutputRootController;
  int _cameraMaxViews = 3;
  int _cameraSaveFps = 30;

  // Gripper settings controllers
  late TextEditingController _gripperIpController;
  late TextEditingController _gripperPortController;
  late TextEditingController _gripperMaxAngleController;
  bool _gripperEnabled = true;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.state.settings;

    _addressController = TextEditingController(text: settings.broadcastAddress);
    _sendPortController = TextEditingController(text: settings.sendPort.toString());
    _recvPortController = TextEditingController(text: settings.recvPort.toString());
    _rateController = TextEditingController(text: settings.sendRateHz.toString());
    _mode = settings.mode;

    // Initialize camera settings
    _cameraBaseIpController = TextEditingController(text: settings.camera.baseIp);
    _cameraPortsController = TextEditingController(text: settings.camera.ports.join(', '));
    _cameraPathController = TextEditingController(text: settings.camera.path);
    _cameraOutputRootController = TextEditingController(text: settings.camera.outputRoot);
    _cameraMaxViews = settings.camera.maxViews;
    _cameraSaveFps = settings.camera.defaultSaveFps;

    // Initialize gripper settings
    _gripperIpController = TextEditingController(text: settings.gripper.ip);
    _gripperPortController = TextEditingController(text: settings.gripper.port.toString());
    _gripperMaxAngleController = TextEditingController(text: settings.gripper.maxAngle.toString());
    _gripperEnabled = settings.gripper.enabled;

    _loadStoragePath();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _sendPortController.dispose();
    _recvPortController.dispose();
    _rateController.dispose();
    _cameraBaseIpController.dispose();
    _cameraPortsController.dispose();
    _cameraPathController.dispose();
    _cameraOutputRootController.dispose();
    _gripperIpController.dispose();
    _gripperPortController.dispose();
    _gripperMaxAngleController.dispose();
    super.dispose();
  }

  Future<void> _loadStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      _storagePath = '${dir.path}/VLA_Records';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  // Network settings
                  _buildSectionTitle('Network Configuration'),
                  _buildTextField(
                    'Broadcast Address',
                    _addressController,
                    'e.g., 192.168.137.255',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Send Port',
                    _sendPortController,
                    'e.g., 5005',
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Receive Port',
                    _recvPortController,
                    'e.g., 5006',
                    isNumeric: true,
                  ),
                  const SizedBox(height: 24),
                  // Control settings
                  _buildSectionTitle('Control Configuration'),
                  _buildTextField(
                    'Default Send Rate (Hz)',
                    _rateController,
                    '10-50',
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    'Default Mode',
                    _mode,
                    {
                      1: 'Pressure',
                      2: 'PWM',
                      3: 'Length',
                    },
                    (value) {
                      setState(() {
                        _mode = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Camera settings
                  _buildSectionTitle('Camera Configuration'),
                  _buildTextField(
                    'Base IP Address',
                    _cameraBaseIpController,
                    'e.g., 172.31.243.152',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Camera Ports (comma-separated)',
                    _cameraPortsController,
                    'e.g., 8080, 8081, 8082',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'MJPEG Stream Path',
                    _cameraPathController,
                    'e.g., /?action=stream',
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    'Max Camera Views',
                    _cameraMaxViews,
                    {1: '1 Camera', 2: '2 Cameras', 3: '3 Cameras'},
                    (value) {
                      setState(() {
                        _cameraMaxViews = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    'Default Save FPS',
                    _cameraSaveFps,
                    {10: '10 FPS', 15: '15 FPS', 20: '20 FPS', 30: '30 FPS'},
                    (value) {
                      setState(() {
                        _cameraSaveFps = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Output Root Directory',
                    _cameraOutputRootController,
                    './VLA_Records',
                  ),
                  const SizedBox(height: 24),
                  // Gripper settings
                  _buildSectionTitle('Gripper Configuration'),
                  _buildTextField(
                    'Gripper IP Address',
                    _gripperIpController,
                    'e.g., 192.168.137.124',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Gripper UDP Port',
                    _gripperPortController,
                    'e.g., 5010',
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Max Gripper Angle',
                    _gripperMaxAngleController,
                    'e.g., 80',
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _buildSwitch(
                    'Gripper Enabled',
                    _gripperEnabled,
                    (value) {
                      setState(() {
                        _gripperEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Storage
                  _buildSectionTitle('Storage'),
                  _buildInfoCard('Recording Path', _storagePath),
                  const SizedBox(height: 24),
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _restoreDefaults,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore Defaults'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF555555),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Apply Network Changes Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyNetworkChanges,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Apply Network Changes (Restart UDP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3498DB),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    int value,
    Map<int, String> items,
    Function(int?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: items.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF3498DB), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    try {
      // Parse camera ports
      final portsText = _cameraPortsController.text.trim();
      final ports = portsText
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .where((p) => p != null)
          .cast<int>()
          .toList();

      if (ports.isEmpty) {
        throw Exception('Invalid camera ports');
      }

      final newSettings = widget.controller.state.settings.copyWith(
        broadcastAddress: _addressController.text.trim(),
        sendPort: int.parse(_sendPortController.text.trim()),
        recvPort: int.parse(_recvPortController.text.trim()),
        sendRateHz: int.parse(_rateController.text.trim()).clamp(10, 50),
        mode: _mode,
        camera: widget.controller.state.settings.camera.copyWith(
          baseIp: _cameraBaseIpController.text.trim(),
          ports: ports,
          path: _cameraPathController.text.trim(),
          maxViews: _cameraMaxViews,
          defaultSaveFps: _cameraSaveFps,
          outputRoot: _cameraOutputRootController.text.trim(),
        ),
        gripper: widget.controller.state.settings.gripper.copyWith(
          ip: _gripperIpController.text.trim(),
          port: int.parse(_gripperPortController.text.trim()),
          maxAngle: int.parse(_gripperMaxAngleController.text.trim()),
          enabled: _gripperEnabled,
        ),
      );

      await widget.controller.saveSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  void _restoreDefaults() {
    setState(() {
      _addressController.text = '192.168.137.255';
      _sendPortController.text = '5005';
      _recvPortController.text = '5006';
      _rateController.text = '25';
      _mode = 3;

      // Restore camera defaults
      _cameraBaseIpController.text = '172.31.243.152';
      _cameraPortsController.text = '8080, 8081, 8082';
      _cameraPathController.text = '/?action=stream';
      _cameraOutputRootController.text = './VLA_Records';
      _cameraMaxViews = 3;
      _cameraSaveFps = 30;

      // Restore gripper defaults
      _gripperIpController.text = '192.168.137.244';
      _gripperPortController.text = '5010';
      _gripperMaxAngleController.text = '80';
      _gripperEnabled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defaults restored (not saved yet)')),
    );
  }

  Future<void> _applyNetworkChanges() async {
    try {
      // Stop current UDP connection
      await widget.controller.stopUdp();

      // Wait a moment for cleanup
      await Future.delayed(const Duration(milliseconds: 300));

      // Start with new settings
      await widget.controller.startUdp();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network settings applied! UDP restarted.'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart UDP: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    }
  }
}
