import 'package:flutter/material.dart';

import '../campaign/campaign.dart';
import '../campaign/progress.dart';
import '../core/models.dart';
import '../services/achievements.dart';
import '../services/save_service.dart';
import 'battle_setup.dart';
import 'game_screen.dart';

/// The screen for campaign mission [index], led by [commander], or
/// continuing [resume].
Widget missionScreen(
  Progress progress,
  int index, {
  Commander? commander,
  SavedMatch? resume,
}) {
  final mission = campaign[index];
  return GameScreen(
    key: ValueKey(index),
    mapJson: resume?.setup ?? missionSetup(index, commander),
    resumeFrom: resume?.state,
    aiLevel: mission.level,
    tutorial: index == 0,
    missionIndex: index,
    label: 'Mission ${index + 1} · ${mission.name}',
    onPlayerWin: (days) async {
      await progress.recordWin(index, days);
      AchievementService.instance.unlock([
        if (progress.completed >= 10) 'halfway',
        if (progress.completed >= campaign.length) 'champion',
        if (progress.totalStars == 3 * campaign.length) 'flawless',
      ]);
    },
    nextBuilder: index + 1 < campaign.length
        ? (_) => missionScreen(
            progress,
            index + 1,
            commander:
                commander ??
                (resume?.state.commanders.first) ??
                Commander.warden,
          )
        : null,
  );
}

/// Mission list. Missions unlock one at a time as the previous one is won.
class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final _progress = Progress.load();

  Future<void> _start(Progress progress, int index) async {
    Commander? commander;
    if (missionHasCommanders(index)) {
      final setup = await showBattleSetup(
        context,
        vsComputer: true,
        chooseLevel: false,
        chooseFog: false,
      );
      if (setup == null || !mounted) return;
      commander = setup.commanders.first;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => missionScreen(progress, index, commander: commander),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign')),
      body: FutureBuilder(
        future: _progress,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: progress,
            builder: (context, _) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: campaign.length + 1,
              itemBuilder: (context, i) => i == 0
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '★ ${progress.totalStars} / ${3 * campaign.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFFFFD54F),
                        ),
                      ),
                    )
                  : _tile(progress, i - 1),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(Progress progress, int index) {
    final unlocked = progress.isUnlocked(index);
    final best = progress.bestDays(index);
    final stars = best == null ? 0 : starsFor(index, best);
    final traits = [
      if (missionHasFog(index)) 'Fog',
      if (enemyCommander(index) != null)
        'vs ${enemyCommander(index)!.title.split(' ').first}',
    ].join(' · ');
    return Card(
      child: ListTile(
        enabled: unlocked,
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(campaign[index].name),
        subtitle: Text(
          [
            !unlocked
                ? 'Locked'
                : best == null
                ? 'Par ${parDays(index)} days'
                : 'Best $best days · par ${parDays(index)}',
            if (traits.isNotEmpty) traits,
          ].join('\n'),
        ),
        isThreeLine: traits.isNotEmpty,
        trailing: unlocked
            ? Text(
                '★' * stars + '☆' * (3 - stars),
                style: const TextStyle(fontSize: 18, color: Color(0xFFFFD54F)),
              )
            : const Icon(Icons.lock),
        onTap: () => _start(progress, index),
      ),
    );
  }
}
