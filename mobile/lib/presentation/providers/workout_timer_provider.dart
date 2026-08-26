import 'dart:async';

import 'package:flutter/foundation.dart';

enum TimerMode { countdown, stopwatch }

class WorkoutTimerProvider extends ChangeNotifier {
  WorkoutTimerProvider({
    required this.presets,
    required int initialPresetMinutes,
    required this.storageKey,
  })  : _selectedPresetMinutes = initialPresetMinutes,
        _remaining = Duration(minutes: initialPresetMinutes);

  final List<int> presets;
  final String storageKey;

  TimerMode _mode = TimerMode.countdown;
  bool _isRunning = false;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration _remaining;
  int _selectedPresetMinutes;

  TimerMode get mode => _mode;
  bool get isRunning => _isRunning;
  int get selectedPresetMinutes => _selectedPresetMinutes;

  String get displayValue {
    final value = _mode == TimerMode.countdown ? _remaining : _elapsed;
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get progressValue {
    if (_mode == TimerMode.stopwatch) {
      final limit = Duration(minutes: _selectedPresetMinutes);
      if (limit.inSeconds == 0) {
        return 0;
      }
      final ratio = _elapsed.inSeconds / limit.inSeconds;
      return ratio.clamp(0, 1).toDouble();
    }

    final totalSeconds = _selectedPresetMinutes * 60;
    if (totalSeconds == 0) {
      return 0;
    }
    final remainingRatio = _remaining.inSeconds / totalSeconds;
    return 1 - remainingRatio.clamp(0, 1).toDouble();
  }

  void toggleMode(TimerMode value) {
    if (_mode == value) {
      return;
    }
    _stopTicker();
    _mode = value;
    _elapsed = Duration.zero;
    _remaining = Duration(minutes: _selectedPresetMinutes);
    notifyListeners();
  }

  void selectPreset(int minutes) {
    _selectedPresetMinutes = minutes;
    _elapsed = Duration.zero;
    _remaining = Duration(minutes: minutes);
    notifyListeners();
  }

  void toggleRunning() {
    if (_isRunning) {
      _stopTicker();
      notifyListeners();
      return;
    }

    _isRunning = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mode == TimerMode.countdown) {
        if (_remaining.inSeconds <= 1) {
          _remaining = Duration.zero;
          _stopTicker();
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      } else {
        _elapsed += const Duration(seconds: 1);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void reset() {
    _stopTicker();
    _elapsed = Duration.zero;
    _remaining = Duration(minutes: _selectedPresetMinutes);
    notifyListeners();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

class MemberWorkoutTimerProvider extends WorkoutTimerProvider {
  MemberWorkoutTimerProvider()
      : super(
          storageKey: 'member',
          presets: const [10, 15, 30],
          initialPresetMinutes: 10,
        );
}

class TrainerWorkoutTimerProvider extends WorkoutTimerProvider {
  TrainerWorkoutTimerProvider()
      : super(
          storageKey: 'trainer',
          presets: const [15, 30, 45],
          initialPresetMinutes: 45,
        );

  String get intensityLabel {
    final minutes = selectedPresetMinutes;
    if (minutes >= 45) return 'HIGH INTENSITY';
    if (minutes >= 30) return 'MEDIUM INTENSITY';
    if (minutes >= 15) return 'LIGHT INTENSITY';
    return 'QUICK SESSION';
  }
}
