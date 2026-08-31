import 'package:flutter/material.dart';

import 'playful_illustrations.dart';
import 'playful_ui.dart';

Future<bool> confirmSignOut(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierColor: Colors.black45,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PlayfulPanel(
              color: playfulCream,
              radius: 28,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Doodle(
                        kind: DoodleKind.star,
                        color: playfulLime,
                        size: 34,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '로그아웃할까요?',
                          style: TextStyle(
                            color: playfulInk,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '이 기기에서 현재 계정의 로그인이 해제돼요.',
                    style: TextStyle(color: Color(0xFF5D5865), height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('cancelSignOutButton'),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: playfulInk,
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: playfulInk,
                              width: 2.5,
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('confirmSignOutButton'),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA5B9),
                            foregroundColor: playfulInk,
                            side: const BorderSide(
                              color: playfulInk,
                              width: 2.5,
                            ),
                          ),
                          child: const Text('로그아웃'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}
