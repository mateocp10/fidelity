class EcuadorDateUtils {
  /// Converts a UTC ISO 8601 string to Ecuador Timezone (UTC-5)
  static DateTime toEcuadorTime(String isoString) {
    if (isoString.isEmpty) {
      return DateTime.now().toUtc().subtract(const Duration(hours: 5));
    }

    // Parse to UTC
    DateTime utcDate = DateTime.parse(isoString);
    if (!utcDate.isUtc) {
      // If the string doesn't specify 'Z', force it to act as UTC
      utcDate = DateTime.utc(
        utcDate.year,
        utcDate.month,
        utcDate.day,
        utcDate.hour,
        utcDate.minute,
        utcDate.second,
        utcDate.millisecond,
        utcDate.microsecond,
      );
    }

    // Convert to Ecuador time (UTC -5)
    return utcDate.subtract(const Duration(hours: 5));
  }

  /// Formats date only (dd/MM/yyyy) without hour/minute
  static String formatEcuadorDate(String isoString) {
    if (isoString.isEmpty) return 'Fecha inválida';
    try {
      final date = toEcuadorTime(isoString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  /// Formats date to display locally in UI (dd/MM/yyyy HH:mm)
  static String formatEcuadorTime(String isoString) {
    if (isoString.isEmpty) return 'Fecha inválida';
    try {
      final date = toEcuadorTime(isoString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  /// Get current date and time in Ecuador timezone
  static DateTime nowEcuador() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 5));
  }

  /// Returns the UTC DateTime representing 00:00:00.000 of the current day in Ecuador time
  static DateTime getStartOfDayEcuadorUtc() {
    final nowEc = nowEcuador();
    // 00:00 in Ecuador is 05:00 in UTC
    return DateTime.utc(nowEc.year, nowEc.month, nowEc.day, 5, 0, 0);
  }

  /// Returns the UTC DateTime representing 23:59:59.999 of the current day in Ecuador time
  static DateTime getEndOfDayEcuadorUtc() {
    final nowEc = nowEcuador();
    // 23:59:59 in Ecuador is 04:59:59 (next day) in UTC
    return DateTime.utc(nowEc.year, nowEc.month, nowEc.day, 5, 0, 0)
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
  }
}
