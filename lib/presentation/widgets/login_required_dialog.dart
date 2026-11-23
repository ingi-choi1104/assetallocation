import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 로그인이 필요한 기능에서 띄우는 안내.
///
/// 포트폴리오 공유는 로그인한 사용자만 만들고 볼 수 있다. 여기서 바로
/// 로그인시키지 않고 설정으로 보내는 이유는, Google 로그인 흐름과 그
/// 오류 처리가 설정 화면에 이미 한 번 구현돼 있어서다 — 같은 흐름을
/// 화면마다 복제하면 한쪽만 고쳐지는 문제가 생긴다.
///
/// [what]은 '공유하려면', '공유받은 포트폴리오를 보려면'처럼
/// "~ 로그인이 필요합니다" 앞에 붙는 말이다.
Future<void> showLoginRequiredDialog(
  BuildContext context, {
  required String what,
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그인이 필요합니다'),
        content: Text(
          '$what 로그인이 필요합니다.\n\n'
          '설정에서 Google 계정으로 로그인한 뒤 다시 시도해주세요.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              // 다이얼로그 context는 pop 뒤에 쓸 수 없으므로 호출자 context로
              // 이동한다.
              Navigator.pop(ctx);
              context.push('/settings');
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
