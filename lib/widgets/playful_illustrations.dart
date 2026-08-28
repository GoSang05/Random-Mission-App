import 'dart:math' as math;

import 'package:flutter/material.dart';

const playfulInk = Color(0xFF17151D);
const playfulPurple = Color(0xFF6953E8);
const playfulLime = Color(0xFFC8FF08);
const playfulCream = Color(0xFFFFFCED);

class GlobalMissionIllustration extends StatelessWidget {
  const GlobalMissionIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _GlobalMissionPainter());
  }
}

class RoomIllustration extends StatelessWidget {
  const RoomIllustration({required this.variant, super.key});

  final int variant;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RoomPainter(variant % 3));
  }
}

class Doodle extends StatelessWidget {
  const Doodle({
    required this.kind,
    this.color = playfulInk,
    this.size = 22,
    super.key,
  });

  final DoodleKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _DoodlePainter(kind, color)),
    );
  }
}

enum DoodleKind { star, heart, sparkle }

class PlayfulDotBackground extends CustomPainter {
  const PlayfulDotBackground();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(playfulCream, BlendMode.src);
    final paint = Paint()..color = const Color(0x130F0C15);
    for (double y = 16; y < size.height; y += 34) {
      for (
        double x = 14 + ((y ~/ 34).isOdd ? 13 : 0);
        x < size.width;
        x += 38
      ) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlobalMissionPainter extends CustomPainter {
  const _GlobalMissionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = playfulInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final globeCenter = Offset(size.width * .61, size.height * .68);
    final radius = math.min(size.width * .32, size.height * .49);
    canvas.drawCircle(
      globeCenter,
      radius,
      Paint()..color = const Color(0xFF9DEBFF),
    );
    canvas.drawCircle(globeCenter, radius, ink);

    final land = Paint()..color = const Color(0xFFA7E641);
    final leftLand = Path()
      ..moveTo(globeCenter.dx - radius * .92, globeCenter.dy - radius * .32)
      ..quadraticBezierTo(
        globeCenter.dx - radius * .38,
        globeCenter.dy - radius * .82,
        globeCenter.dx - radius * .1,
        globeCenter.dy - radius * .55,
      )
      ..quadraticBezierTo(
        globeCenter.dx + radius * .18,
        globeCenter.dy - radius * .24,
        globeCenter.dx - radius * .06,
        globeCenter.dy + radius * .02,
      )
      ..quadraticBezierTo(
        globeCenter.dx - radius * .34,
        globeCenter.dy + radius * .23,
        globeCenter.dx - radius * .45,
        globeCenter.dy + radius * .67,
      )
      ..quadraticBezierTo(
        globeCenter.dx - radius * .9,
        globeCenter.dy + radius * .47,
        globeCenter.dx - radius * .92,
        globeCenter.dy - radius * .32,
      )
      ..close();
    canvas.drawPath(leftLand, land);
    canvas.drawPath(leftLand, ink..strokeWidth = 2.2);
    final rightLand = Path()
      ..moveTo(globeCenter.dx + radius * .45, globeCenter.dy - radius * .72)
      ..quadraticBezierTo(
        globeCenter.dx + radius * .95,
        globeCenter.dy - radius * .42,
        globeCenter.dx + radius * .82,
        globeCenter.dy - radius * .05,
      )
      ..quadraticBezierTo(
        globeCenter.dx + radius * .55,
        globeCenter.dy + radius * .06,
        globeCenter.dx + radius * .72,
        globeCenter.dy + radius * .48,
      )
      ..quadraticBezierTo(
        globeCenter.dx + radius * .34,
        globeCenter.dy + radius * .7,
        globeCenter.dx + radius * .16,
        globeCenter.dy + radius * .35,
      )
      ..quadraticBezierTo(
        globeCenter.dx + radius * .02,
        globeCenter.dy,
        globeCenter.dx + radius * .45,
        globeCenter.dy - radius * .72,
      )
      ..close();
    canvas.drawPath(rightLand, land);
    canvas.drawPath(rightLand, ink..strokeWidth = 2.2);

    final poleX = globeCenter.dx - radius * .08;
    canvas.drawLine(
      Offset(poleX, globeCenter.dy - radius * .86),
      Offset(poleX, globeCenter.dy - radius * 1.55),
      ink..strokeWidth = 4,
    );
    final flag = Path()
      ..moveTo(poleX + 3, globeCenter.dy - radius * 1.5)
      ..quadraticBezierTo(
        poleX + radius * .35,
        globeCenter.dy - radius * 1.66,
        poleX + radius * .68,
        globeCenter.dy - radius * 1.48,
      )
      ..lineTo(poleX + radius * .58, globeCenter.dy - radius * 1.12)
      ..quadraticBezierTo(
        poleX + radius * .27,
        globeCenter.dy - radius * 1.3,
        poleX + 3,
        globeCenter.dy - radius * 1.18,
      )
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFF83B4));
    canvas.drawPath(flag, ink..strokeWidth = 2.6);

    _cloud(
      canvas,
      Offset(size.width * .18, size.height * .32),
      size.width * .17,
      ink,
    );
    _cloud(
      canvas,
      Offset(size.width * .83, size.height * .3),
      size.width * .13,
      ink,
    );

    final starCenter = Offset(size.width * .28, size.height * .73);
    final star = _starPath(starCenter, radius * .48, 5);
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFDF48));
    canvas.drawPath(star, ink..strokeWidth = 2.8);
    canvas.drawCircle(
      starCenter + Offset(-radius * .11, 0),
      2.2,
      Paint()..color = playfulInk,
    );
    canvas.drawCircle(
      starCenter + Offset(radius * .11, 0),
      2.2,
      Paint()..color = playfulInk,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: starCenter + Offset(0, radius * .07),
        width: radius * .23,
        height: radius * .17,
      ),
      0,
      math.pi,
      false,
      ink..strokeWidth = 2,
    );
  }

  void _cloud(Canvas canvas, Offset center, double width, Paint ink) {
    final path = Path()
      ..moveTo(center.dx - width * .5, center.dy + width * .13)
      ..cubicTo(
        center.dx - width * .58,
        center.dy - width * .12,
        center.dx - width * .28,
        center.dy - width * .27,
        center.dx - width * .13,
        center.dy - width * .14,
      )
      ..cubicTo(
        center.dx,
        center.dy - width * .48,
        center.dx + width * .34,
        center.dy - width * .39,
        center.dx + width * .34,
        center.dy - width * .12,
      )
      ..cubicTo(
        center.dx + width * .68,
        center.dy - width * .12,
        center.dx + width * .63,
        center.dy + width * .2,
        center.dx + width * .42,
        center.dy + width * .2,
      )
      ..lineTo(center.dx - width * .36, center.dy + width * .2)
      ..quadraticBezierTo(
        center.dx - width * .5,
        center.dy + width * .2,
        center.dx - width * .5,
        center.dy + width * .13,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(path, ink..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter(this.variant);
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = playfulInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final sky = [
      const Color(0xFFBDEEFF),
      const Color(0xFFFFEDB6),
      const Color(0xFFCFEAFF),
    ][variant];
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    if (variant == 0) {
      canvas.drawCircle(
        Offset(size.width * .5, size.height * .63),
        size.width * .23,
        Paint()..color = const Color(0xFFA9E754),
      );
      canvas.drawCircle(
        Offset(size.width * .5, size.height * .63),
        size.width * .23,
        ink,
      );
      canvas.drawCircle(
        Offset(size.width * .45, size.height * .61),
        2.5,
        Paint()..color = playfulInk,
      );
      canvas.drawCircle(
        Offset(size.width * .56, size.height * .61),
        2.5,
        Paint()..color = playfulInk,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * .505, size.height * .66),
          width: 17,
          height: 10,
        ),
        0,
        math.pi,
        false,
        ink,
      );
      final hill = Path()
        ..moveTo(0, size.height)
        ..quadraticBezierTo(
          size.width * .25,
          size.height * .72,
          size.width * .54,
          size.height,
        )
        ..close();
      canvas.drawPath(hill, Paint()..color = const Color(0xFF7DDB66));
      canvas.drawPath(hill, ink);
    } else if (variant == 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .48),
          width: size.width * .34,
          height: size.width * .3,
        ),
        Paint()..color = const Color(0xFFFFC6A8),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .48),
          width: size.width * .34,
          height: size.width * .3,
        ),
        ink,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .39),
          width: size.width * .42,
          height: size.width * .24,
        ),
        math.pi,
        math.pi,
        false,
        ink..strokeWidth = 12,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * .18,
          size.height * .72,
          size.width * .64,
          size.height * .2,
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawLine(
        Offset(size.width * .18, size.height * .72),
        Offset(size.width * .82, size.height * .72),
        ink..strokeWidth = 2.5,
      );
      canvas.drawLine(
        Offset(size.width * .5, size.height * .72),
        Offset(size.width * .5, size.height * .92),
        ink,
      );
    } else {
      final colors = [
        const Color(0xFFFF9ABE),
        const Color(0xFF9B84FF),
        const Color(0xFF72DCB1),
      ];
      for (var i = 0; i < 3; i++) {
        final x = size.width * (.28 + i * .22);
        final y = size.height * (.5 + (i.isEven ? .08 : 0));
        canvas.drawCircle(
          Offset(x, y),
          size.width * .12,
          Paint()..color = colors[i],
        );
        canvas.drawCircle(Offset(x, y), size.width * .12, ink..strokeWidth = 2);
        canvas.drawCircle(Offset(x - 5, y), 1.8, Paint()..color = playfulInk);
        canvas.drawCircle(Offset(x + 5, y), 1.8, Paint()..color = playfulInk);
      }
      canvas.drawPath(
        _starPath(
          Offset(size.width * .8, size.height * .2),
          size.width * .07,
          5,
        ),
        Paint()..color = const Color(0xFFFFDB45),
      );
      canvas.drawPath(
        _starPath(
          Offset(size.width * .8, size.height * .2),
          size.width * .07,
          5,
        ),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter(this.kind, this.color);
  final DoodleKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = playfulInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * .09)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    if (kind == DoodleKind.star) {
      final path = _starPath(center, size.width * .42, 5);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, ink);
    } else if (kind == DoodleKind.heart) {
      final path = Path()
        ..moveTo(center.dx, size.height * .83)
        ..cubicTo(
          size.width * .05,
          size.height * .55,
          size.width * .12,
          size.height * .12,
          center.dx,
          size.height * .31,
        )
        ..cubicTo(
          size.width * .88,
          size.height * .12,
          size.width * .95,
          size.height * .55,
          center.dx,
          size.height * .83,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, ink);
    } else {
      canvas.drawLine(
        Offset(center.dx, 1),
        Offset(center.dx, size.height - 1),
        ink..color = color,
      );
      canvas.drawLine(
        Offset(1, center.dy),
        Offset(size.width - 1, center.dy),
        ink,
      );
      canvas.drawLine(
        Offset(size.width * .23, size.height * .23),
        Offset(size.width * .77, size.height * .77),
        ink..strokeWidth = 1.4,
      );
      canvas.drawLine(
        Offset(size.width * .77, size.height * .23),
        Offset(size.width * .23, size.height * .77),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

Path _starPath(Offset center, double radius, int points) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final angle = -math.pi / 2 + i * math.pi / points;
    final r = i.isEven ? radius : radius * .48;
    final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}
