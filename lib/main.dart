import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'services/ads_service.dart';
import 'services/play_games.dart';
import 'services/settings.dart';
import 'services/sound_service.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The board and HUD are laid out for a tall screen.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Not awaited: a slow or broken audio asset must never delay the first frame.
  SoundService.instance.init();
  SoundService.instance.playMenuMusic();
  AdsService.instance.initialize();
  Settings.load();
  L10n.load();
  PlayGames.start();
  runApp(const TacticsApp());
}

class TacticsApp extends StatelessWidget {
  const TacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // A language switch rebuilds the whole app (the key resets it to the
    // home screen, which is where the switch lives).
    return ValueListenableBuilder(
      valueListenable: L10n.language,
      builder: (context, language, _) => MaterialApp(
        key: ValueKey(language),
        title: 'Marchlords',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
