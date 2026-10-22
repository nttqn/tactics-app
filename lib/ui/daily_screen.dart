import 'package:flutter/material.dart';

import '../campaign/daily.dart';
import '../services/achievements.dart';
import '../services/save_service.dart';
import 'game_screen.dart';
import '../l10n.dart';

/// The battle for [challenge], or [resume] of one left unfinished.
Widget dailyScreen(
  DailyRecord record,
  DailyChallenge challenge, {
  SavedMatch? resume,
}) => GameScreen(
  mapJson: resume?.setup ?? challenge.setup(),
  resumeFrom: resume?.state,
  aiLevel: challenge.level,
  dailyKey: challenge.key,
  label: '${tr('Daily challenge', 'Thử thách hằng ngày')} · ${challenge.key}',
  onPlayerWin: (days) async {
    await record.recordWin(challenge.key, days);
    if (record.streak(DailyChallenge.pacificToday()) >= 7) {
      AchievementService.instance.unlock(['devoted']);
    }
  },
);

/// Today's rules and the player's record; returns true to start the battle.
Future<bool> showDailyBriefing(
  BuildContext context,
  DailyRecord record,
  DailyChallenge challenge,
) async {
  final best = record.best(challenge.key);
  final streak = record.streak(DailyChallenge.pacificToday());
  final spec = challenge.spec;
  final lines = [
    tr(
          'Map: ${spec.width} x ${spec.height}',
          'Bản đồ: ${spec.width} x ${spec.height}',
        ) +
        (spec.bridges > 0
            ? tr(
                ', river with ${spec.bridges} bridges',
                ', sông có ${spec.bridges} cầu',
              )
            : ''),
    tr(
      'Enemy: ${levelName(challenge.level)} computer led by '
          '${challenge.enemyCommander.displayName}',
      'Địch: máy mức ${levelName(challenge.level)}, tướng '
          '${challenge.enemyCommander.displayName}',
    ),
    tr(
      'You lead as ${challenge.playerCommander.displayName}',
      'Bạn làm tướng ${challenge.playerCommander.displayName}',
    ),
    if (challenge.fog) tr('Fog of war', 'Sương mù chiến tranh'),
    best == null
        ? tr('Not won yet today', 'Hôm nay chưa thắng')
        : tr('Your best today: $best days', 'Tốt nhất hôm nay: $best ngày'),
    tr(
      'Win streak: $streak ${streak == 1 ? 'day' : 'days'}',
      'Chuỗi thắng: $streak ngày',
    ),
  ];
  final start = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(tr('Daily challenge', 'Thử thách hằng ngày')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'The same battle for every player today. Win it on as few days '
                  'as you can, and come back tomorrow to keep your streak.',
              'Hôm nay mọi người chơi cùng một trận. Hãy thắng trong ít ngày '
                  'nhất có thể, và quay lại ngày mai để giữ chuỗi thắng.',
            ),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $line'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(tr('Not now', 'Để sau')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(tr('To battle!', 'Xuất trận!')),
        ),
      ],
    ),
  );
  return start ?? false;
}
