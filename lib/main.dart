import 'package:flutter/material.dart';

import 'services/sound_service.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Not awaited: a slow or broken audio asset must never delay the first frame.
  SoundService.instance.init();
  SoundService.instance.playMenuMusic();
  runApp(const TacticsApp());
}

class TacticsApp extends StatelessWidget {
  const TacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tactics',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
