import 'package:flutter/material.dart';

import '../campaign/campaign.dart';
import '../campaign/progress.dart';
import '../core/map_generator.dart';
import 'game_screen.dart';

Widget _missionScreen(Progress progress, int index) {
  final mission = campaign[index];
  return GameScreen(
    key: ValueKey(index),
    mapJson: generateMap(mission.spec),
    aiLevel: mission.level,
    onPlayerWin: (days) => progress.recordWin(index, days),
    nextBuilder: index + 1 < campaign.length
        ? (_) => _missionScreen(progress, index + 1)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F2A),
      appBar: AppBar(
        title: const Text('Campaign'),
        backgroundColor: const Color(0xFF1B1F2A),
      ),
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
              itemCount: campaign.length,
              itemBuilder: (context, i) => _tile(context, progress, i),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Progress progress, int index) {
    final unlocked = progress.isUnlocked(index);
    final best = progress.bestDays(index);
    return Card(
      child: ListTile(
        enabled: unlocked,
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(campaign[index].name),
        subtitle: Text(
          !unlocked
              ? 'Locked'
              : best == null
              ? 'Not yet won'
              : 'Won in $best days',
        ),
        trailing: Icon(
          !unlocked
              ? Icons.lock
              : best == null
              ? Icons.play_arrow
              : Icons.check_circle,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _missionScreen(progress, index),
          ),
        ),
      ),
    );
  }
}
