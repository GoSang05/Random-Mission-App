import 'package:flutter/material.dart';

class DoitLogo extends StatelessWidget {
  const DoitLogo({this.fontSize = 28, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'DOIT',
      style: TextStyle(
        color: const Color(0xFF17151D),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
      ),
    );
  }
}
