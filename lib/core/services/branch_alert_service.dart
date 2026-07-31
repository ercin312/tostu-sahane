import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class BranchAlertService {
  static final AudioPlayer _player = AudioPlayer();
  static var _busy = false;

  static Future<void> playNewOrderAlert() async {
    await _playOnce('sounds/new_order.wav');
  }

  /// Garson çağır / hesap — ses döngüsü; [stopAlert] ile kesilir.
  static Future<void> playWaiterCallAlert() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1);
      await _player.play(AssetSource('sounds/new_order.wav'));
    } catch (_) {
      unawaited(_fallbackAlert(repeats: 6));
    }
  }

  static Future<void> stopAlert() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    _busy = false;
  }

  static Future<void> _playOnce(String asset) async {
    if (_busy) return;
    _busy = true;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1);
      await _player.play(AssetSource(asset));
      await _player.onPlayerComplete.first.timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } catch (_) {
      await _fallbackAlert();
    } finally {
      _busy = false;
    }
  }

  static Future<void> _fallbackAlert({int repeats = 4}) async {
    if (kIsWeb) return;
    final n = defaultTargetPlatform == TargetPlatform.windows ? repeats : 2;
    for (var i = 0; i < n; i++) {
      await SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
  }
}
