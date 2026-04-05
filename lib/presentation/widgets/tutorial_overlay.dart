import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

const _kTutorialShownKey = 'tutorial_shown_v1';

// ═══════════════════════════════════════════════════════════════════════════════
// Public types
// ═══════════════════════════════════════════════════════════════════════════════

class TutorialTargetKeys {
  final GlobalKey fab;
  final GlobalKey cameraBtn;
  final GlobalKey syncBtn;
  final GlobalKey sortBtn;
  final GlobalKey backupSection; // 설정 탭 백업 섹션

  const TutorialTargetKeys({
    required this.fab,
    required this.cameraBtn,
    required this.syncBtn,
    required this.sortBtn,
    required this.backupSection,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Step model
// ═══════════════════════════════════════════════════════════════════════════════

class _Step {
  final String? targetId;
  final String emoji;
  final String title;
  final String body;
  final int tab;                     // 0=포트폴리오, 1=설정
  final bool showBundleAnimation;    // 번들 애니메이션 스텝
  final bool showStaticAnimation;    // 정적 포트폴리오 리밸런싱 애니메이션
  final bool showDynamicAnimation;   // 동적 포트폴리오 신호 계산 애니메이션

  const _Step({
    this.targetId,
    required this.emoji,
    required this.title,
    required this.body,
    this.tab = 0,
    this.showBundleAnimation = false,
    this.showStaticAnimation = false,
    this.showDynamicAnimation = false,
  });
}

const _steps = [
  _Step(
    emoji: '🌿',
    title: '자산배분 헬퍼',
    body: '포트폴리오를 한눈에 관리하고\n목표 비중에 맞게 리밸런싱해요!\n\n주요 기능들을 하나씩 소개할게요 😊',
  ),
  _Step(
    targetId: 'fab',
    emoji: '➕',
    title: '포트폴리오 추가',
    body: '버튼을 누르면 두 가지 유형 중\n하나를 선택할 수 있어요!\n📊 정적  |  📈 동적',
  ),
  _Step(
    emoji: '📊',
    title: '정적 포트폴리오',
    body: '목표 비중을 직접 설정하면\n리밸런싱 코드를 자동 계산!\n얼마를 사고팔지 앱이 알려줘요 💡',
    showStaticAnimation: true,
  ),
  _Step(
    emoji: '📈',
    title: '동적 포트폴리오',
    body: 'VAA·PAA·GTAA 등 전략이\n매달 최적 비중을 자동 산출!\n복잡한 계산은 앱이 대신해요 ✨',
    showDynamicAnimation: true,
  ),
  _Step(
    targetId: 'camera',
    emoji: '📸',
    title: '스냅샷 기록',
    body: '지금 포트폴리오 상태를\n사진 찍듯 저장해둬요!\n나중에 그때 자산 현황을\n다시 확인할 수 있어요 🗓',
  ),
  _Step(
    targetId: 'sync',
    emoji: '🔄',
    title: '가격 동기화',
    body: '탭 한 번으로 최신 시세 즉시 반영!\n앱 실행하면 자동 갱신되고\n백그라운드에서 5분마다\n계속 업데이트돼요 ⚡',
  ),
  _Step(
    targetId: 'sort',
    emoji: '📋',
    title: '순서 편집',
    body: '포트폴리오 카드 순서를\n드래그해서 맘대로 바꿀 수 있어요!\n자주 보는 걸 위로 올려두면\n더 편리하게 쓸 수 있어요 👆',
  ),
  _Step(
    emoji: '🗂',
    title: '번들로 묶기',
    body: '카드를 길게 눌러서\n다른 카드 위에 드롭하면\n여러 포트폴리오를 묶을 수 있어요!\n아래 애니메이션처럼 해보세요 👇',
    showBundleAnimation: true,
  ),
  _Step(
    targetId: 'backup',
    emoji: '💾',
    title: '데이터 백업 & 복원',
    body: '여기서 데이터를 JSON 파일로\n내보내거나 복원할 수 있어요!\n기기 교체 전에 꼭 백업해두세요 🛡',
    tab: 1,
  ),
  _Step(
    emoji: '🎯',
    title: '준비 완료!',
    body: '이제 시작해볼까요? 💪\n\n설정 탭 → "사용법 안내 다시 보기"로\n언제든 이 안내를 다시 볼 수 있어요!\n\n현명한 자산배분 응원할게요 🌿',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// SharedPreferences
// ═══════════════════════════════════════════════════════════════════════════════

Future<bool> checkShouldShowTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kTutorialShownKey) ?? false);
}

Future<void> markTutorialShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTutorialShownKey, true);
}

Future<void> resetTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kTutorialShownKey);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Public entry point
// ═══════════════════════════════════════════════════════════════════════════════

/// [onTabSwitch] : 스텝 변경 시 앱 탭 전환 요청 콜백 (0=포트폴리오, 1=설정)
void showTutorialOverlay(
  BuildContext context,
  TutorialTargetKeys keys, {
  void Function(int tab)? onTabSwitch,
}) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: _TutorialOverlayWidget(
        keys: keys,
        onTabSwitch: onTabSwitch,
        onDismiss: () => entry.remove(),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main overlay widget
// ═══════════════════════════════════════════════════════════════════════════════

class _TutorialOverlayWidget extends StatefulWidget {
  final TutorialTargetKeys keys;
  final void Function(int tab)? onTabSwitch;
  final VoidCallback onDismiss;

  const _TutorialOverlayWidget({
    required this.keys,
    required this.onTabSwitch,
    required this.onDismiss,
  });

  @override
  State<_TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<_TutorialOverlayWidget> {
  bool _visible = false;
  bool _dismissing = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _goToStep(int newStep) {
    setState(() => _step = newStep);
    // 스텝에 맞는 탭으로 전환
    widget.onTabSwitch?.call(_steps[newStep].tab);
  }

  Rect? _spotlight() {
    final id = _steps[_step].targetId;
    if (id == null) return null;

    GlobalKey? key;
    switch (id) {
      case 'fab':    key = widget.keys.fab;
      case 'camera': key = widget.keys.cameraBtn;
      case 'sync':   key = widget.keys.syncBtn;
      case 'sort':   key = widget.keys.sortBtn;
      case 'backup': key = widget.keys.backupSection;
    }

    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height)
        .inflate(10);
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await markTutorialShown();
    if (!mounted) return;
    setState(() => _visible = false);
    await Future.delayed(const Duration(milliseconds: 320));
    widget.onDismiss();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      _goToStep(_step + 1);
    } else {
      _dismiss();
    }
  }

  void _prev() {
    if (_step > 0) _goToStep(_step - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = _steps[_step];
    final spotlight = _spotlight();

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ① 어두운 오버레이 + 스포트라이트 홀
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(spotlight: spotlight),
              ),
            ),

            // ② 설명 카드
            if (step.showBundleAnimation)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 128),
                    child: _BundleDemoCard(key: ValueKey(_step), step: step),
                  ),
                ),
              )
            else if (step.showStaticAnimation)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 128),
                    child: _StaticDemoCard(key: ValueKey(_step), step: step),
                  ),
                ),
              )
            else if (step.showDynamicAnimation)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 128),
                    child: _DynamicDemoCard(key: ValueKey(_step), step: step),
                  ),
                ),
              )
            else if (spotlight == null)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 128),
                    child: _CenteredCard(key: ValueKey(_step), step: step),
                  ),
                ),
              )
            else
              _buildPositionedCard(step, spotlight, size),

            // ③ 건너뛰기 버튼
            Positioned(
              top: 0,
              right: 8,
              child: SafeArea(
                child: TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: Text('건너뛰기',
                      style: GoogleFonts.jua(fontSize: 14)),
                ),
              ),
            ),

            // ④ 하단: 페이지 인디케이터 + 네비게이션
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageDots(count: _steps.length, current: _step),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            OutlinedButton.icon(
                              onPressed: _prev,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 18),
                              label: Text('이전',
                                  style: GoogleFonts.jua(fontSize: 14)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(80, 44),
                                side: const BorderSide(
                                    color: Colors.white54, width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                            const Spacer(),
                          ] else
                            const Spacer(),
                          FilledButton.icon(
                            onPressed: _next,
                            icon: _step < _steps.length - 1
                                ? const Icon(Icons.arrow_forward_rounded,
                                    size: 18)
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              _step < _steps.length - 1 ? '다음' : '시작하기',
                              style: GoogleFonts.jua(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(100, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 4,
                              shadowColor: AppColors.primaryLight
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionedCard(_Step step, Rect spotlight, Size size) {
    const cardW = 300.0;
    const arrowSize = 36.0;
    const gap = 8.0;

    final left = (spotlight.center.dx - cardW / 2)
        .clamp(12.0, size.width - cardW - 12.0);
    final isAbove = spotlight.center.dy > size.height * 0.5;

    if (isAbove) {
      return Positioned(
        key: ValueKey('card_$_step'),
        left: left,
        bottom: size.height - spotlight.top + gap,
        width: cardW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CompactCard(step: step),
            const SizedBox(height: 2),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryLight, size: arrowSize),
          ],
        ),
      );
    } else {
      return Positioned(
        key: ValueKey('card_$_step'),
        left: left,
        top: spotlight.bottom + gap,
        width: cardW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: AppColors.primaryLight, size: arrowSize),
            const SizedBox(height: 2),
            _CompactCard(step: step),
          ],
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Spotlight CustomPainter
// ═══════════════════════════════════════════════════════════════════════════════

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlight;
  static const double _r = 14.0;
  const _SpotlightPainter({this.spotlight});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    if (spotlight == null) {
      canvas.drawRect(
          full, Paint()..color = Colors.black.withValues(alpha: 0.82));
      return;
    }

    canvas.saveLayer(full, Paint());
    canvas.drawRect(
        full, Paint()..color = Colors.black.withValues(alpha: 0.82));
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight!, const Radius.circular(_r)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // 초록 glow 테두리
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          spotlight!.inflate(2.5), const Radius.circular(_r + 2.5)),
      Paint()
        ..color = AppColors.primaryLight.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotlight != spotlight;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Cards
// ═══════════════════════════════════════════════════════════════════════════════

TextStyle _bodyStyle({double fontSize = 14.5}) => GoogleFonts.jua(
      fontSize: fontSize,
      color: Colors.white.withValues(alpha: 0.92),
      height: 1.75,
      letterSpacing: 0.1,
    );

/// 스포트라이트 없는 스텝용 큰 중앙 카드
class _CenteredCard extends StatelessWidget {
  final _Step step;
  const _CenteredCard({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A5C38), Color(0xFF0D3D22)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 2),
              ),
              child: Center(
                  child:
                      Text(step.emoji, style: const TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nanumPenScript(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                height: 1.2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _DecorativeDivider(),
            ),
            Text(step.body, textAlign: TextAlign.center, style: _bodyStyle()),
          ],
        ),
      ),
    );
  }
}

/// 스포트라이트 스텝용 컴팩트 카드
class _CompactCard extends StatelessWidget {
  final _Step step;
  const _CompactCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D6640), Color(0xFF0D3D22)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child:
                      Text(step.emoji, style: const TextStyle(fontSize: 25))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.nanumPenScript(
                      fontSize: 21,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(step.body, style: _bodyStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 번들 애니메이션 스텝 카드
class _BundleDemoCard extends StatelessWidget {
  final _Step step;
  const _BundleDemoCard({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A5C38), Color(0xFF0D3D22)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  step.title,
                  style: GoogleFonts.nanumPenScript(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _DecorativeDivider(),
            ),
            // 설명
            Text(step.body, textAlign: TextAlign.center, style: _bodyStyle()),
            const SizedBox(height: 20),
            // 번들 애니메이션
            const _BundleAnimationWidget(),
          ],
        ),
      ),
    );
  }
}

class _DecorativeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.3)
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.transparent
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 번들 합치기 애니메이션 (2초 루프)
// ═══════════════════════════════════════════════════════════════════════════════

const _kCardW = 104.0;
const _kCardH = 68.0;
const _kCardGap = 14.0;
const _kTotalW = _kCardW * 2 + _kCardGap;

class _BundleAnimationWidget extends StatefulWidget {
  const _BundleAnimationWidget();

  @override
  State<_BundleAnimationWidget> createState() =>
      _BundleAnimationWidgetState();
}

class _BundleAnimationWidgetState extends State<_BundleAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;

        // ── 카드 불투명도 ──────────────────────────────────────────────────
        // 0–50%: 불투명, 50–65%: 사라짐, 65–88%: 숨김, 88–100%: 나타남
        final double cardsAlpha = t < 0.50
            ? 1.0
            : t < 0.65
                ? 1.0 - (t - 0.50) / 0.15
                : t < 0.88
                    ? 0.0
                    : (t - 0.88) / 0.12;

        // ── 카드2 X 이동 ────────────────────────────────────────────────────
        // 0–22%: 원위치, 22–50%: 왼쪽으로 이동 (ease), 50%+: 리셋
        double card2DX;
        double card2Lift; // 위로 살짝 뜨는 효과
        if (t < 0.22) {
          // 가볍게 흔들려서 "드래그 가능"을 암시
          card2DX = 2.0 * sin(t * pi * 8);
          card2Lift = 0;
        } else if (t < 0.50) {
          final p = Curves.easeInOut.transform((t - 0.22) / 0.28);
          card2DX = -(_kCardW + _kCardGap) * p;
          // 이동 시 부드럽게 위로 떠오름 (중간 지점에서 최대)
          final liftP = t < 0.36
              ? (t - 0.22) / 0.14
              : 1.0 - (t - 0.36) / 0.14;
          card2Lift = 8.0 * liftP.clamp(0.0, 1.0);
        } else {
          card2DX = 0; // 숨겨진 동안 리셋
          card2Lift = 0;
        }

        // ── 번들 카드 ────────────────────────────────────────────────────────
        // 0–50%: 숨김, 50–65%: 나타남(탄성), 65–88%: 표시, 88–100%: 사라짐
        final double bundleAlpha = t < 0.50
            ? 0.0
            : t < 0.65
                ? (t - 0.50) / 0.15
                : t < 0.88
                    ? 1.0
                    : 1.0 - (t - 0.88) / 0.12;

        final double bundleScale = t < 0.50
            ? 0.82
            : t < 0.65
                ? 0.82 +
                    0.18 *
                        Curves.elasticOut
                            .transform(((t - 0.50) / 0.15).clamp(0.0, 1.0))
                            .clamp(0.0, 1.2)
                : 1.0;

        return SizedBox(
          width: _kTotalW,
          height: _kCardH + 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 카드 1 (왼쪽, 고정)
              Positioned(
                left: 0,
                top: 12,
                child: Opacity(
                  opacity: cardsAlpha.clamp(0.0, 1.0),
                  child: const _MiniPortfolioCard(
                    emoji: '📊',
                    label: '성장형',
                    color: Color(0xFF1A5C38),
                  ),
                ),
              ),
              // 카드 2 (오른쪽 → 왼쪽으로 이동)
              Positioned(
                left: _kCardW + _kCardGap + card2DX,
                top: 12 - card2Lift,
                child: Opacity(
                  opacity: cardsAlpha.clamp(0.0, 1.0),
                  child: const _MiniPortfolioCard(
                    emoji: '📈',
                    label: '안정형',
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
              // 번들 결과 카드
              Positioned(
                left: 0,
                top: 12,
                child: Opacity(
                  opacity: bundleAlpha.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: bundleScale,
                    alignment: Alignment.centerLeft,
                    child: const _MiniBundleCard(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniPortfolioCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  const _MiniPortfolioCard(
      {required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCardW,
      height: _kCardH,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.jua(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBundleCard extends StatelessWidget {
  const _MiniBundleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kTotalW,
      height: _kCardH,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5C38), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Text('🗂', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('번들',
                    style: GoogleFonts.jua(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400)),
                Text('2개 포트폴리오 묶음',
                    style: GoogleFonts.jua(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w400)),
              ],
            ),
            const Spacer(),
            Icon(Icons.check_circle_rounded,
                color: AppColors.primaryLight.withValues(alpha: 0.9), size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 정적 포트폴리오 — 리밸런싱 애니메이션
// ═══════════════════════════════════════════════════════════════════════════════

class _StaticDemoCard extends StatelessWidget {
  final _Step step;
  const _StaticDemoCard({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A5C38), Color(0xFF0D3D22)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(
                  step.title,
                  style: GoogleFonts.nanumPenScript(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _DecorativeDivider(),
            ),
            Text(step.body, textAlign: TextAlign.center, style: _bodyStyle()),
            const SizedBox(height: 18),
            const _RebalanceAnimationWidget(),
          ],
        ),
      ),
    );
  }
}

class _RebalanceAnimationWidget extends StatefulWidget {
  const _RebalanceAnimationWidget();

  @override
  State<_RebalanceAnimationWidget> createState() =>
      _RebalanceAnimationWidgetState();
}

class _RebalanceAnimationWidgetState extends State<_RebalanceAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;

        // 전체 페이드 아웃 (90~100%)
        final double alpha =
            t < 0.90 ? 1.0 : 1.0 - (t - 0.90) / 0.10;

        // 현재→목표 진행도 (0=현재, 1=목표)
        // 0~25%: 현재 상태 표시, 25~55%: 애니메이션, 55~100%: 목표 상태
        final double barP = t < 0.25
            ? 0.0
            : t < 0.55
                ? Curves.easeInOut.transform((t - 0.25) / 0.30)
                : 1.0;

        // "리밸런싱 완료!" 배지 (55~85%에 표시)
        final double badgeAlpha = t < 0.55
            ? 0.0
            : t < 0.65
                ? (t - 0.55) / 0.10
                : t < 0.88
                    ? 1.0
                    : 0.0;

        // [emoji, label, 현재비중, 목표비중, 색]
        const assets = [
          ('📈', '주식', 0.65, 0.40, Color(0xFF4DB6AC)),
          ('📋', '채권', 0.15, 0.40, Color(0xFFFFB74D)),
          ('🥇', '금',   0.20, 0.20, Color(0xFFFF8A65)),
        ];

        // 레이블: 현재 → 목표
        final phaseLabel = barP < 0.05
            ? '현재 비중'
            : barP > 0.95
                ? '목표 비중 달성'
                : '조정 중...';

        return Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('비중 현황',
                      style: GoogleFonts.jua(
                          color: Colors.white54, fontSize: 11)),
                  Text(phaseLabel,
                      style: GoogleFonts.jua(
                          color: barP > 0.05
                              ? AppColors.primaryLight
                              : Colors.white38,
                          fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              ...assets.map((a) {
                final (emoji, label, curr, tgt, color) = a;
                final frac = (curr + (tgt - curr) * barP).clamp(0.0, 1.0);
                final pct = (frac * 100).round();
                final diff = ((tgt - curr) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      SizedBox(
                          width: 24,
                          child: Text(label,
                              style: GoogleFonts.jua(
                                  color: Colors.white70, fontSize: 10))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 16,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 36,
                        child: Text('$pct%',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.jua(
                                color: Colors.white, fontSize: 11)),
                      ),
                      SizedBox(
                        width: 36,
                        child: barP > 0.05 && diff != 0
                            ? Text(
                                diff > 0 ? '+$diff%' : '$diff%',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.jua(
                                  color: diff > 0
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFFEF9A9A),
                                  fontSize: 10,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              Opacity(
                opacity: badgeAlpha.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.primaryLight, size: 14),
                      const SizedBox(width: 6),
                      Text('리밸런싱 완료!',
                          style: GoogleFonts.jua(
                              color: AppColors.primaryLight, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 동적 포트폴리오 — 전략 신호 계산 애니메이션
// ═══════════════════════════════════════════════════════════════════════════════

class _DynamicDemoCard extends StatelessWidget {
  final _Step step;
  const _DynamicDemoCard({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B4E), Color(0xFF0A1929)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
        border: Border.all(
            color: const Color(0xFF1565C0).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(
                  step.title,
                  style: GoogleFonts.nanumPenScript(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _DecorativeDivider(),
            ),
            Text(step.body, textAlign: TextAlign.center, style: _bodyStyle()),
            const SizedBox(height: 18),
            const _DynamicCalcAnimationWidget(),
          ],
        ),
      ),
    );
  }
}

class _DynamicCalcAnimationWidget extends StatefulWidget {
  const _DynamicCalcAnimationWidget();

  @override
  State<_DynamicCalcAnimationWidget> createState() =>
      _DynamicCalcAnimationWidgetState();
}

class _DynamicCalcAnimationWidgetState
    extends State<_DynamicCalcAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;

        // 전체 페이드 아웃 (88~100%)
        final double alpha =
            t < 0.88 ? 1.0 : 1.0 - (t - 0.88) / 0.12;

        // 각 티커가 나타나는 시점 (4개, 0.10~0.58 구간에 순서대로)
        // [ticker, 신호, 비중, appearT]
        const signals = [
          ('SPY', '매수', '50%', 0.10, Color(0xFF4CAF50)),
          ('QQQ', '매수', '50%', 0.25, Color(0xFF4CAF50)),
          ('TLT', '제외', '  -', 0.40, Color(0xFFEF5350)),
          ('GLD', '제외', '  -', 0.55, Color(0xFFEF5350)),
        ];

        // 결과 카드 (0.62~0.88 표시)
        final double resultAlpha = t < 0.62
            ? 0.0
            : t < 0.72
                ? (t - 0.62) / 0.10
                : t < 0.88
                    ? 1.0
                    : 0.0;

        // 결과 카드 scale (elasticOut)
        final double resultScale = t < 0.62
            ? 0.85
            : t < 0.72
                ? 0.85 +
                    0.15 *
                        Curves.elasticOut
                            .transform(((t - 0.62) / 0.10).clamp(0.0, 1.0))
                            .clamp(0.0, 1.2)
                : 1.0;

        return Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 전략 라벨
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.6)),
                    ),
                    child: Text('VAA 전략',
                        style: GoogleFonts.jua(
                            color: const Color(0xFF90CAF9), fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  Text('신호 계산 중...',
                      style: GoogleFonts.jua(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 10),
              // 티커 신호 rows
              ...signals.map((s) {
                final (ticker, signal, weight, appearT, color) = s;
                final rowAlpha =
                    ((t - appearT) / 0.10).clamp(0.0, 1.0);
                final isBuy = signal == '매수';
                return Opacity(
                  opacity: rowAlpha,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        Text(ticker,
                            style: GoogleFonts.jua(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w400)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(signal,
                              style: GoogleFonts.jua(
                                  color: color, fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 28,
                          child: Text(weight,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.jua(
                                  color: isBuy
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              // 최종 결과 카드
              Opacity(
                opacity: resultAlpha.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: resultScale,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('추천 배분 자동 계산 완료!',
                                style: GoogleFonts.jua(
                                    color: Colors.white, fontSize: 12)),
                            Text('SPY 50%  ·  QQQ 50%',
                                style: GoogleFonts.jua(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF81D4FA), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page dots
// ═══════════════════════════════════════════════════════════════════════════════

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryLight
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
