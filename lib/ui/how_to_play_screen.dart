import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/models.dart';
import '../l10n.dart';
import 'art_icon.dart';

/// Rules reference. Unit and terrain numbers are read from the game data,
/// so this page cannot drift from the actual rules.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static List<String> get _basics => [
    tr(
      'Blue moves first, then Red. On your turn every unit may move once and '
          'then attack, capture or wait.',
      'Phe Xanh đi trước, rồi tới phe Đỏ. Trong lượt của mình, mỗi quân được '
          'di chuyển một lần rồi tấn công, chiếm đóng hoặc chờ.',
    ),
    tr(
      'Tap a unit to select it, tap a blue tile to move, then choose an '
          'action. Undo takes back actions until you end your turn.',
      'Chạm một quân để chọn, chạm ô xanh để di chuyển, rồi chọn hành động. '
          'Hoàn tác rút lại các nước đi cho tới khi hết lượt.',
    ),
    tr(
      'You win by capturing the enemy castle or by defeating every enemy unit.',
      'Bạn thắng khi chiếm được lâu đài địch hoặc tiêu diệt toàn bộ quân địch.',
    ),
    tr(
      'Every building you own pays ${GameState.incomePerBuilding}g at the '
          'start of your turn and heals your unit standing on it.',
      'Mỗi công trình bạn sở hữu nộp ${GameState.incomePerBuilding} vàng đầu '
          'lượt và hồi máu cho quân của bạn đứng trên đó.',
    ),
    tr(
      'Infantry and spearmen capture buildings. A healthy unit needs two '
          'turns; leaving the tile starts over.',
      'Bộ binh và lính giáo chiếm được công trình. Quân đầy máu cần hai lượt; '
          'rời khỏi ô thì phải chiếm lại từ đầu.',
    ),
    tr(
      'Recruit new units at your tent. They can act from your next turn.',
      'Chiêu mộ quân mới tại lều trại. Quân mới hành động được từ lượt sau.',
    ),
    tr(
      'A wounded unit hits more weakly. The defender strikes back if the '
          'attacker is within its range.',
      'Quân bị thương đánh yếu hơn. Quân bị đánh sẽ phản đòn nếu kẻ tấn công '
          'nằm trong tầm của nó.',
    ),
    tr(
      'Monks cannot fight; they restore 3 HP to an ally beside them.',
      'Tu sĩ không đánh được; họ hồi 3 máu cho đồng đội đứng cạnh.',
    ),
    tr(
      'A unit that defeats an enemy gains a rank, up to three. Each rank adds '
          '10% damage.',
      'Quân hạ được địch sẽ lên một cấp, tối đa ba cấp. Mỗi cấp thêm 10% '
          'sát thương.',
    ),
    tr(
      'Fighting fills your commander\'s meter. When it is full, tap the '
          'commander badge or the power button to unleash it once.',
      'Giao tranh làm đầy thanh năng lượng của tướng. Khi đầy, chạm biểu '
          'tượng tướng hoặc nút kỹ năng để tung chiêu một lần.',
    ),
    tr(
      'Under fog of war you only see what your units and buildings see. '
          'Hidden enemies cannot be targeted, and walking into one ends the '
          'move in an ambush. Undo under fog costs a short ad.',
      'Khi có sương mù, bạn chỉ thấy những gì quân và công trình của mình '
          'nhìn thấy. Không thể đánh quân địch đang ẩn, và đi trúng chúng là '
          'bị phục kích. Hoàn tác khi có sương mù cần xem một quảng cáo ngắn.',
    ),
    tr(
      'During the computer\'s turn, the Speed button plays it at x2 or x4.',
      'Trong lượt của máy, nút Tốc độ cho chạy nhanh x2 hoặc x4.',
    ),
    tr(
      'Stuck? Watch a short ad for a hint: the move a strong commander '
          'would make is marked in gold.',
      'Bí nước? Xem một quảng cáo ngắn để nhận gợi ý: nước đi của một vị '
          'tướng giỏi được đánh dấu màu vàng.',
    ),
    tr(
      'The daily challenge is the same battle for every player that day. '
          'Win it every day to build a streak.',
      'Thử thách hằng ngày là cùng một trận cho mọi người chơi trong ngày. '
          'Thắng mỗi ngày để giữ chuỗi thắng.',
    ),
    tr(
      'Your current battle is saved after every move; pick it up again with '
          'Continue on the main menu.',
      'Trận đang chơi được lưu sau mỗi nước đi; chơi tiếp bằng nút Chơi tiếp '
          'ở màn hình chính.',
    ),
  ];

  /// The two unit types [type] damages most, as a readable list.
  static String _strongAgainst(UnitType type) {
    final ranked = UnitType.values.toList()
      ..sort((a, b) => type.baseDamage(b).compareTo(type.baseDamage(a)));
    return ranked.take(2).map((t) => t.label).join(', ');
  }

  static String _unitNotes(UnitType type) => [
    tr('Cost ${type.cost}g', 'Giá ${type.cost} vàng'),
    tr('Move ${type.move}', 'Đi ${type.move}'),
    type.minRange == type.maxRange
        ? tr('Range ${type.maxRange}', 'Tầm ${type.maxRange}')
        : tr(
            'Range ${type.minRange}-${type.maxRange}',
            'Tầm ${type.minRange}-${type.maxRange}',
          ),
    tr('Sight ${type.vision}', 'Tầm nhìn ${type.vision}'),
    if (type.canCapture) tr('captures', 'chiếm được công trình'),
    if (type.canHeal) tr('heals allies', 'hồi máu đồng đội'),
    if (type.moveClass == MoveClass.flying)
      tr('flies over anything', 'bay qua mọi địa hình'),
    if (type.siege)
      tr(
        'cannot move and attack, never strikes back',
        'không thể vừa đi vừa bắn, không phản đòn',
      ),
  ].join(' · ');

  static String _terrainNotes(Terrain t) {
    String cost(int? c) => c == null ? tr('blocked', 'không qua được') : '$c';
    return [
      tr('Defense ${t.defense * 10}%', 'Phòng thủ ${t.defense * 10}%'),
      tr('On foot ${cost(t.footCost)}', 'Đi bộ ${cost(t.footCost)}'),
      tr('Mounted ${cost(t.mountedCost)}', 'Cưỡi ngựa ${cost(t.mountedCost)}'),
      if (t.isBuilding) tr('can be captured', 'chiếm được'),
      if (t == Terrain.barracks) tr('recruits units', 'chiêu mộ quân'),
      if (t == Terrain.hq) tr('lose it and you lose', 'mất nó là thua'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleLarge;
    return Scaffold(
      appBar: AppBar(title: Text(tr('How to play', 'Cách chơi'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in _basics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(line),
            ),
          const SizedBox(height: 8),
          Text(tr('Units', 'Các loại quân'), style: heading),
          for (final type in UnitType.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UnitIcon(type, size: 44),
              title: Text(type.label),
              // A unit that cannot attack has no "best against" line.
              subtitle: Text(
                type.canAttack
                    ? '${_unitNotes(type)}\n'
                          '${tr('Best against', 'Khắc chế')}: '
                          '${_strongAgainst(type)}'
                    : _unitNotes(type),
              ),
              isThreeLine: true,
            ),
          const SizedBox(height: 8),
          Text(tr('Commanders', 'Các vị tướng'), style: heading),
          for (final commander in Commander.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(commander.shortName[0])),
              title: Text(commander.displayName),
              subtitle: Text('${commander.powerName}: ${commander.powerText}'),
            ),
          const SizedBox(height: 8),
          Text(tr('Terrain', 'Địa hình'), style: heading),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              tr(
                'Defense reduces damage taken by a unit standing there; '
                    'flying units get none. Numbers are movement points to '
                    'enter.',
                'Phòng thủ giảm sát thương cho quân đứng trên ô đó; quân bay '
                    'không được hưởng. Các con số là điểm di chuyển để đi vào ô.',
              ),
            ),
          ),
          for (final t in Terrain.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: TerrainIcon(t, owner: 0, size: 44),
              title: Text(t.label),
              subtitle: Text(_terrainNotes(t)),
            ),
        ],
      ),
    );
  }
}
