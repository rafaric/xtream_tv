import 'package:logger/logger.dart';

/// Global logger instance for the application
///
/// Usage:
/// ```dart
/// import 'package:xtream_tv/utils/logger.dart';
///
/// logger.d('Debug message');
/// logger.i('Info message');
/// logger.w('Warning message');
/// logger.e('Error message');
/// ```
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
