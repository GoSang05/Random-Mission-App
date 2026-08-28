import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:random_mission_app/screens/capture_screen.dart';

class _DeniedImagePicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    throw PlatformException(code: 'camera_access_denied');
  }
}

void main() {
  testWidgets('capture screen exposes a recoverable permission state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureScreen(
          missionTitle: '테스트 미션',
          imagePicker: _DeniedImagePicker(),
          onSave: (_, _) async {},
        ),
      ),
    );

    expect(find.byKey(const Key('videoModeButton')), findsNothing);
    await tester.tap(find.byKey(const Key('cameraCaptureButton')));
    await tester.pumpAndSettle();

    expect(find.text('촬영하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(
      find.byKey(const Key('retryCameraPermissionButton')),
      findsOneWidget,
    );
  });
}
