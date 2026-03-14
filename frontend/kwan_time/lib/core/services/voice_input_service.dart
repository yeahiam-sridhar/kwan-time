import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  VoiceInputService._();

  static SpeechToText? _activeSpeech;
  static Completer<void>? _cancelSignal;

  static Future<String> capture() async {
    final session = await AudioSession.instance;
    bool focusAcquired = false;
    SpeechToText? speech;
    Timer? watchdog;
    final done = Completer<String>();
    String transcript = '';

    void finish(String value) {
      if (!done.isCompleted) {
        done.complete(value);
      }
    }

    try {
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: true,
        ),
      );
      focusAcquired = await session.setActive(true);
      if (!focusAcquired) {
        debugPrint('VoiceInputService: audio focus denied');
        return '';
      }

      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }
      if (status.isPermanentlyDenied) {
        debugPrint('VoiceInputService: microphone permanently denied');
        await openAppSettings();
        return '';
      }
      if (!status.isGranted) {
        debugPrint('VoiceInputService: microphone denied');
        return '';
      }

      speech = SpeechToText();
      _activeSpeech = speech;
      _cancelSignal = Completer<void>();

      final available = await speech.initialize(
        onStatus: (status) {
          debugPrint('VoiceInputService STT status: $status');
        },
        onError: (error) {
          debugPrint('VoiceInputService STT error: ${error.errorMsg}');
          finish('');
        },
        debugLogging: true,
      );
      if (!available) {
        debugPrint('VoiceInputService: speech engine unavailable');
        if (Platform.isAndroid && !kReleaseMode) {
          debugPrint('Emulator mic unavailable - test on device');
        }
        return '';
      }
      if (!speech.isAvailable) {
        debugPrint('VoiceInputService: isAvailable=false');
        return '';
      }

      String? localeId;
      try {
        final locales = await speech.locales();
        const preferredLocale = 'en_IN';
        final preferred = locales.where((l) => l.localeId == preferredLocale);
        if (preferred.isNotEmpty) {
          localeId = preferredLocale;
        } else if (locales.isNotEmpty) {
          localeId = locales.first.localeId;
          debugPrint('VoiceInputService: locale fallback -> $localeId');
        }
      } catch (e) {
        debugPrint('VoiceInputService: locale discovery failed: $e');
      }

      watchdog = Timer(const Duration(seconds: 12), () {
        debugPrint('VoiceInputService: timeout watchdog fired');
        finish('');
      });

      await speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (!result.finalResult) {
            return;
          }
          if (words.isEmpty) {
            debugPrint('VoiceInputService: empty transcript received');
            finish('');
            return;
          }
          finish(words);
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
        cancelOnError: false,
        partialResults: true,
      );

      transcript = await Future.any<String>(<Future<String>>[
        done.future,
        _cancelSignal!.future.then((_) => ''),
      ]);
    } catch (e) {
      debugPrint('VoiceInputService capture error: $e');
      transcript = '';
    } finally {
      watchdog?.cancel();
      try {
        await speech?.stop();
      } catch (_) {}
      try {
        await speech?.cancel();
      } catch (_) {}
      _activeSpeech = null;
      _cancelSignal = null;
      if (focusAcquired) {
        try {
          await session.setActive(false);
        } catch (_) {}
      }
    }

    return transcript.trim();
  }

  static Future<void> stopCapture() async {
    try {
      if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
        _cancelSignal!.complete();
      }
      await _activeSpeech?.stop();
    } catch (_) {}
  }

  static Future<void> cancelCapture() async {
    try {
      if (_cancelSignal != null && !_cancelSignal!.isCompleted) {
        _cancelSignal!.complete();
      }
      await _activeSpeech?.cancel();
    } catch (_) {}
  }
}
