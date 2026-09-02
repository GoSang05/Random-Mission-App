import 'dart:io';

import 'package:image/image.dart' as image;

Future<void> main(List<String> arguments) async {
  final sourcePath = arguments.isEmpty
      ? 'assets/branding/doit_app_icon.png'
      : arguments.first;
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Launcher icon source not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final source = image.decodePng(await sourceFile.readAsBytes());
  if (source == null) {
    stderr.writeln('Could not decode launcher icon: $sourcePath');
    exitCode = 3;
    return;
  }

  const androidIcons = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  for (final entry in androidIcons.entries) {
    await _writeResized(source, entry.key, entry.value, preserveAlpha: true);
  }

  const iosIcons = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final entry in iosIcons.entries) {
    await _writeResized(
      source,
      '$iosDirectory/${entry.key}',
      entry.value,
      preserveAlpha: false,
    );
  }
}

Future<void> _writeResized(
  image.Image source,
  String path,
  int size, {
  required bool preserveAlpha,
}) async {
  final resized = image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
  image.Image output = resized;
  if (!preserveAlpha) {
    output = image.Image(width: size, height: size, numChannels: 3);
    image.fill(output, color: image.ColorRgb8(250, 247, 237));
    image.compositeImage(output, resized);
  }
  final destination = File(path);
  destination.parent.createSync(recursive: true);
  await destination.writeAsBytes(image.encodePng(output, level: 9));
  stdout.writeln('Wrote $path ($size x $size)');
}
