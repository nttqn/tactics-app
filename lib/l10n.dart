import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_player.dart';
import 'core/models.dart';

enum AppLanguage { en, vi }

/// The game's two languages. Strings are written in place with [tr], so
/// each English text sits next to its Vietnamese one.
class L10n {
  L10n._();

  static const _key = 'language';

  /// Follows the device language until the player picks one.
  static final ValueNotifier<AppLanguage> language = ValueNotifier(
    PlatformDispatcher.instance.locale.languageCode == 'vi'
        ? AppLanguage.vi
        : AppLanguage.en,
  );

  static bool get vi => language.value == AppLanguage.vi;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) language.value = AppLanguage.values.byName(saved);
  }

  static Future<void> toggle() async {
    language.value = vi ? AppLanguage.en : AppLanguage.vi;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.value.name);
  }
}

/// [en] or [vi], whichever language is active.
String tr(String en, String vi) => L10n.vi ? vi : en;

String playerName(int player) =>
    tr(['Blue', 'Red'][player], ['Xanh', 'Đỏ'][player]);

String levelName(AiLevel level) => switch (level) {
  AiLevel.easy => tr('Easy', 'Dễ'),
  AiLevel.normal => tr('Normal', 'Thường'),
  AiLevel.hard => tr('Hard', 'Khó'),
};

extension LocalizedUnit on UnitType {
  String get label => switch (this) {
    UnitType.infantry => tr('Infantry', 'Bộ binh'),
    UnitType.spearman => tr('Spearman', 'Lính giáo'),
    UnitType.archer => tr('Archer', 'Cung thủ'),
    UnitType.knight => tr('Knight', 'Kỵ sĩ'),
    UnitType.catapult => tr('Catapult', 'Máy bắn đá'),
    UnitType.griffin => tr('Griffin', 'Sư thứu'),
    UnitType.monk => tr('Monk', 'Tu sĩ'),
  };
}

extension LocalizedTerrain on Terrain {
  String get label => switch (this) {
    Terrain.plain => tr('Grass', 'Đồng cỏ'),
    Terrain.forest => tr('Forest', 'Rừng'),
    Terrain.mountain => tr('Mountain', 'Núi'),
    Terrain.water => tr('Water', 'Sông'),
    Terrain.bridge => tr('Bridge', 'Cầu'),
    Terrain.city => tr('Village', 'Làng'),
    Terrain.barracks => tr('Tent', 'Lều trại'),
    Terrain.hq => tr('Castle', 'Lâu đài'),
  };
}

extension LocalizedCommander on Commander {
  /// Given name only, e.g. "Aldric".
  String get shortName => title.split(' ').first;

  /// Full name with epithet, e.g. "Aldric the Warden".
  String get displayName => switch (this) {
    Commander.warden => tr(title, 'Aldric Hộ Vệ'),
    Commander.bold => tr(title, 'Brenna Dũng Mãnh'),
    Commander.swift => tr(title, 'Corvin Thần Tốc'),
  };

  String get powerName => switch (this) {
    Commander.warden => tr(power, 'Hiệu Triệu'),
    Commander.bold => tr(power, 'Cuồng Nộ'),
    Commander.swift => tr(power, 'Thần Hành'),
  };

  String get powerText => switch (this) {
    Commander.warden => tr(description, 'Toàn quân hồi 3 HP.'),
    Commander.bold => tr(
      description,
      'Quân của bạn gây thêm 30% sát thương trong lượt này.',
    ),
    Commander.swift => tr(
      description,
      'Quân của bạn đi xa thêm 2 ô trong lượt này.',
    ),
  };
}
