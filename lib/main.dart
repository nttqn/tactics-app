import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads_service.dart';
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
  runApp(const TacticsApp());
}

class TacticsApp extends StatelessWidget {
  const TacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marchlords',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
