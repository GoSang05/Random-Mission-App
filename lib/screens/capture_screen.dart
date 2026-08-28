import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/mission_data.dart';

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
    decoded.dispose();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _previewBytes = bytes;
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
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        foregroundColor: Colors.white,
        title: const Text('사진 인증'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  widget.missionTitle,
                  key: const Key('captureMissionTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: ColoredBox(
                    color: Colors.black,
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        if (_saving)
                          Center(
                            child: CircularProgressIndicator(value: _progress),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_photo == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filledTonal(
                      key: const Key('galleryCaptureButton'),
                      onPressed: _saving ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    GestureDetector(
                      key: const Key('cameraCaptureButton'),
                      onTap: _initializing || _saving ? null : _takePhoto,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white54, width: 6),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('retryCameraPermissionButton'),
                      onPressed: _initializeCamera,
                      icon: const Icon(Icons.refresh_rounded),
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
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('다시 찍기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('saveCaptureButton'),
                        onPressed: _saving ? null : _save,
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
    );
  }

  Widget _buildPreview() {
    if (_previewBytes != null) {
      return Image.memory(_previewBytes!, fit: BoxFit.cover);
    }
    final controller = _camera;
    if (controller != null && controller.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      );
    }
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(
      child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 72),
    );
  }
}
