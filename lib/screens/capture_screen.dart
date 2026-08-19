import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mission_data.dart';

class CaptureResult {
  const CaptureResult({required this.path, required this.kind});

  final String path;
  final MissionMediaKind kind;
}

typedef CaptureSaveCallback =
    Future<void> Function(
      CaptureResult result,
      ValueChanged<double> onProgress,
    );

enum CaptureFlowState {
  idle,
  capturing,
  cancelled,
  permissionDenied,
  preview,
  saving,
  success,
  failure,
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    required this.missionTitle,
    required this.onSave,
    this.imagePicker,
    super.key,
  });

  final String missionTitle;
  final CaptureSaveCallback onSave;
  final ImagePicker? imagePicker;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  static const _maxPhotoBytes = 15 * 1024 * 1024;
  static const _maxVideoBytes = 50 * 1024 * 1024;
  static const _permissionCodes = {
    'camera_access_denied',
    'camera_access_restricted',
    'camera_access_denied_without_prompt',
    'photo_access_denied',
    'photo_access_restricted',
    'photo_access_denied_without_prompt',
    'video_access_denied',
    'video_access_restricted',
    'video_access_denied_without_prompt',
    'permission_denied',
  };

  late final ImagePicker _picker;
  late final AnimationController _shutterController;
  late final Animation<double> _shutterScale;

  MissionMediaKind _kind = MissionMediaKind.photo;
  CaptureFlowState _state = CaptureFlowState.idle;
  ImageSource _lastSource = ImageSource.camera;
  XFile? _media;
  Uint8List? _previewBytes;
  String? _failureMessage;
  double _progress = 0;
  bool _flashVisible = false;

  bool get _busy =>
      _state == CaptureFlowState.capturing ||
      _state == CaptureFlowState.saving ||
      _state == CaptureFlowState.success;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _shutterScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 0.82), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.08), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 30),
        ]).animate(
          CurvedAnimation(parent: _shutterController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _shutterController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _validateMedia(XFile media, MissionMediaKind kind) async {
    if (media.path.trim().isEmpty) {
      throw const FormatException('선택한 파일을 열 수 없어요.');
    }
    final length = await media.length();
    final maxBytes = kind == MissionMediaKind.photo
        ? _maxPhotoBytes
        : _maxVideoBytes;
    if (length == 0) throw const FormatException('빈 파일은 사용할 수 없어요.');
    if (length > maxBytes) {
      throw const FormatException('파일이 너무 커요. 더 짧거나 작은 미디어를 선택해주세요.');
    }
    if (kind == MissionMediaKind.video) return null;

    final bytes = await media.readAsBytes();
    final image = await decodeImageFromList(bytes);
    image.dispose();
    return bytes;
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;

    final selectedKind = _kind;
    _lastSource = source;
    setState(() {
      _state = CaptureFlowState.capturing;
      _failureMessage = null;
      _flashVisible = true;
    });
    _shutterController.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;
    setState(() => _flashVisible = false);

    try {
      final picked = selectedKind == MissionMediaKind.photo
          ? await _picker.pickImage(
              source: source,
              imageQuality: 88,
              maxWidth: 1920,
              maxHeight: 1920,
            )
          : await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 15),
            );
      if (!mounted) return;

      if (picked == null) {
        setState(() => _state = CaptureFlowState.cancelled);
        return;
      }

      final previewBytes = await _validateMedia(picked, selectedKind);
      if (!mounted) return;

      setState(() {
        _kind = selectedKind;
        _media = picked;
        _previewBytes = previewBytes;
        _state = CaptureFlowState.preview;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _media = null;
        _previewBytes = null;
        _state = CaptureFlowState.failure;
        _failureMessage = error.message;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final permissionDenied = _permissionCodes.contains(
        error.code.toLowerCase(),
      );
      setState(() {
        _state = permissionDenied
            ? CaptureFlowState.permissionDenied
            : CaptureFlowState.failure;
        _failureMessage = permissionDenied
            ? '설정에서 카메라와 사진 접근 권한을 허용해주세요.'
            : '카메라를 열지 못했어요. 다시 시도해주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = CaptureFlowState.failure;
        _failureMessage = '미디어를 불러오지 못했어요. 다시 시도해주세요.';
      });
    }
  }

  Future<void> _save() async {
    final media = _media;
    if (_busy || media == null || media.path.trim().isEmpty) return;

    setState(() {
      _state = CaptureFlowState.saving;
      _failureMessage = null;
      _progress = 0;
    });

    int bytes;
    try {
      bytes = await media.length();
    } catch (_) {
      if (mounted) {
        setState(() {
          _media = null;
          _previewBytes = null;
          _state = CaptureFlowState.failure;
          _failureMessage = '파일 크기를 확인하지 못했어요. 다시 선택해주세요.';
        });
      }
      return;
    }
    if (!mounted) return;
    final maxBytes = _kind == MissionMediaKind.photo
        ? _maxPhotoBytes
        : _maxVideoBytes;
    if (bytes == 0 || bytes > maxBytes) {
      setState(() {
        _media = null;
        _previewBytes = null;
        _state = CaptureFlowState.failure;
        _failureMessage = bytes == 0
            ? '빈 파일은 저장할 수 없어요.'
            : '파일이 너무 커요. 더 짧거나 작은 미디어를 선택해주세요.';
      });
      return;
    }

    try {
      await widget.onSave(
        CaptureResult(path: media.path, kind: _kind),
        _setProgress,
      );
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _state = CaptureFlowState.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = CaptureFlowState.failure;
        _failureMessage = '저장하지 못했어요. 다시 시도해주세요.';
      });
    }
  }

  void _setProgress(double value) {
    if (!mounted || _state != CaptureFlowState.saving || !value.isFinite) {
      return;
    }
    setState(() => _progress = value.clamp(0.0, 1.0).toDouble());
  }

  void _reset() {
    if (_busy) return;
    setState(() {
      _media = null;
      _previewBytes = null;
      _failureMessage = null;
      _progress = 0;
      _state = CaptureFlowState.idle;
    });
  }

  Future<void> _retry() => _media == null ? _pick(_lastSource) : _save();

  void _close() {
    if (!_busy) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF101014);
    final colors = Theme.of(context).colorScheme;
    final modeEnabled = !_busy && _media == null;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        key: const Key('captureScreen'),
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: Colors.white,
          title: const Text('미션 인증'),
          leading: IconButton(
            key: const Key('captureCloseButton'),
            tooltip: '촬영 닫기',
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MissionHeader(title: widget.missionTitle),
                    const SizedBox(height: 12),
                    _ModeSelector(
                      kind: _kind,
                      enabled: modeEnabled,
                      onChanged: (kind) => setState(() => _kind = kind),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildViewport(colors),
                              AnimatedOpacity(
                                key: const Key('captureFlash'),
                                opacity: _flashVisible ? 0.88 : 0,
                                duration: const Duration(milliseconds: 90),
                                child: const ColoredBox(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildActions(),
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

  Widget _buildViewport(ColorScheme colors) {
    return KeyedSubtree(
      key: Key('captureState_${_state.name}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_media == null)
            _EmptyViewfinder(kind: _kind)
          else if (_kind == MissionMediaKind.photo)
            _PhotoPreview(bytes: _previewBytes)
          else
            _VideoPreview(fileName: _media!.name),
          if (_state != CaptureFlowState.idle &&
              _state != CaptureFlowState.preview)
            ColoredBox(
              color: Colors.black54,
              child: Center(child: _buildStateMessage(colors)),
            ),
        ],
      ),
    );
  }

  Widget _buildStateMessage(ColorScheme colors) {
    final (icon, title, message, color) = switch (_state) {
      CaptureFlowState.capturing => (
        Icons.camera_alt_rounded,
        '선택 화면을 여는 중',
        '잠시만 기다려주세요.',
        Colors.white,
      ),
      CaptureFlowState.cancelled => (
        Icons.close_rounded,
        '선택이 취소됐어요',
        '준비되면 다시 시도해주세요.',
        Colors.white,
      ),
      CaptureFlowState.permissionDenied => (
        Icons.no_photography_rounded,
        '권한이 필요해요',
        _failureMessage ?? '카메라와 사진 접근 권한을 확인해주세요.',
        const Color(0xFFFFC857),
      ),
      CaptureFlowState.saving => (
        Icons.cloud_upload_rounded,
        '미리보기 저장 중 ${(_progress * 100).round()}%',
        '완료될 때까지 화면을 닫지 말아주세요.',
        colors.primaryContainer,
      ),
      CaptureFlowState.success => (
        Icons.check_circle_rounded,
        '인증 완료!',
        '미션으로 돌아갈게요.',
        const Color(0xFF63D49B),
      ),
      CaptureFlowState.failure => (
        Icons.error_outline_rounded,
        '문제가 생겼어요',
        _failureMessage ?? '다시 시도해주세요.',
        const Color(0xFFFF8A80),
      ),
      _ => (Icons.camera_alt_rounded, '', '', Colors.white),
    };

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 54),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          if (_state == CaptureFlowState.saving) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              key: const Key('uploadProgressIndicator'),
              value: _progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: Colors.white24,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case CaptureFlowState.idle:
      case CaptureFlowState.capturing:
        return _CaptureActions(
          key: ValueKey(_state),
          kind: _kind,
          enabled: _state == CaptureFlowState.idle,
          shutterScale: _shutterScale,
          onCamera: () => _pick(ImageSource.camera),
          onGallery: () => _pick(ImageSource.gallery),
        );
      case CaptureFlowState.preview:
        return _ActionRow(
          key: const ValueKey('previewActions'),
          secondaryKey: const Key('retakeCaptureButton'),
          secondaryLabel: '다시 찍기',
          secondaryIcon: Icons.replay_rounded,
          onSecondary: _reset,
          primaryKey: const Key('saveCaptureButton'),
          primaryLabel: _kind == MissionMediaKind.photo ? '사진 저장' : '동영상 저장',
          primaryIcon: Icons.check_rounded,
          onPrimary: _save,
        );
      case CaptureFlowState.saving:
        return const SizedBox(
          key: ValueKey('savingActions'),
          height: 52,
          child: Center(
            child: Text(
              '로컬 미리보기에 저장하고 있어요',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      case CaptureFlowState.success:
        return const SizedBox(
          key: ValueKey('successActions'),
          height: 52,
          child: Center(
            child: Text(
              '완료',
              style: TextStyle(
                color: Color(0xFF63D49B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      case CaptureFlowState.cancelled:
      case CaptureFlowState.permissionDenied:
      case CaptureFlowState.failure:
        return _ActionRow(
          key: ValueKey('recoveryActions_${_state.name}'),
          secondaryKey: const Key('cancelCaptureButton'),
          secondaryLabel: '취소',
          secondaryIcon: Icons.close_rounded,
          onSecondary: _close,
          primaryKey: const Key('retryCaptureButton'),
          primaryLabel: _media == null ? '다시 시도' : '저장 재시도',
          primaryIcon: Icons.refresh_rounded,
          onPrimary: _retry,
        );
    }
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                key: const Key('captureMissionTitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.kind,
    required this.enabled,
    required this.onChanged,
  });

  final MissionMediaKind kind;
  final bool enabled;
  final ValueChanged<MissionMediaKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            key: const Key('photoModeButton'),
            label: '사진',
            icon: Icons.photo_camera_rounded,
            selected: kind == MissionMediaKind.photo,
            enabled: enabled,
            onTap: () => onChanged(MissionMediaKind.photo),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeButton(
            key: const Key('videoModeButton'),
            label: '동영상',
            icon: Icons.videocam_rounded,
            selected: kind == MissionMediaKind.video,
            enabled: enabled,
            onTap: () => onChanged(MissionMediaKind.video),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.white38,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyViewfinder extends StatelessWidget {
  const _EmptyViewfinder({required this.kind});

  final MissionMediaKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2935), Color(0xFF17161D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == MissionMediaKind.photo
                  ? Icons.center_focus_strong_rounded
                  : Icons.video_camera_back_rounded,
              color: Colors.white54,
              size: 68,
            ),
            const SizedBox(height: 14),
            Text(
              kind == MissionMediaKind.photo
                  ? '미션 순간을 사진으로 남겨보세요'
                  : '미션 순간을 동영상으로 남겨보세요',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null) return const _PreviewError();
    return Image.memory(
      key: const Key('photoPreview'),
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _PreviewError(),
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF17161D),
      child: Center(
        child: Text(
          '사진 미리보기를 불러오지 못했어요.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('videoPreviewPlaceholder'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF332E51), Color(0xFF17161D)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 82,
              ),
              const SizedBox(height: 16),
              const Text(
                '동영상이 준비됐어요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureActions extends StatelessWidget {
  const _CaptureActions({
    required this.kind,
    required this.enabled,
    required this.shutterScale,
    required this.onCamera,
    required this.onGallery,
    super.key,
  });

  final MissionMediaKind kind;
  final bool enabled;
  final Animation<double> shutterScale;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('galleryPickerButton'),
                onPressed: enabled ? onGallery : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('앨범'),
              ),
            ),
          ),
          ScaleTransition(
            scale: shutterScale,
            child: Semantics(
              button: true,
              label: kind == MissionMediaKind.photo ? '사진 촬영' : '동영상 촬영',
              child: RawMaterialButton(
                key: const Key('captureShutterButton'),
                onPressed: enabled ? onCamera : null,
                elevation: 0,
                fillColor: enabled ? Colors.white : Colors.white38,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white54, width: 5),
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 76,
                  height: 76,
                ),
                child: Icon(
                  kind == MissionMediaKind.photo
                      ? Icons.camera_alt_rounded
                      : Icons.fiber_manual_record_rounded,
                  color: kind == MissionMediaKind.photo
                      ? const Color(0xFF16151B)
                      : const Color(0xFFE84B55),
                  size: 29,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.secondaryKey,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    required this.primaryKey,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    super.key,
  });

  final Key secondaryKey;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback onSecondary;
  final Key primaryKey;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: secondaryKey,
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            icon: Icon(secondaryIcon),
            label: Text(secondaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: primaryKey,
            onPressed: onPrimary,
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}
