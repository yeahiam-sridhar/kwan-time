import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  double _volume = 1.0;
  double _ambientVolume = 0.15;
  String _profile = 'calm';
  bool _initialized = false;

  AudioPlayer? _ambientPlayer;
  StreamSubscription<ProcessingState>? _ambientStateSubscription;
  bool _ambientPlaying = false;
  bool _pausedForMic = false;
  double _volumeBeforeMic = 0.0;
  bool _reminderActive = false;
  String? _customMusicPath;

  final List<String> _customTracks = <String>[];
  int _trackIndex = 0;
  bool _playlistLoaded = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query('app_settings');
      for (final row in rows) {
        final key = row['key']?.toString() ?? '';
        final value = row['value']?.toString() ?? '';
        if (key == 'sound_volume') {
          _volume = double.tryParse(value) ?? 1.0;
        } else if (key == 'ambient_volume') {
          _ambientVolume = double.tryParse(value) ?? 0.15;
        } else if (key == 'sound_profile' && value.isNotEmpty) {
          _profile = value;
        } else if (key == 'custom_music_path' && value.trim().isNotEmpty) {
          final path = value.trim();
          if (File(path).existsSync()) {
            _customMusicPath = path;
          } else {
            debugPrint('[SoundService] custom music path missing: $path');
          }
        }
      }
      await _loadPlaylist();
      debugPrint('SoundService initialized profile=$_profile volume=$_volume');
    } catch (e) {
      debugPrint('SoundService initialize error: $e');
    } finally {
      _initialized = true;
    }
  }

  Future<void> play(String soundKey) async {
    if (_profile == 'silent') {
      return;
    }
    unawaited(_playSafe(soundKey));
  }

  Future<void> onReminderFired(String soundKey) async {
    if (_profile == 'silent') {
      return;
    }
    _reminderActive = true;
    try {
      await _playSafe(soundKey);
    } finally {
      _reminderActive = false;
    }
  }

  Future<void> playAsset(String assetPath) async {
    if (_profile == 'silent') {
      return;
    }
    unawaited(_playAssetSafe(assetPath));
  }

  Future<void> _playSafe(String soundKey) async {
    await _playAssetCandidatesSafe(<String>[
      'assets/sounds/$soundKey.mp3',
      'assets/sounds/event_start.mp3',
    ]);
  }

  Future<void> _playAssetSafe(String assetPath) async {
    await _playAssetCandidatesSafe(<String>[
      assetPath,
      'assets/sounds/event_start.mp3',
    ]);
  }

  Future<void> _playAssetCandidatesSafe(List<String> candidates) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer();
      await _setAssetWithFallback(player, candidates);
      await player.setVolume(_volume.clamp(0.0, 1.0));
      await player.play();
      await Future.any<void>(<Future<void>>[
        player.playerStateStream
            .firstWhere(
                (state) => state.processingState == ProcessingState.completed)
            .then((_) {}),
        Future<void>.delayed(const Duration(seconds: 4)),
      ]);
    } catch (e) {
      debugPrint('Sound play failed: $e');
    } finally {
      try {
        await player?.dispose();
      } catch (_) {}
    }
  }

  Future<void> startAmbient({String? assetPath, double volume = 0.15}) async {
    if (_profile == 'silent' || _profile == 'professional') {
      return;
    }
    if (_pausedForMic) {
      return;
    }

    _ambientVolume = volume.clamp(0.0, 1.0);
    await _loadPlaylist();

    final selectedTrack = _nextTrack(assetPath: assetPath);
    final fallbackAsset = _fallbackAmbientAsset();
    final hasPlaylist = _customTracks.isNotEmpty;

    try {
      final player = _ambientPlayer ??= AudioPlayer();
      await _ambientStateSubscription?.cancel();
      _ambientStateSubscription = null;
      await player.setLoopMode(hasPlaylist ? LoopMode.off : LoopMode.one);
      await _setAmbientSourceWithFallback(player, selectedTrack, fallbackAsset);
      await player.setVolume(_effectiveAmbientVolume);
      await player.play();
      _ambientPlaying = true;
      _pausedForMic = false;

      if (hasPlaylist) {
        _ambientStateSubscription =
            player.processingStateStream.listen((state) {
          if (state == ProcessingState.completed &&
              _ambientPlaying &&
              !_pausedForMic) {
            unawaited(
                startAmbient(assetPath: assetPath, volume: _ambientVolume));
          }
        });
      }
    } catch (e) {
      _ambientPlaying = false;
      debugPrint('Ambient start failed: $e');
    }
  }

  Future<void> playAmbient() async {
    await startAmbient(volume: _ambientVolume);
  }

  Future<void> stopAmbient() async {
    await _ambientStateSubscription?.cancel();
    _ambientStateSubscription = null;
    try {
      await _ambientPlayer?.stop();
    } catch (_) {}
    _ambientPlaying = false;
    _pausedForMic = false;
  }

  Future<void> pauseForMic() async {
    if (_ambientPlayer == null || !_ambientPlaying || _pausedForMic) {
      return;
    }
    try {
      _volumeBeforeMic = _effectiveAmbientVolume;
      for (double v = _volumeBeforeMic; v > 0.01; v -= 0.03) {
        await _ambientPlayer!.setVolume(v.clamp(0.0, 1.0));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await _ambientPlayer!.pause();
      _pausedForMic = true;
      debugPrint('Ambient paused for mic session');
    } catch (e) {
      debugPrint('Pause for mic failed: $e');
    }
  }

  Future<void> resumeAfterMic() async {
    if (!_pausedForMic || _ambientPlayer == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      await _ambientPlayer!.play();
      final target =
          _volumeBeforeMic > 0 ? _volumeBeforeMic : _effectiveAmbientVolume;
      for (double v = 0.01; v < target; v += 0.02) {
        await _ambientPlayer!.setVolume(v.clamp(0.0, 0.35));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await _ambientPlayer!.setVolume(target.clamp(0.0, 0.35));
      _pausedForMic = false;
      _ambientPlaying = true;
      debugPrint('Ambient resumed after mic session');
    } catch (e) {
      debugPrint('Resume after mic failed: $e');
      _pausedForMic = false;
      _ambientPlaying = false;
      await startAmbient();
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _ambientPlayer?.setVolume(_effectiveAmbientVolume);
    } catch (_) {}
    unawaited(_saveSettingAsync('sound_volume', _volume.toString()));
  }

  Future<void> setAmbientVolume(double value) async {
    _ambientVolume = value.clamp(0.0, 1.0);
    try {
      await _ambientPlayer?.setVolume(_effectiveAmbientVolume);
    } catch (_) {}
    unawaited(_saveSettingAsync('ambient_volume', _ambientVolume.toString()));
  }

  Future<void> setProfile(String profile) async {
    _profile = profile;
    if (profile == 'silent' || profile == 'professional') {
      await stopAmbient();
    }
    unawaited(_saveSettingAsync('sound_profile', profile));
  }

  Future<void> dispose() async {
    await _ambientStateSubscription?.cancel();
    _ambientStateSubscription = null;
    try {
      await _ambientPlayer?.dispose();
    } catch (_) {}
    _ambientPlayer = null;
    _ambientPlaying = false;
  }

  Future<void> _setAssetWithFallback(
      AudioPlayer player, List<String> candidates) async {
    Object? lastError;
    for (final asset in candidates) {
      try {
        await player.setAsset(asset);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('Unable to load any audio asset');
  }

  Future<void> addTrack(String path) async {
    if (path.trim().isEmpty) {
      return;
    }
    _customTracks.add(path.trim());
    await _savePlaylist();
  }

  Future<void> setCustomMusicPath(String absolutePath) async {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      debugPrint('[SoundService] setCustomMusicPath: file not found');
      return;
    }

    _customMusicPath = absolutePath;
    await _saveSettingAsync('custom_music_path', absolutePath);
    debugPrint('[SoundService] custom music set: $absolutePath');

    if (_ambientPlaying) {
      await startAmbient(volume: _ambientVolume);
    }
  }

  Future<void> removeTrack(int index) async {
    if (index < 0 || index >= _customTracks.length) {
      return;
    }
    _customTracks.removeAt(index);
    if (_trackIndex >= _customTracks.length) {
      _trackIndex = 0;
    }
    await _savePlaylist();
  }

  Future<void> _loadPlaylist() async {
    if (_playlistLoaded) {
      return;
    }
    try {
      final db = await DbHelper.instance.database;
      final playlistRows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: <Object?>['music_playlist'],
        limit: 1,
      );
      if (playlistRows.isNotEmpty) {
        final raw = playlistRows.first['value']?.toString() ?? '[]';
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _customTracks
            ..clear()
            ..addAll(decoded
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty));
        }
      }

      final indexRows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: <Object?>['music_playlist_index'],
        limit: 1,
      );
      if (indexRows.isNotEmpty) {
        _trackIndex =
            int.tryParse(indexRows.first['value']?.toString() ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('Playlist load failed: $e');
    } finally {
      _playlistLoaded = true;
    }
  }

  Future<void> _savePlaylist() async {
    await _saveSettingAsync('music_playlist', jsonEncode(_customTracks));
    await _saveSettingAsync('music_playlist_index', _trackIndex.toString());
  }

  String _nextTrack({String? assetPath}) {
    final customPath = _customMusicPath;
    if (customPath != null && customPath.isNotEmpty) {
      if (File(customPath).existsSync()) {
        return customPath;
      }
      _customMusicPath = null;
      unawaited(_saveSettingAsync('custom_music_path', ''));
    }

    if (_customTracks.isNotEmpty) {
      final track = _customTracks[_trackIndex % _customTracks.length];
      _trackIndex = (_trackIndex + 1) % _customTracks.length;
      unawaited(
          _saveSettingAsync('music_playlist_index', _trackIndex.toString()));
      return track;
    }

    final builtInTracks = <String>[
      if (assetPath != null && assetPath.trim().isNotEmpty) assetPath.trim(),
      'assets/sounds/ambient/morning_bells.mp3',
      'assets/sounds/ambient/focus_hum.mp3',
      'assets/sounds/ambient/evening_calm.mp3',
      'assets/sounds/ambient/deep_night.mp3',
      'assets/sounds/morning_bells.mp3',
      'assets/sounds/evening_calm.mp3',
    ];
    final deduped = builtInTracks.toSet().toList();
    final track = deduped[_trackIndex % deduped.length];
    _trackIndex = (_trackIndex + 1) % deduped.length;
    unawaited(
        _saveSettingAsync('music_playlist_index', _trackIndex.toString()));
    return track;
  }

  String _fallbackAmbientAsset() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return 'assets/sounds/ambient/morning_bells.mp3';
    }
    if (hour >= 10 && hour < 17) {
      return 'assets/sounds/ambient/focus_hum.mp3';
    }
    if (hour >= 17 && hour < 22) {
      return 'assets/sounds/ambient/evening_calm.mp3';
    }
    return 'assets/sounds/ambient/deep_night.mp3';
  }

  Future<void> _setAmbientSourceWithFallback(
    AudioPlayer player,
    String track,
    String fallbackAsset,
  ) async {
    try {
      if (_looksLikeFilePath(track)) {
        await player.setFilePath(track);
      } else if (track.startsWith('assets/')) {
        await player.setAsset(track);
      } else {
        await player.setAsset('assets/sounds/$track.mp3');
      }
      return;
    } catch (_) {}

    await _setAssetWithFallback(player, <String>[
      fallbackAsset,
      'assets/sounds/ambient/morning_bells.mp3',
      'assets/sounds/morning_bells.mp3',
    ]);
  }

  bool _looksLikeFilePath(String path) =>
      path.contains('\\') || path.contains('/') || path.contains(':');

  Future<void> _saveSettingAsync(String key, String value) async {
    try {
      final db = await DbHelper.instance.database;
      await db.insert(
        'app_settings',
        <String, Object?>{'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  double get _effectiveAmbientVolume =>
      (_ambientVolume * _volume).clamp(0.0, 0.35);

  double get volume => _volume;

  String get profile => _profile;

  bool get ambientPlaying => _ambientPlaying;

  bool get reminderActive => _reminderActive;

  String? get customMusicPath => _customMusicPath;
}
