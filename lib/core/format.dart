/// Small formatting helpers shared across the UI.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// Transfer rates use the same unit ladder but always in bytes/second.
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '—';
  return '${formatBytes(bytesPerSecond.round())}/s';
}

String formatDuration(Duration duration) {
  if (duration.inSeconds < 1) return 'a moment';
  if (duration.inSeconds < 60) return '${duration.inSeconds}s';
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  if (minutes < 60) {
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  }
  final hours = duration.inHours;
  final restMinutes = minutes % 60;
  return restMinutes == 0 ? '${hours}h' : '${hours}h ${restMinutes}m';
}

String formatEta(int remainingBytes, double bytesPerSecond) {
  if (remainingBytes <= 0) return 'finishing';
  if (bytesPerSecond <= 0) return 'estimating';
  final seconds = (remainingBytes / bytesPerSecond).round();
  return formatDuration(Duration(seconds: seconds));
}

String formatCount(int count, String singular, [String? plural]) {
  return '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
}

String formatTimestamp(DateTime time) {
  final now = DateTime.now();
  final local = time.toLocal();
  final sameDay =
      now.year == local.year && now.month == local.month && now.day == local.day;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (sameDay) return 'Today, $hour:$minute';
  final yesterday = now.subtract(const Duration(days: 1));
  if (yesterday.year == local.year &&
      yesterday.month == local.month &&
      yesterday.day == local.day) {
    return 'Yesterday, $hour:$minute';
  }
  final month = _months[local.month - 1];
  return '$month ${local.day}, $hour:$minute';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `application/vnd.android.package-archive` style lookup is overkill here;
/// the UI only needs a coarse icon family.
String fileKindLabel(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return 'FILE';
  final ext = name.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'heic':
    case 'bmp':
    case 'svg':
      return 'IMAGE';
    case 'mp4':
    case 'mkv':
    case 'mov':
    case 'avi':
    case 'webm':
      return 'VIDEO';
    case 'mp3':
    case 'wav':
    case 'flac':
    case 'm4a':
    case 'ogg':
      return 'AUDIO';
    case 'pdf':
      return 'PDF';
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return 'ARCHIVE';
    case 'apk':
      return 'APP';
    case 'doc':
    case 'docx':
    case 'txt':
    case 'md':
    case 'rtf':
      return 'DOC';
    case 'xls':
    case 'xlsx':
    case 'csv':
      return 'SHEET';
    case 'ppt':
    case 'pptx':
      return 'SLIDES';
    default:
      return ext.toUpperCase().length > 5 ? 'FILE' : ext.toUpperCase();
  }
}

String sanitizeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'file';
  return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
}

/// Appends ` (2)`, ` (3)`… when a name already exists in [taken].
String uniqueFileName(String name, Set<String> taken) {
  if (!taken.contains(name.toLowerCase())) return name;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  var index = 2;
  while (true) {
    final candidate = '$stem ($index)$ext';
    if (!taken.contains(candidate.toLowerCase())) return candidate;
    index++;
  }
}
