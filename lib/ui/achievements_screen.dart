import 'package:flutter/material.dart';

import '../services/achievements.dart';
import '../l10n.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _loaded = AchievementService.instance.load();

  @override
  Widget build(BuildContext context) {
    final unlocked = AchievementService.instance.unlocked;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Achievements', 'Thành tích'))),
      body: FutureBuilder(
        future: _loaded,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tr(
                    '${unlocked.length} / ${achievements.length} earned',
                    'Đã đạt ${unlocked.length} / ${achievements.length}',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              for (final a in achievements)
                Card(
                  child: ListTile(
                    leading: Icon(
                      unlocked.contains(a.id)
                          ? Icons.emoji_events
                          : Icons.lock_outline,
                      color: unlocked.contains(a.id)
                          ? const Color(0xFFFFD54F)
                          : null,
                    ),
                    title: Text(a.name),
                    subtitle: Text(a.text),
                    enabled: unlocked.contains(a.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
