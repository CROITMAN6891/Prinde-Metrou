import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../game/game_controller.dart';
import '../../game/game_state.dart';
import '../../game/progress_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../theme/metro_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/collision_overlay.dart';
import '../widgets/language_switcher.dart';
import '../widgets/metro_grid.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/tier_choice_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.localeController,
    required this.progressStore,
  });

  final LocaleController localeController;
  final ProgressStore progressStore;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameState _gameState;
  late final GameController _gameController;
  late final AnimationController _collisionController;

  CollisionMessageKind? _collisionMessage;

  @override
  void initState() {
    super.initState();
    _gameState = GameState(tier: widget.progressStore.tier);
    _gameController = GameController(
      _gameState,
      progressStore: widget.progressStore,
    );
    _collisionController = AnimationController(
      vsync: this,
      duration: GameConstants.collisionAnimationDuration,
    );
    _gameState.addListener(_onGameStateChanged);
    WidgetsBinding.instance.addObserver(this);
    _gameController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause on any loss of foreground. Coming back (resumed) deliberately
    // does NOT unpause: the player taps the pause overlay when ready.
    if (state != AppLifecycleState.resumed) {
      _gameController.pause();
    }
  }

  void _onGameStateChanged() {
    if (_gameState.phase == GamePhase.colliding && _collisionMessage == null) {
      _playCollisionSequence();
    }
  }

  Future<void> _playCollisionSequence() async {
    setState(() => _collisionMessage = CollisionMessageKind.ouch);
    await _collisionController.forward(from: 0);
    if (!mounted) return;
    await _delayRespectingPause(GameConstants.ouchMessageDuration);
    if (!mounted) return;
    setState(() => _collisionMessage = CollisionMessageKind.newChance);
    await _delayRespectingPause(GameConstants.newChanceMessageDuration);
    if (!mounted) return;
    setState(() => _collisionMessage = null);
    _collisionController.reset();
    _gameController.resumeAfterCollision();
  }

  /// Waits [duration], then holds for as long as the game is paused, so a
  /// timed sequence never advances while the app is in the background.
  Future<void> _delayRespectingPause(Duration duration) async {
    await Future<void>.delayed(duration);
    await _gameController.waitUntilResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameState.removeListener(_onGameStateChanged);
    _gameController.dispose();
    _collisionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // balances the switcher's width
                  AnimatedBuilder(
                    animation: _gameState,
                    builder: (context, _) => Text(
                      l10n.scoreLabel(_gameState.score),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: MetroTheme.scoreText,
                      ),
                    ),
                  ),
                  LanguageSwitcher(localeController: widget.localeController),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _gameState,
              builder: (context, _) => _StationPlaque(
                label: '${l10n.stationLabel} · '
                    '${_gameState.tier.label(l10n).toUpperCase()}',
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanEnd: _gameController.onSwipeEnd,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: MetroGrid(
                        gameState: _gameState,
                        collisionAnimation: _collisionController,
                      ),
                    ),
                    CollisionOverlay(kind: _collisionMessage),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _gameState,
                        builder: (context, _) => TierChoiceOverlay(
                          visible:
                              _gameState.phase == GamePhase.choosingTier,
                          score: _gameState.score,
                          tier: _gameState.tier,
                          onChoose: _gameController.chooseTier,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _gameState,
                        builder: (context, _) => PauseOverlay(
                          visible: _gameState.isPaused,
                          onResume: _gameController.resume,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}

class _StationPlaque extends StatelessWidget {
  const _StationPlaque({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: MetroTheme.wagonColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: MetroTheme.background,
          ),
        ),
      ),
    );
  }
}
