import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class BranchAlertService {
  static final AudioPlayer _player = AudioPlayer();
  static var _playing = false;

  static Future<void> playNewOrderAlert() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1);
      await _player.play(AssetSource('sounds/new_order.wav'));
      await _player.onPlayerComplete.first.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } catch (_) {
      await _fallbackAlert();
    } finally {
      _playing = false;
    }
  }

  static Future<void> _fallbackAlert() async {
    if (kIsWeb) return;
    final repeats = defaultTargetPlatform == TargetPlatform.windows ? 4 : 2;
    for (var i = 0; i < repeats; i++) {
      await SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
  }
}
