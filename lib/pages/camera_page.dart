import 'dart:async';
import 'package:flutter/material.dart';
import '../core/state/controller.dart';
import '../core/camera/camera_frame.dart';

/// Camera page - preview and recording controls
class CameraPage extends StatefulWidget {
  final AppController controller;

  const CameraPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final Map<int, CameraFrame?> _latestFrames = {};
  final Map<int, CameraStatus?> _latestStatus = {};
  StreamSubscription? _frameSubscription;
  StreamSubscription? _statusSubscription;

  bool _isPreviewRunning = false;
  String _episodeName = '';
  int _saveFps = 30;

  @override
  void initState() {
    super.initState();
    _saveFps = widget.controller.state.settings.camera.defaultSaveFps;
  }

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }

  void _startPreview() {
    if (_isPreviewRunning) return;

    widget.controller.cameraService.start(widget.controller.state.settings.camera);

    _frameSubscription = widget.controller.cameraService.frames.listen((frame) {
      if (mounted) {
        setState(() {
          _latestFrames[frame.camId] = frame;
        });
      }
    });

    _statusSubscription = widget.controller.cameraService.status.listen((status) {
      if (mounted) {
        setState(() {
          _latestStatus[status.camId] = status;
        });
      }
    });

    setState(() {
      _isPreviewRunning = true;
    });
  }

  void _stopPreview() {
    if (!_isPreviewRunning) return;

    _frameSubscription?.cancel();
    _statusSubscription?.cancel();
    _frameSubscription = null;
    _statusSubscription = null;

    widget.controller.cameraService.stop();

    setState(() {
      _isPreviewRunning = false;
      _latestFrames.clear();
      _latestStatus.clear();
    });
  }

  void _startRecording() {
    if (_episodeName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter episode name')),
      );
      return;
    }

    if (!_isPreviewRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start preview first')),
      );
      return;
    }

    // Start recording would be handled by EpisodeManager integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording started: $_episodeName @ ${_saveFps}fps')),
    );
  }

  void _stopRecording() {
    // Stop recording would be handled by EpisodeManager integration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording stopped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxViews = widget.controller.state.settings.camera.maxViews;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Camera Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Toolbar
            Card(
              color: const Color(0xFF2A2A2A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Start/Stop Preview
                        ElevatedButton.icon(
                          onPressed: _isPreviewRunning ? _stopPreview : _startPreview,
                          icon: Icon(_isPreviewRunning ? Icons.stop : Icons.play_arrow),
                          label: Text(_isPreviewRunning ? 'Stop Preview' : 'Start Preview'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPreviewRunning
                                ? const Color(0xFFE74C3C)
                                : const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Episode Name
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Episode Name',
                              labelStyle: TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              _episodeName = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Save FPS
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<int>(
                            value: _saveFps,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Save FPS',
                              labelStyle: TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [10, 15, 20, 30].map((fps) {
                              return DropdownMenuItem(
                                value: fps,
                                child: Text('$fps FPS'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _saveFps = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Start Recording
                        ElevatedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.fiber_manual_record),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE74C3C),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Stop Recording
                        ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF555555),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Camera Previews
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: maxViews == 1 ? 1 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 4 / 3,
                ),
                itemCount: maxViews,
                itemBuilder: (context, index) {
                  return _buildCameraPreview(index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(int camId) {
    final frame = _latestFrames[camId];
    final status = _latestStatus[camId];

    return Card(
      color: const Color(0xFF2A2A2A),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: status?.isOnline ?? false
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                ),
                const SizedBox(width: 8),
                Text(
                  'Camera $camId',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                if (status != null) ...[
                  Text(
                    '${status.fps.toStringAsFixed(1)} FPS',
                    style: const TextStyle(color: Color(0xFF3498DB), fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  if (status.width != null && status.height != null)
                    Text(
                      '${status.width}×${status.height}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ],
            ),
          ),
          // Preview
          Expanded(
            child: Container(
              color: Colors.black,
              child: frame != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          frame.jpegBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                        // Timestamp overlay
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  frame.wallIso.replaceAll('-', ':'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  'Mono: ${frame.tsMonoMs}',
                                  style: const TextStyle(
                                    color: Color(0xFF3498DB),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            status?.error != null
                                ? Icons.error_outline
                                : Icons.videocam_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            status?.error ?? 'No signal',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
