import 'package:flutter/material.dart';

import 'playful_illustrations.dart';

class PlayfulBackground extends StatelessWidget {
  const PlayfulBackground({required this.child, this.dark = false, super.key});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: dark ? const _DarkDotPainter() : const _LightPagePainter(),
      child: child,
    );
  }
}

class PlayfulHeader extends StatelessWidget {
  const PlayfulHeader({
    required this.title,
    this.actions = const [],
    this.dark = false,
    this.titleWidget,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final bool dark;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : playfulInk;
    return SizedBox(
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: dark ? playfulCream : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: playfulInk, width: 3),
                  boxShadow: const [
                    BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                  ],
                ),
                child: BackButton(
                  color: playfulInk,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const Spacer(),
              ...actions.expand((item) => [const SizedBox(width: 9), item]),
            ],
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 68),
              child:
                  titleWidget ??
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
            ),
          ),
          Positioned(
            top: 0,
            left: 108,
            child: Doodle(
              kind: DoodleKind.star,
              color: const Color(0xFF9B7BFF),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayfulIconButton extends StatelessWidget {
  const PlayfulIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.buttonKey,
    this.dark = false,
    this.fill,
    this.iconColor,
    this.size = 52,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Key? buttonKey;
  final bool dark;
  final Color? fill;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = fill ?? (dark ? playfulCream : Colors.white);
    final foreground = iconColor ?? playfulInk;
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: playfulInk, width: 3),
        boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size * .26),
          child: Icon(icon, color: foreground, size: size * .54),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class PlayfulSectionHeader extends StatelessWidget {
  const PlayfulSectionHeader({
    required this.title,
    required this.count,
    this.dark = false,
    super.key,
  });

  final String title;
  final int count;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : playfulInk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 68,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF8A68F1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAD9FF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: playfulInk, width: 2.5),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: playfulInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class PlayfulPanel extends StatelessWidget {
  const PlayfulPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.radius = 24,
    this.shadowColor = const Color(0xFFD5C5FF),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: playfulInk, width: 3),
        boxShadow: [
          BoxShadow(color: shadowColor, offset: const Offset(6, 7)),
          const BoxShadow(color: playfulInk, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _DarkDotPainter extends CustomPainter {
  const _DarkDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF171A33), BlendMode.src);
    final paint = Paint()..color = const Color(0x122D3154);
    for (double y = 12; y < size.height; y += 28) {
      for (
        double x = 12 + ((y ~/ 28).isOdd ? 12 : 0);
        x < size.width;
        x += 30
      ) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
    _drawSparkle(
      canvas,
      Offset(size.width * .1, size.height * .2),
      const Color(0xFFA881FF),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * .88, size.height * .72),
      const Color(0xFFFF85AE),
    );
    _drawCloud(canvas, Offset(size.width * .9, size.height * .9), Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LightPagePainter extends CustomPainter {
  const _LightPagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(playfulCream, BlendMode.src);
    final dots = Paint()..color = const Color(0x120F0C15);
    for (double y = 16; y < size.height; y += 32) {
      for (
        double x = 14 + ((y ~/ 32).isOdd ? 13 : 0);
        x < size.width;
        x += 36
      ) {
        canvas.drawCircle(Offset(x, y), 1, dots);
      }
    }
    _drawSparkle(
      canvas,
      Offset(size.width * .12, size.height * .24),
      const Color(0xFF8D70F4),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * .9, size.height * .42),
      const Color(0xFFFF88AD),
    );
    _drawSparkle(
      canvas,
      Offset(size.width * .08, size.height * .77),
      playfulLime,
    );
    _drawCloud(
      canvas,
      Offset(size.width * .92, size.height * .68),
      Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _drawSparkle(Canvas canvas, Offset center, Color color) {
  final fill = Paint()..color = color;
  final ink = Paint()
    ..color = playfulInk
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  final path = Path()
    ..moveTo(center.dx, center.dy - 8)
    ..lineTo(center.dx + 3, center.dy - 3)
    ..lineTo(center.dx + 8, center.dy)
    ..lineTo(center.dx + 3, center.dy + 3)
    ..lineTo(center.dx, center.dy + 8)
    ..lineTo(center.dx - 3, center.dy + 3)
    ..lineTo(center.dx - 8, center.dy)
    ..lineTo(center.dx - 3, center.dy - 3)
    ..close();
  canvas.drawPath(path, fill);
  canvas.drawPath(path, ink);
}

void _drawCloud(Canvas canvas, Offset center, Color color) {
  final fill = Paint()..color = color;
  final ink = Paint()
    ..color = playfulInk
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;
  final path = Path()
    ..moveTo(center.dx - 18, center.dy + 5)
    ..cubicTo(
      center.dx - 24,
      center.dy - 5,
      center.dx - 12,
      center.dy - 13,
      center.dx - 5,
      center.dy - 7,
    )
    ..cubicTo(
      center.dx,
      center.dy - 19,
      center.dx + 14,
      center.dy - 16,
      center.dx + 14,
      center.dy - 6,
    )
    ..cubicTo(
      center.dx + 27,
      center.dy - 6,
      center.dx + 27,
      center.dy + 8,
      center.dx + 16,
      center.dy + 8,
    )
    ..lineTo(center.dx - 14, center.dy + 8)
    ..close();
  canvas.drawPath(path, fill);
  canvas.drawPath(path, ink);
}
