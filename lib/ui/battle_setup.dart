import 'dart:math';

import 'package:flutter/material.dart';

import '../ai/ai_player.dart';
import '../core/models.dart';
import '../game/board_art.dart';
import '../services/ads_service.dart';
import '../l10n.dart';

/// Choices made before a battle starts.
class BattleSetup {
  final AiLevel? level;
  final List<Commander?> commanders;
  final bool fog;

  /// The player asked to watch an ad for extra starting gold.
  final bool bonusGold;
  const BattleSetup({
    required this.level,
    required this.commanders,
    required this.fog,
    this.bonusGold = false,
  });

  static const bonusAmount = 300;

  /// [map] with this setup's commanders and fog applied, and [bonusAmount]
  /// extra gold for blue when [goldEarned].
  Map<String, dynamic> applyTo(
    Map<String, dynamic> map, {
    bool goldEarned = false,
  }) {
    final funds = ((map['funds'] as List?)?.cast<int>() ?? [0, 0]).toList();
    if (goldEarned) funds[0] += bonusAmount;
    return {
      ...map,
      'fog': fog,
      'commanders': [for (final c in commanders) c?.name],
      'funds': funds,
    };
  }

  /// Plays the bonus-gold ad when it was asked for, then applies the setup.
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> map) async {
    final earned = bonusGold && await AdsService.instance.showRewarded();
    return applyTo(map, goldEarned: earned);
  }
}

/// Asks for difficulty, commanders and fog. Against the computer the enemy
/// commander is picked at random. Returns null if dismissed.
Future<BattleSetup?> showBattleSetup(
  BuildContext context, {
  required bool vsComputer,
  bool chooseLevel = true,
  bool chooseFog = true,
}) {
  var level = AiLevel.normal;
  final picks = <Commander>[Commander.warden, Commander.bold];
  var fog = false;
  var bonusGold = false;
  return showModalBottomSheet<BattleSetup>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setState) {
        Widget commanderRow(int player, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Color.lerp(playerColors[player], Colors.white, 0.45),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in Commander.values)
                  ChoiceChip(
                    label: Text(c.shortName),
                    selected: picks[player] == c,
                    onSelected: (_) => setState(() => picks[player] = c),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${picks[player].powerName}: ${picks[player].powerText}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
          ],
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Prepare for battle', 'Chuẩn bị xuất trận'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (vsComputer && chooseLevel) ...[
                  Text(tr('Enemy skill', 'Sức mạnh của địch')),
                  const SizedBox(height: 6),
                  SegmentedButton<AiLevel>(
                    segments: [
                      for (final l in AiLevel.values)
                        ButtonSegment(value: l, label: Text(levelName(l))),
                    ],
                    selected: {level},
                    onSelectionChanged: (s) => setState(() => level = s.first),
                  ),
                  const SizedBox(height: 16),
                ],
                commanderRow(
                  0,
                  vsComputer
                      ? tr('Your commander', 'Tướng của bạn')
                      : tr('Blue commander', 'Tướng phe Xanh'),
                ),
                if (!vsComputer)
                  commanderRow(1, tr('Red commander', 'Tướng phe Đỏ')),
                if (chooseFog)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Fog of war', 'Sương mù chiến tranh')),
                    subtitle: Text(
                      tr(
                        'See only what your units can see.',
                        'Chỉ thấy những gì quân mình nhìn thấy.',
                      ),
                    ),
                    value: fog,
                    onChanged: (v) => setState(() => fog = v),
                  ),
                // Only offered when an ad is actually ready to play.
                if (vsComputer &&
                    chooseFog &&
                    AdsService.instance.rewardedReady.value)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr(
                        'Start with +${BattleSetup.bonusAmount} gold',
                        'Khởi đầu thêm ${BattleSetup.bonusAmount} vàng',
                      ),
                    ),
                    subtitle: Text(
                      tr(
                        'Watch a short ad before the battle.',
                        'Xem một quảng cáo ngắn trước trận.',
                      ),
                    ),
                    value: bonusGold,
                    onChanged: (v) => setState(() => bonusGold = v),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheet).pop(
                      BattleSetup(
                        level: vsComputer ? level : null,
                        commanders: [
                          picks[0],
                          vsComputer
                              ? Commander.values[Random().nextInt(
                                  Commander.values.length,
                                )]
                              : picks[1],
                        ],
                        fog: fog,
                        bonusGold: bonusGold,
                      ),
                    ),
                    child: Text(tr('To battle!', 'Xuất trận!')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
