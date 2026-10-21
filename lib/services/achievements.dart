import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String viTitle;
  final String viDescription;
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.viTitle,
    this.viDescription,
  );

  String get name => tr(title, viTitle);
  String get text => tr(description, viDescription);
}

const achievements = [
  Achievement(
    'first_blood',
    'First Blood',
    'Defeat an enemy unit.',
    'Giọt Máu Đầu',
    'Hạ một quân địch.',
  ),
  Achievement(
    'castle',
    'Castle Stormer',
    'Win by capturing the enemy castle.',
    'Phá Thành',
    'Thắng bằng cách chiếm lâu đài địch.',
  ),
  Achievement(
    'total_war',
    'Total War',
    'Win by defeating every enemy unit.',
    'Tận Diệt',
    'Thắng bằng cách tiêu diệt mọi quân địch.',
  ),
  Achievement(
    'landlord',
    'Landlord',
    'Hold 8 buildings at once.',
    'Địa Chủ',
    'Giữ 8 công trình cùng lúc.',
  ),
  Achievement(
    'veteran',
    'Veteran',
    'Raise a unit to the third rank.',
    'Lão Binh',
    'Đưa một quân lên cấp ba.',
  ),
  Achievement(
    'medic',
    'Field Medic',
    'Heal an ally with a monk.',
    'Quân Y',
    'Dùng tu sĩ hồi máu cho đồng đội.',
  ),
  Achievement(
    'unleashed',
    'Unleashed',
    'Use a commander power.',
    'Tung Chiêu',
    'Dùng kỹ năng của tướng.',
  ),
  Achievement(
    'blitz',
    'Blitz',
    'Win a battle by day 8.',
    'Chớp Nhoáng',
    'Thắng một trận trước ngày thứ 8.',
  ),
  Achievement(
    'mist',
    'Through the Mist',
    'Win a battle under fog of war.',
    'Xuyên Sương Mù',
    'Thắng một trận có sương mù chiến tranh.',
  ),
  Achievement(
    'tactician',
    'Tactician',
    'Beat the Hard computer outside the campaign.',
    'Nhà Chiến Thuật',
    'Thắng máy mức Khó ngoài chiến dịch.',
  ),
  Achievement(
    'cartographer',
    'Cartographer',
    'Win a battle on a map you made.',
    'Người Vẽ Bản Đồ',
    'Thắng một trận trên bản đồ do bạn tạo.',
  ),
  Achievement(
    'halfway',
    'Half the Realm',
    'Win campaign mission 10.',
    'Nửa Vương Quốc',
    'Thắng màn 10 của chiến dịch.',
  ),
  Achievement(
    'devoted',
    'Devoted',
    'Win the daily challenge seven days in a row.',
    'Bền Bỉ',
    'Thắng thử thách hằng ngày bảy ngày liên tiếp.',
  ),
  Achievement(
    'champion',
    'Champion',
    'Win the whole campaign.',
    'Nhà Vô Địch',
    'Hoàn thành toàn bộ chiến dịch.',
  ),
  Achievement(
    'flawless',
    'Flawless General',
    'Earn three stars on every mission.',
    'Danh Tướng',
    'Đạt ba sao ở mọi màn.',
  ),
];

/// Unlocked achievements, saved on the device. Screens listen to
/// [justUnlocked] to announce new ones.
class AchievementService {
  AchievementService._();
  static final instance = AchievementService._();

  static const _key = 'achievements';

  final Set<String> unlocked = {};

  /// The most recent batch of newly unlocked achievements.
  final ValueNotifier<List<Achievement>> justUnlocked = ValueNotifier(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    unlocked
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
  }

  /// Marks [ids] as earned; announces and returns the ones that are new.
  Future<List<Achievement>> unlock(Iterable<String> ids) async {
    final fresh = [
      for (final a in achievements)
        if (ids.contains(a.id) && !unlocked.contains(a.id)) a,
    ];
    if (fresh.isEmpty) return fresh;
    unlocked.addAll(fresh.map((a) => a.id));
    justUnlocked.value = fresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, unlocked.toList());
    return fresh;
  }
}
