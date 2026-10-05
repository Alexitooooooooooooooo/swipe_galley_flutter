import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home_widget_service.dart';

/// Ajustes y estadísticas de uso, persistidos localmente con SharedPreferences.
class SettingsProvider with ChangeNotifier {
  static const String _kHaptics = 'pref_haptics';
  static const String _kSound = 'pref_sound';
  static const String _kDailyGoal = 'pref_daily_goal';
  static const String _kOnboarding = 'pref_onboarding_done';
  static const String _kMoveAlbum = 'pref_move_album';
  static const String _kReviewedToday = 'stat_reviewed_today';
  static const String _kGoalDate = 'stat_goal_date';
  static const String _kTotalReviewed = 'stat_total_reviewed';
  static const String _kTotalDeleted = 'stat_total_deleted';
  static const String _kFreedBytes = 'stat_freed_bytes';

  bool _haptics = true;
  bool _sound = true;
  int _dailyGoal = 10;
  bool _onboardingDone = false;
  String _moveAlbum = 'swipe-album';

  int _reviewedToday = 0;
  int _totalReviewed = 0;
  int _totalDeleted = 0;
  int _freedBytes = 0;
  String _goalDate = '';

  bool get hapticsEnabled => _haptics;
  bool get soundEnabled => _sound;
  int get dailyGoal => _dailyGoal;
  bool get onboardingDone => _onboardingDone;
  String get moveAlbum => _moveAlbum;

  /// Conteo de hoy limitado a la meta (nunca muestra más que el objetivo).
  int get reviewedToday => _reviewedToday > _dailyGoal ? _dailyGoal : _reviewedToday;
  int get totalReviewed => _totalReviewed;
  int get totalDeleted => _totalDeleted;
  int get freedBytes => _freedBytes;

  double get dailyProgress =>
      _dailyGoal <= 0 ? 0 : (reviewedToday / _dailyGoal).clamp(0.0, 1.0);
  bool get goalReached => reviewedToday >= _dailyGoal;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _haptics = prefs.getBool(_kHaptics) ?? true;
      _sound = prefs.getBool(_kSound) ?? true;
      _dailyGoal = prefs.getInt(_kDailyGoal) ?? 10;
      _onboardingDone = prefs.getBool(_kOnboarding) ?? false;
      _moveAlbum = prefs.getString(_kMoveAlbum) ?? 'swipe-album';
      _totalReviewed = prefs.getInt(_kTotalReviewed) ?? 0;
      _totalDeleted = prefs.getInt(_kTotalDeleted) ?? 0;
      _freedBytes = prefs.getInt(_kFreedBytes) ?? 0;
      _goalDate = prefs.getString(_kGoalDate) ?? _todayKey();
      // Si cambió el día, reiniciamos el progreso diario.
      _reviewedToday =
          _goalDate == _todayKey() ? (prefs.getInt(_kReviewedToday) ?? 0) : 0;
    } catch (_) {
      // Si algo falla, seguimos con los valores por defecto.
    }
    notifyListeners();
    _syncWidget();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    notifyListeners();
    await _prefs((p) => p.setBool(_kHaptics, value));
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    notifyListeners();
    await _prefs((p) => p.setBool(_kSound, value));
  }

  Future<void> setDailyGoal(int value) async {
    _dailyGoal = value.clamp(1, 999);
    notifyListeners();
    await _prefs((p) => p.setInt(_kDailyGoal, _dailyGoal));
    await _syncWidget();
  }

  Future<void> completeOnboarding() async {
    if (_onboardingDone) return;
    _onboardingDone = true;
    notifyListeners();
    await _prefs((p) => p.setBool(_kOnboarding, true));
  }

  Future<void> resetOnboarding() async {
    _onboardingDone = false;
    notifyListeners();
    await _prefs((p) => p.setBool(_kOnboarding, false));
  }

  Future<void> setMoveAlbum(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _moveAlbum = trimmed;
    notifyListeners();
    await _prefs((p) => p.setString(_kMoveAlbum, trimmed));
  }

  Future<void> recordSwipe() async {
    final today = _todayKey();
    if (_goalDate != today) {
      _goalDate = today;
      _reviewedToday = 0;
    }
    // No contar más allá de la meta (evita mostrar 11/10).
    if (_reviewedToday < _dailyGoal) {
      _reviewedToday++;
    }
    _totalReviewed++;
    notifyListeners();
    await _prefs((p) async {
      await p.setInt(_kReviewedToday, _reviewedToday);
      await p.setString(_kGoalDate, _goalDate);
      await p.setInt(_kTotalReviewed, _totalReviewed);
    });
    await _syncWidget();
  }

  Future<void> recordDeletion({required int count, required int bytes}) async {
    if (count <= 0) return;
    _totalDeleted += count;
    if (bytes > 0) _freedBytes += bytes;
    notifyListeners();
    await _prefs((p) async {
      await p.setInt(_kTotalDeleted, _totalDeleted);
      await p.setInt(_kFreedBytes, _freedBytes);
    });
    await _syncWidget();
  }

  Future<void> resetStats() async {
    _reviewedToday = 0;
    _totalReviewed = 0;
    _totalDeleted = 0;
    _freedBytes = 0;
    _goalDate = _todayKey();
    notifyListeners();
    await _prefs((p) async {
      await p.setInt(_kReviewedToday, 0);
      await p.setInt(_kTotalReviewed, 0);
      await p.setInt(_kTotalDeleted, 0);
      await p.setInt(_kFreedBytes, 0);
      await p.setString(_kGoalDate, _goalDate);
    });
    await _syncWidget();
  }

  /// Envía la meta diaria al widget de pantalla de inicio (Android).
  Future<void> _syncWidget() async {
    await HomeWidgetService.syncStats(
      goal: _dailyGoal,
      done: reviewedToday,
      date: _todayKey(),
    );
    await HomeWidgetService.syncStatsWidget(
      deleted: _totalDeleted,
      freed: _freedBytes,
      reviewed: _totalReviewed,
    );
  }

  Future<void> _prefs(Future<void> Function(SharedPreferences prefs) action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await action(prefs);
    } catch (_) {
      // Ignoramos errores de persistencia.
    }
  }
}
