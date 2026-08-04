/// Formats a [Duration] as a short human-readable string, e.g. "1h 24m" or
/// "45m" or "< 1m". Shared by the trip list and trip detail screens so
/// duration reads consistently everywhere.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h';
  if (minutes > 0) return '${minutes}m';
  return '< 1m';
}
