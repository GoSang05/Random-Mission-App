import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

import '../models/mission_data.dart';

class LocalMediaStore {
  LocalMediaStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  static const maxImageDimension = 1920;
  static const jpegQuality = 82;

  final Future<Directory> Function() _documentsDirectory;

  Future<String> persist({
    required String sourcePath,
    required MissionMediaKind kind,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('미디어 파일이 없어요.');

    final documents = await _documentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}mission_media',
    );
    await directory.create(recursive: true);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${source.statSync().size}';

    if (kind == MissionMediaKind.video) {
      final extension = _safeExtension(sourcePath, fallback: 'mp4');
      final target = '${directory.path}${Platform.pathSeparator}$id.$extension';
      return (await source.copy(target)).path;
    }

    final target = '${directory.path}${Platform.pathSeparator}$id.jpg';
    try {
      await Isolate.run(() => _optimizePhoto(sourcePath, target));
      return target;
    } catch (_) {
      final extension = _safeExtension(sourcePath, fallback: 'jpg');
      final fallback =
          '${directory.path}${Platform.pathSeparator}$id.$extension';
      return (await source.copy(fallback)).path;
    }
  }

  String _safeExtension(String path, {required String fallback}) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return fallback;
    final extension = fileName.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : fallback;
  }
}

void _optimizePhoto(String sourcePath, String targetPath) {
  final bytes = File(sourcePath).readAsBytesSync();
  var decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('지원하지 않는 이미지 형식입니다.');
  decoded = image.bakeOrientation(decoded);

  if (decoded.width > LocalMediaStore.maxImageDimension ||
      decoded.height > LocalMediaStore.maxImageDimension) {
    decoded = decoded.width >= decoded.height
        ? image.copyResize(decoded, width: LocalMediaStore.maxImageDimension)
        : image.copyResize(decoded, height: LocalMediaStore.maxImageDimension);
  }

  File(targetPath).writeAsBytesSync(
    image.encodeJpg(decoded, quality: LocalMediaStore.jpegQuality),
    flush: true,
  );
}
