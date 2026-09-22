import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../game/game_controller.dart';
import '../../game/game_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../theme/metro_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/collision_overlay.dart';
import '../widgets/language_switcher.dart';
import '../widgets/metro_grid.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameState _gameState;
  late final GameController _gameController;
  late final AnimationController _collisionController;

  CollisionMessageKind? _collisionMessage;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _gameController = GameController(_gameState);
    _collisionController = AnimationController(
      vsync: this,
      duration: GameConstants.collisionAnimationDuration,
    );
    _gameState.addListener(_onGameStateChanged);
    _gameController.start();
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
    await Future<void>.delayed(GameConstants.ouchMessageDuration);
    if (!mounted) return;
    setState(() => _collisionMessage = CollisionMessageKind.newChance);
    await Future<void>.delayed(GameConstants.newChanceMessageDuration);
    if (!mounted) return;
    setState(() => _collisionMessage = null);
    _collisionController.reset();
    _gameController.resumeAfterCollision();
  }

  @override
  void dispose() {
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
            _StationPlaque(label: l10n.stationLabel),
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
