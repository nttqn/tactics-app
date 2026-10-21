import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../campaign/daily.dart';
import '../campaign/progress.dart';
import '../core/map_generator.dart';
import '../services/ads_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import 'achievements_screen.dart';
import 'battle_setup.dart';
import 'campaign_screen.dart';
import 'daily_screen.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'my_maps_screen.dart';
import 'theme.dart';
import 'title_backdrop.dart';
import '../l10n.dart';

/// Mode select: continue a saved match, campaign, a one-off battle against
/// the computer on a random map, two players on one device, and extras.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<SavedMatch?> _saved = SaveService.load();
  Future<DailyRecord> _daily = DailyRecord.load();
  BannerAd? _banner;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    // The ads SDK starts up in the background; ask for a banner once it is
    // ready, which may already be the case.
    AdsService.instance.ready.addListener(_loadBanner);
    _loadBanner();
  }

  void _loadBanner() {
    if (_banner != null || !AdsService.instance.ready.value) return;
    _banner = AdsService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _bannerLoaded = true);
      },
    );
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_loadBanner);
    _banner?.dispose();
    super.dispose();
  }

  /// Opens [screen] and refreshes the Continue button when it closes.
  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    SoundService.instance.playMenuMusic();
    setState(() {
      _saved = SaveService.load();
      _daily = DailyRecord.load();
    });
  }

  Future<void> _randomBattle({required bool vsComputer}) async {
    final setup = await showBattleSetup(context, vsComputer: vsComputer);
    if (setup == null || !mounted) return;
    final map = await setup.prepare(
      generateMap(MapSpec(seed: Random().nextInt(1 << 20))),
    );
    if (!mounted) return;
    _open(
      GameScreen(
        mapJson: map,
        aiLevel: setup.level,
        label: vsComputer
            ? tr('Skirmish', 'Giao tranh')
            : tr('2 players', '2 người chơi'),
      ),
    );
  }

  Future<void> _startDaily(DailyRecord record) async {
    final challenge = DailyChallenge.today();
    if (!await showDailyBriefing(context, record, challenge) || !mounted) {
      return;
    }
    _open(dailyScreen(record, challenge));
  }

  Future<void> _continue(SavedMatch saved) async {
    if (saved.daily != null) {
      final record = await DailyRecord.load();
      if (!mounted) return;
      _open(
        dailyScreen(
          record,
          DailyChallenge.fromKey(saved.daily!),
          resume: saved,
        ),
      );
    } else if (saved.mission != null) {
      final progress = await Progress.load();
      if (!mounted) return;
      _open(missionScreen(progress, saved.mission!, resume: saved));
    } else {
      _open(
        GameScreen(
          mapJson: saved.setup,
          aiLevel: saved.level,
          resumeFrom: saved.state,
          label: saved.label,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget option(
      String label,
      VoidCallback onPressed, {
      bool primary = false,
      String? subtitle,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 260,
        height: subtitle == null ? 52 : 62,
        child: (primary ? FilledButton.new : OutlinedButton.new)(
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ClipRect(child: TitleBackdrop()),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'MARCHLORDS',
                          style: TextStyle(
                            fontFamily: titleFont,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: gold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(height: 3, color: goldDark),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton.icon(
                        onPressed: L10n.toggle,
                        icon: const Icon(Icons.translate, size: 18),
                        // Names the language the button switches to.
                        label: Text(L10n.vi ? 'English' : 'Tiếng Việt'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder(
                      future: _saved,
                      builder: (context, snapshot) {
                        final saved = snapshot.data;
                        if (saved == null) return const SizedBox.shrink();
                        return option(
                          tr('Continue', 'Chơi tiếp'),
                          () => _continue(saved),
                          primary: true,
                          subtitle:
                              '${saved.label} · ${tr('day', 'ngày')} ${saved.state.turn}',
                        );
                      },
                    ),
                    option(
                      tr('Campaign', 'Chiến dịch'),
                      () => _open(const CampaignScreen()),
                    ),
                    FutureBuilder(
                      future: _daily,
                      builder: (context, snapshot) {
                        final record = snapshot.data;
                        if (record == null) return const SizedBox.shrink();
                        final best = record.best(DailyChallenge.today().key);
                        final streak = record.streak(DateTime.now());
                        return option(
                          tr('Daily challenge', 'Thử thách hằng ngày'),
                          () => _startDaily(record),
                          subtitle: best == null
                              ? (streak > 0
                                    ? tr(
                                        'New battle today · streak $streak',
                                        'Trận mới hôm nay · chuỗi $streak',
                                      )
                                    : tr(
                                        'A new battle every day',
                                        'Mỗi ngày một trận mới',
                                      ))
                              : tr(
                                  'Won in $best days · streak $streak',
                                  'Thắng trong $best ngày · chuỗi $streak',
                                ),
                        );
                      },
                    ),
                    option(
                      tr('Skirmish', 'Giao tranh'),
                      () => _randomBattle(vsComputer: true),
                    ),
                    option(
                      tr('2 players, one device', '2 người, chung một máy'),
                      () => _randomBattle(vsComputer: false),
                    ),
                    option(
                      tr('Map editor', 'Tạo bản đồ'),
                      () => _open(const MyMapsScreen()),
                    ),
                    option(
                      tr('Achievements', 'Thành tích'),
                      () => _open(const AchievementsScreen()),
                    ),
                    option(
                      tr('How to play', 'Cách chơi'),
                      () => _open(const HowToPlayScreen()),
                    ),
                  ],
                ),
              ),
            ),
            if (_bannerLoaded && _banner != null)
              SizedBox(
                width: _banner!.size.width.toDouble(),
                height: _banner!.size.height.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
          ],
        ),
      ),
    );
  }
}
