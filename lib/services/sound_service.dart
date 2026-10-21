import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { attack, defeat, win, click, back }

/// Music + one-shot effects via `flame_audio`.
///
/// Music: `m_title.mp3` loops on every menu screen; each match picks one of
/// `m_ig1..6.mp3` at random; `m_win.mp3` plays once on a victory (as an
/// effect, so it isn't cut off by the music being stopped).
///
/// `init()` is fired unawaited from `main()` (never awaited before
/// `runApp()`): a broken asset can leave `AudioPool` creation hanging on
/// web, which would otherwise block the first frame. Every call here is a
/// safe no-op if loading hasn't finished or the sound is switched off.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _musicKey = 'music_enabled';
  static const _sfxKey = 'sfx_enabled';

  static const menuTrack = 'm_title.mp3';
  static const gameTracks = [
    'm_ig1.mp3',
    'm_ig2.mp3',
    'm_ig3.mp3',
    'm_ig4.mp3',
    'm_ig5.mp3',
    'm_ig6.mp3',
  ];

  static const Map<SoundEffect, String> _files = {
    SoundEffect.attack: 'sfx_attack.mp3',
    SoundEffect.defeat: 'sfx_explosive.wav',
    SoundEffect.win: 'm_win.mp3',
    SoundEffect.click: 'sfx_menu_confirm.wav',
    SoundEffect.back: 'sfx_menu_back.wav',
  };

  final ValueNotifier<bool> musicEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> sfxEnabled = ValueNotifier<bool>(true);
  final Map<SoundEffect, AudioPool> _pools = {};
  final _rng = math.Random();
  bool _bgmReady = false;

  /// The track that *should* be playing (null = silence), even while music
  /// is switched off or still loading, so toggling music back on, or init
  /// finishing late, starts the right thing.
  String? _wanted;

  /// What bgm is actually playing right now.
  String? _playing;

  /// No audio focus on Android: by default every player requests focus,
  /// and the one losing it (the music) is paused each time an effect plays.
  /// Ambient on iOS mixes with other apps the same way.
  static final _audioContext = AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(_audioContext);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    musicEnabled.value = prefs.getBool(_musicKey) ?? true;
    sfxEnabled.value = prefs.getBool(_sfxKey) ?? true;
    try {
      // Also makes bgm pause/resume with the app going to background.
      // Passed explicitly too: the bgm player has its own fallback context
      // and may be created before the global one above is in place.
      await FlameAudio.bgm.initialize(audioContext: _audioContext);
      _bgmReady = true;
      await FlameAudio.audioCache
          .loadAll([menuTrack, ...gameTracks])
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    for (final entry in _files.entries) {
      try {
        _pools[entry.key] = await FlameAudio.createPool(
          entry.value,
          minPlayers: 1,
          maxPlayers: 3,
          audioContext: _audioContext,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // That one effect just stays silent.
      }
    }
    // A screen may have asked for music before loading finished.
    _apply(restart: true);
  }

  void play(SoundEffect effect) {
    if (!sfxEnabled.value) return;
    _pools[effect]?.start(volume: effect == SoundEffect.win ? 0.8 : 1.0);
  }

  /// Menu screens call this; it keeps an already-playing title loop going
  /// instead of restarting it on every screen change.
  void playMenuMusic() {
    _wanted = menuTrack;
    _apply(restart: false);
  }

  /// Starts a random battle track from the beginning.
  void startGameMusic() {
    _wanted = gameTracks[_rng.nextInt(gameTracks.length)];
    _apply(restart: true);
  }

  void _apply({required bool restart}) {
    if (!_bgmReady) return;
    final target = musicEnabled.value ? _wanted : null;
    if (target == _playing && !restart) return;
    try {
      if (target == null) {
        FlameAudio.bgm.stop();
      } else {
        FlameAudio.bgm.play(target, volume: 0.55);
      }
      _playing = target;
    } catch (_) {}
  }

  Future<void> toggleMusic() async {
    musicEnabled.value = !musicEnabled.value;
    _apply(restart: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, musicEnabled.value);
  }

  Future<void> toggleSfx() async {
    sfxEnabled.value = !sfxEnabled.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxKey, sfxEnabled.value);
  }
}
