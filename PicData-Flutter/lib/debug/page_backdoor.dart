import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Debug-only backdoor: tap a page title to print its file/class info.
///
/// This avoids runtime reflection; file/class name is hard-coded by caller.
void debugPrintPageBackdoorInfo({
  required String className,
  required String filePath,
}) {
  if (!kDebugMode) return;
  // ignore: avoid_print
  print('[PageBackdoor] class=$className file=$filePath');
  // 复制
  Clipboard.setData(ClipboardData(text: '[PageBackdoor] class=$className file=$filePath'));
}

