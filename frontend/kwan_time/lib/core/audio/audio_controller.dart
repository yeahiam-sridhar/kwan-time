import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';
import 'ambient_state_machine.dart';
import 'audio_gatekeeper.dart';

class AudioController {
  AudioController._();

  static final AudioController instance = AudioController._();

  AudioPlayer? _ambientPlayer;
  AudioPlayer? _reminderPlayer;
  AudioPlayer? _sfxPlayer;
  StreamSubscription<ProcessingState>? _ambientSub;

  bool _ambientStarting = false;

  double _sfxVol = 0.8;
  double _ambientVol = 0.12;
  final List<String> _playlist = <String>[];
  int _trackIndex = 0;
  String? _customMusicPath;

  final AmbientStateMachine _asm = AmbientStateMachine.instance;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        unawaited(
            AudioGatekeeper.instance.process(GatekeeperEvent.audioInterrupt));
        return;
      }
      if (event.type != AudioInterruptionType.unknown) {
        unawaited(
            AudioGatekeeper.instance.process(GatekeeperEvent.audioResume));
      }
    });

    session.becomingNoisyEventStream.listen((_) {
      unawaited(
          AudioGatekeeper.instance.process(GatekeeperEvent.audioInterrupt));
    });

    await _loadPrefs();
    await _loadPlaylist();
  }

  Future<void> startAmbient() async {
    if (_ambientStarting) {
      return;
    }
    if (!_asm.canStart && !_asm.canPlay) {
      debugPrint('AudioController.startAmbient: state blocked');
      return;
    }

    _ambientStarting = true;
    try {
      await _cleanAmbient();

      final track = _nextTrack();
      final player = AudioPlayer();
      _ambientPlayer = player;

      if (track.startsWith('file:')) {
        await player.setFilePath(track.substring(5));
      } else {
        await player.setAsset('assets/sounds/$track.mp3');
      }
      await player.setVolume(_ambientVol.clamp(0.01, 0.3));
      final shouldLoopSingleTrack = _playlist.isEmpty;
      await player
          .setLoopMode(shouldLoopSingleTrack ? LoopMode.one : LoopMode.off);

      if (!_asm.canStart && !_asm.canPlay) {
        await player.dispose();
        _ambientPlayer = null;
        debugPrint(
            'AudioController.startAmbient: state changed during load, aborted');
        return;
      }

      await player.play();
      _asm.transition(AmbientState.playing);

      await _ambientSub?.cancel();
      _ambientSub = player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed &&
            _ambientPlayer == player &&
            _asm.canPlay) {
          unawaited(startAmbient());
        }
      });

      debugPrint('Ambient: $track');
    } catch (e) {
      debugPrint('startAmbient error: $e');
      _ambientPlayer = null;
    } finally {
      _ambientStarting = false;
    }
  }

  Future<void> pauseAmbient() async {
    if (_ambientPlayer == null) {
      return;
    }
    for (double v = _ambientVol; v > 0.01; v -= 0.025) {
      try {
        await _ambientPlayer?.setVolume(v.clamp(0.0, 0.3));
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await _ambientPlayer?.pause();
  }

  Future<void> resumeAmbient() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_ambientPlayer == null) {
      await startAmbient();
      return;
    }
    try {
      await _ambientPlayer?.play();
      for (double v = 0.01; v < _ambientVol; v += 0.02) {
        try {
          await _ambientPlayer?.setVolume(v.clamp(0.0, 0.3));
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await _ambientPlayer?.setVolume(_ambientVol.clamp(0.0, 0.3));
    } catch (_) {
      await startAmbient();
    }
  }

  Future<void> stopAmbient() async {
    await _cleanAmbient();
    _asm.forceStop();
  }

  Future<void> _cleanAmbient() async {
    await _ambientSub?.cancel();
    _ambientSub = null;
    final player = _ambientPlayer;
    _ambientPlayer = null;
    try {
      await player?.stop();
    } catch (_) {}
    try {
      await player?.dispose();
    } catch (_) {}
  }

  Future<void> playReminder(String eventId) async {
    final current = _reminderPlayer;
    _reminderPlayer = null;
    try {
      await current?.stop();
      await current?.dispose();
    } catch (_) {}

    try {
      final player = AudioPlayer();
      _reminderPlayer = player;
      await player.setAsset('assets/sounds/reminder_chime.mp3');
      await player.setVolume(_sfxVol.clamp(0.1, 1.0));
      await player.setLoopMode(LoopMode.one);
      await player.play();
      debugPrint('Reminder playing for event=$eventId');
    } catch (e) {
      debugPrint('playReminder error: $e');
    }
  }

  Future<void> stopReminder() async {
    final player = _reminderPlayer;
    _reminderPlayer = null;
    try {
      await player?.stop();
      await player?.dispose();
    } catch (_) {}
  }

  Future<void> playSfx(String key) async {
    AudioPlayer? player;
    try {
      await _sfxPlayer?.dispose();
      _sfxPlayer = null;
      player = AudioPlayer();
      _sfxPlayer = player;
      await player.setAsset('assets/sounds/$key.mp3');
      await player.setVolume(_sfxVol.clamp(0.01, 1.0));
      await player.play();
      await Future.any<void>(<Future<void>>[
        player.processingStateStream
            .firstWhere((state) => state == ProcessingState.completed)
            .then((_) {}),
        Future<void>.delayed(const Duration(seconds: 5)),
      ]);
    } catch (e) {
      debugPrint('SFX error [$key]: $e');
    } finally {
      if (_sfxPlayer == player) {
        _sfxPlayer = null;
      }
      try {
        await player?.dispose();
      } catch (_) {}
    }
  }

  Future<void> stopAll() async {
    await stopAmbient();
    await stopReminder();
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.dispose();
    } catch (_) {}
    _sfxPlayer = null;
    debugPrint('AudioController: all audio stopped');
  }

  bool get isAnyAudioPlaying =>
      (_ambientPlayer?.playing ?? false) || (_reminderPlayer?.playing ?? false);

  Future<void> setAmbientVolume(double value) async {
    _ambientVol = (value * 0.3).clamp(0.0, 0.3);
    try {
      await _ambientPlayer?.setVolume(_ambientVol);
    } catch (_) {}
    _saveAsync('ambient_volume', _ambientVol.toString());
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVol = value.clamp(0.0, 1.0);
    _saveAsync('sfx_volume', _sfxVol.toString());
  }

  Future<void> addTrack(String path) async {
    _playlist.add(path);
    await _savePlaylist();
  }

  Future<void> setCustomMusicPath(String absolutePath) async {
    if (!File(absolutePath).existsSync()) {
      debugPrint('AudioController.setCustomMusicPath: file not found');
      return;
    }
    _customMusicPath = absolutePath;
    _saveAsync('custom_music_path', absolutePath);
    debugPrint('AudioController custom music set: $absolutePath');
  }

  Future<void> removeTrack(int index) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }
    _playlist.removeAt(index);
    if (_trackIndex >= _playlist.length) {
      _trackIndex = 0;
    }
    await _savePlaylist();
  }

  List<String> get playlist => List.unmodifiable(_playlist);

  String _nextTrack() {
    final customPath = _customMusicPath;
    if (customPath != null && customPath.isNotEmpty) {
      if (File(customPath).existsSync()) {
        return 'file:$customPath';
      }
      _customMusicPath = null;
      _saveAsync('custom_music_path', '');
    }

    if (_playlist.isEmpty) {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 10) {
        return 'morning_bells';
      }
      if (hour >= 10 && hour < 17) {
        return 'focus_hum';
      }
      if (hour >= 17 && hour < 22) {
        return 'evening_calm';
      }
      return 'deep_night';
    }
    final track = _playlist[_trackIndex % _playlist.length];
    _trackIndex = (_trackIndex + 1) % _playlist.length;
    _saveAsync('music_playlist_index', _trackIndex.toString());
    return 'file:$track';
  }

  Future<void> _loadPrefs() async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query('app_settings');
      for (final row in rows) {
        final key = row['key']?.toString();
        final value = row['value']?.toString();
        if (key == null || value == null) {
          continue;
        }
        switch (key) {
          case 'sfx_volume':
            _sfxVol = double.tryParse(value) ?? 0.8;
            break;
          case 'ambient_volume':
            _ambientVol = double.tryParse(value) ?? 0.12;
            break;
          case 'music_playlist_index':
            _trackIndex = int.tryParse(value) ?? 0;
            break;
          case 'custom_music_path':
            if (value.trim().isNotEmpty && File(value.trim()).existsSync()) {
              _customMusicPath = value.trim();
            }
            break;
        }
      }
    } catch (e) {
      debugPrint('Prefs load error: $e');
    }
  }

  Future<void> _loadPlaylist() async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: <Object?>['music_playlist'],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      _playlist
        ..clear()
        ..addAll(List<String>.from(jsonDecode(rows.first['value'] as String)));
    } catch (e) {
      debugPrint('Playlist load error: $e');
    }
  }

  Future<void> _savePlaylist() async {
    _saveAsync('music_playlist', jsonEncode(_playlist));
    _saveAsync('music_playlist_index', _trackIndex.toString());
  }

  void _saveAsync(String key, String value) {
    unawaited(() async {
      try {
        final db = await DbHelper.instance.database;
        await db.insert(
          'app_settings',
          <String, Object?>{'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }());
  }
}
