// Basic Flutter widget test for FlexPAL Control Panel

import 'package:flutter_test/flutter_test.dart';
import 'package:flexpal_control/core/state/controller.dart';
import 'package:flexpal_control/core/state/app_state.dart';
import 'package:flexpal_control/core/udp/udp_service.dart';
import 'package:flexpal_control/core/utils/logger.dart';
import 'package:flexpal_control/core/record/recorder.dart';
import 'package:flexpal_control/core/camera/camera_service.dart';
import 'package:flexpal_control/core/camera/camera_recorder.dart';
import 'package:flexpal_control/core/gripper/gripper_service.dart';

void main() {
  testWidgets('FlexPAL app smoke test', (WidgetTester tester) async {
    // Initialize all dependencies
    final state = AppState();
    final udpService = UdpService();
    final logger = Logger();
    final recorder = Recorder('./test_recordings');
    final cameraService = CameraService();
    final cameraRecorder = CameraRecorder();
    final gripperService = GripperService();

    final controller = AppController(
      state: state,
      udpService: udpService,
      recorder: recorder,
      cameraService: cameraService,
      cameraRecorder: cameraRecorder,
      gripperService: gripperService,
      logger: logger,
    );

    await controller.init();

    // The app should initialize without errors
    expect(controller.state.settings.mode, isNotNull);
  });
}
