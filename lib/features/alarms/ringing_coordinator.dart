/// Guards against stacking two identical ringing screens.
///
/// An alarm can be delivered through several paths at once (full-screen intent,
/// notification tap, cold-start launch details). This coordinator ensures only
/// one ring per alarm is active at a time, and lets the ring be released when
/// its screen closes so the same alarm can ring again later.
class RingingCoordinator {
  int? _active;

  /// The alarm currently being rung, or `null`.
  int? get active => _active;

  bool get isRinging => _active != null;

  /// Attempts to claim the ring for [alarmId].
  ///
  /// Returns `true` if the caller should show the ringing screen, or `false` if
  /// the same alarm is already ringing (a duplicate delivery to ignore).
  bool tryAcquire(int alarmId) {
    if (_active == alarmId) return false;
    _active = alarmId;
    return true;
  }

  /// Releases the ring if [alarmId] owns it.
  void release(int alarmId) {
    if (_active == alarmId) _active = null;
  }
}
