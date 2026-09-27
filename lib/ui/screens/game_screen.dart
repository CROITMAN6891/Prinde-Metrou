import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../game/game_controller.dart';
import '../../game/game_state.dart';
import '../../game/progress_store.dart';
import '../../game/progression.dart';
import '../../game/train_skin.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../theme/metro_theme.dart';
import '../widgets/ad_banner.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/collision_overlay.dart';
import '../widgets/language_switcher.dart';
import '../widgets/metro_grid.dart';
import '../widgets/pause_overlay.dart';
import '../widgets/skin_picker.dart';
import '../widgets/tier_choice_overlay.dart';
import '../widgets/tier_picker.dart';

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
  Celebration? _celebration;
  bool _celebrationUnlockedSkin = false;
  late TrainSkin _skin;
  int _celebrationGeneration = 0;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _skin = widget.progressStore.skin;
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
    if (_gameState.score > _lastScore) {
      final unlocked = widget.progressStore.recordScore(_gameState.score);
      // A milestone outranks the station bonus that reached it.
      final celebration =
          celebrationFor(_gameState.score) ??
          (_gameState.lastGainWasBonus ? Celebration.bonus : null);
      if (celebration != null) {
        _showCelebration(celebration, unlockedSkin: unlocked.isNotEmpty);
      }
    }
    _lastScore = _gameState.score;

    if (_gameState.phase == GamePhase.colliding && _collisionMessage == null) {
      _playCollisionSequence();
    }
  }

  Future<void> _showCelebration(
    Celebration celebration, {
    required bool unlockedSkin,
  }) async {
    final generation = ++_celebrationGeneration;
    setState(() {
      _celebration = celebration;
      _celebrationUnlockedSkin = unlockedSkin;
    });
    await _delayRespectingPause(GameConstants.celebrationMessageDuration);
    // A newer celebration (or a collision) may have replaced this one.
    if (!mounted || generation != _celebrationGeneration) return;
    setState(() => _celebration = null);
  }

  Future<void> _playCollisionSequence() async {
    _celebrationGeneration++;
    setState(() {
      _celebration = null;
      _collisionMessage = CollisionMessageKind.ouch;
    });
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

  Future<void> _openSkinPicker() async {
    _gameController.pause();
    final chosen = await SkinPicker.show(
      context,
      selected: _skin,
      bestScore: widget.progressStore.bestScore,
    );
    if (!mounted || chosen == null) return;
    setState(() => _skin = chosen);
    widget.progressStore.saveSkin(chosen);
  }

  /// Leaves the game paused afterwards, like the skin picker, so the player
  /// resumes on their own at the new speed.
  Future<void> _openTierPicker() async {
    _gameController.pause();
    final chosen = await TierPicker.show(
      context,
      selected: _gameState.tier,
      unlocked: widget.progressStore.unlockedTier,
    );
    if (!mounted || chosen == null) return;
    _gameController.selectTier(chosen);
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.skinPickerTitle,
                        icon: const Icon(Icons.palette_outlined),
                        color: MetroTheme.wagonColor,
                        onPressed: _openSkinPicker,
                      ),
                      AnimatedBuilder(
                        animation: _gameState,
                        builder: (context, _) => IconButton(
                          tooltip: l10n.tierPickerTitle,
                          icon: const Icon(Icons.speed),
                          color: MetroTheme.wagonColor,
                          // The milestone box is already a speed choice.
                          onPressed:
                              _gameState.phase == GamePhase.choosingTier
                              ? null
                              : _openTierPicker,
                        ),
                      ),
                    ],
                  ),
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
                label:
                    '${l10n.stationLabel} · '
                    '${_gameState.tier.label(l10n).toUpperCase()}',
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _gameController.onSwipeStart,
                onPanUpdate: _gameController.onSwipeUpdate,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: MetroGrid(
                        gameState: _gameState,
                        collisionAnimation: _collisionController,
                        skin: _skin,
                        stationLabel: l10n.stationLabel,
                        portalLabel: l10n.portalLabel,
                      ),
                    ),
                    CollisionOverlay(kind: _collisionMessage),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _gameState,
                        builder: (context, _) => TierChoiceOverlay(
                          visible: _gameState.phase == GamePhase.choosingTier,
                          score: _gameState.score,
                          tier: _gameState.tier,
                          onChoose: _gameController.chooseTier,
                        ),
                      ),
                    ),
                    // Above the tier choice, so the milestone banner shows over
                    // its dimmed backdrop instead of under it.
                    Positioned.fill(
                      child: CelebrationOverlay(
                        celebration: _celebration,
                        unlockedSkin: _celebrationUnlockedSkin,
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
