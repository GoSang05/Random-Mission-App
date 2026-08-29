import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/mission_data.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';

class CaptureResult {
  const CaptureResult({required this.path, this.kind = MissionMediaKind.photo});

  final String path;
  final MissionMediaKind kind;
}

typedef CaptureSaveCallback =
    Future<void> Function(
      CaptureResult result,
      ValueChanged<double> onProgress,
    );

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    required this.missionTitle,
    required this.onSave,
    this.imagePicker,
    super.key,
  });

  final String missionTitle;
  final CaptureSaveCallback onSave;

  /// 테스트에서만 외부 플러그인을 대체하기 위한 주입점입니다.
  final ImagePicker? imagePicker;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  static const _maxPhotoBytes = 15 * 1024 * 1024;

  CameraController? _camera;
  XFile? _photo;
  Uint8List? _previewBytes;
  double? _photoAspectRatio;
  bool _initializing = true;
  bool _taking = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.imagePicker != null) {
      _initializing = false;
    } else {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.imagePicker != null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _photo == null) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw CameraException('CameraAccessDenied', '사진 촬영을 위해 카메라 권한이 필요해요.');
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', '사용 가능한 카메라가 없어요.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await _disposeCamera();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.description ?? '카메라를 시작하지 못했어요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = '카메라를 시작하지 못했어요.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _camera;
    _camera = null;
    await controller?.dispose();
  }

  Future<void> _takePhoto() async {
    if (_taking || _saving) return;
    setState(() {
      _taking = true;
      _error = null;
    });
    try {
      final XFile? photo;
      if (widget.imagePicker != null) {
        photo = await widget.imagePicker!.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 88,
        );
      } else {
        final controller = _camera;
        if (controller == null || !controller.value.isInitialized) return;
        photo = await controller.takePicture();
      }
      if (photo == null) return;
      await _setPhoto(photo);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = error.description ?? '촬영하지 못했어요.');
    } catch (_) {
      if (mounted) setState(() => _error = '촬영하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_taking || _saving) return;
    try {
      final photo = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (photo != null) await _setPhoto(photo);
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요.');
    }
  }

  Future<void> _setPhoto(XFile photo) async {
    final length = await photo.length();
    if (length <= 0 || length > _maxPhotoBytes) {
      throw const FormatException('15MB 이하 사진만 사용할 수 있어요.');
    }
    final bytes = await photo.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    final aspectRatio = decoded.width / decoded.height;
    decoded.dispose();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _previewBytes = bytes;
      _photoAspectRatio = aspectRatio;
      _error = null;
    });
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() {
      _saving = true;
      _progress = 0;
      _error = null;
    });
    try {
      await widget.onSave(CaptureResult(path: photo.path), (value) {
        if (mounted) setState(() => _progress = value.clamp(0, 1));
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 저장하지 못했어요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _retake() {
    setState(() {
      _photo = null;
      _previewBytes = null;
      _photoAspectRatio = null;
      _error = null;
    });
    if (widget.imagePicker == null && _camera == null) _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('captureScreen'),
      backgroundColor: const Color(0xFF171A33),
      body: SafeArea(
        child: PlayfulBackground(
          dark: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  children: [
                    PlayfulHeader(
                      title: '사진 인증',
                      dark: true,
                      actions: [
                        PlayfulIconButton(
                          tooltip: '카메라 다시 연결',
                          icon: Icons.camera_alt_rounded,
                          fill: playfulCream,
                          iconColor: playfulPurple,
                          onPressed: _initializeCamera,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE3D1FF), Color(0xFFC9AFFF)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: playfulInk, width: 3),
                        boxShadow: const [
                          BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: playfulPurple,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.missionTitle,
                              key: const Key('captureMissionTitle'),
                              style: const TextStyle(
                                color: playfulInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Doodle(
                            kind: DoodleKind.sparkle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final aspectRatio = _previewAspectRatio(context);
                          return Center(
                            child: AspectRatio(
                              key: const Key('capturePreviewFrame'),
                              aspectRatio: aspectRatio,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: playfulInk,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFF9D72F7),
                                      offset: Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildPreview(),
                                      if (_error != null)
                                        ColoredBox(
                                          color: Colors.black54,
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(28),
                                              child: Text(
                                                _error!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_saving)
                                        Center(
                                          child: CircularProgressIndicator(
                                            value: _progress,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_photo == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          PlayfulIconButton(
                            buttonKey: const Key('galleryCaptureButton'),
                            tooltip: '갤러리',
                            icon: Icons.photo_library_outlined,
                            fill: const Color(0xFFE3D1FF),
                            size: 66,
                            onPressed: _saving ? null : _pickFromGallery,
                          ),
                          GestureDetector(
                            key: const Key('cameraCaptureButton'),
                            onTap: _initializing || _saving ? null : _takePhoto,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: playfulInk, width: 4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFA777FF),
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: playfulInk,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PlayfulIconButton(
                            buttonKey: const Key('retryCameraPermissionButton'),
                            tooltip: '카메라 다시 시도',
                            icon: Icons.refresh_rounded,
                            fill: const Color(0xFFE3D1FF),
                            size: 66,
                            onPressed: _initializeCamera,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('retakeCaptureButton'),
                              onPressed: _saving ? null : _retake,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: playfulCream,
                                foregroundColor: playfulInk,
                                side: const BorderSide(
                                  color: playfulInk,
                                  width: 3,
                                ),
                              ),
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('다시 찍기'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('saveCaptureButton'),
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: playfulLime,
                                foregroundColor: playfulInk,
                                side: const BorderSide(
                                  color: playfulInk,
                                  width: 3,
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('사진 저장'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_previewBytes != null) {
      return Image.memory(_previewBytes!, fit: BoxFit.contain);
    }
    final controller = _camera;
    if (controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(
      child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 72),
    );
  }

  double _previewAspectRatio(BuildContext context) {
    final photoRatio = _photoAspectRatio;
    if (photoRatio != null && photoRatio.isFinite && photoRatio > 0) {
      return photoRatio;
    }

    final controllerRatio = _camera?.value.aspectRatio;
    if (controllerRatio != null &&
        controllerRatio.isFinite &&
        controllerRatio > 0) {
      final isPortrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;
      if (isPortrait && controllerRatio > 1) return 1 / controllerRatio;
      if (!isPortrait && controllerRatio < 1) return 1 / controllerRatio;
      return controllerRatio;
    }

    return MediaQuery.orientationOf(context) == Orientation.portrait
        ? 3 / 4
        : 4 / 3;
  }
}
