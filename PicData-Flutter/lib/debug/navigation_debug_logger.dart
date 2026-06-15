import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pic_data/pages/Home/gallery/pic_detail_page.dart';
import 'package:pic_data/pages/Home/gallery/tag_gallery_page.dart';
import 'package:pic_data/pages/Home/home_page.dart';
import 'package:pic_data/pages/downloads/download_failed_items_page.dart';
import 'package:pic_data/pages/downloads/downloads_page.dart';
import 'package:pic_data/pages/files/file_browser_page.dart';
import 'package:pic_data/pages/files/files_page.dart';
import 'package:pic_data/pages/files/local_image_gallery_page.dart';
import 'package:pic_data/pages/files/text_file_preview_page.dart';
import 'package:pic_data/pages/settings/settings_page.dart';

class NavigationDebugPageInfo {
  const NavigationDebugPageInfo({
    required this.className,
    required this.filePath,
  });

  final String className;
  final String filePath;
}

class NavigationDebugObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == Navigator.defaultRouteName) {
      return;
    }
    _logRoute(route);
  }
}

void logNavigationDebugPage(Type pageType) {
  if (!kDebugMode) {
    return;
  }
  final info = _pageInfoByType[pageType];
  if (info == null) {
    _logUnknownPage(pageType.toString());
    return;
  }
  _logPageInfo(info);
}

void _logRoute(Route<dynamic> route) {
  if (!kDebugMode || route is! MaterialPageRoute<dynamic>) {
    return;
  }
  final BuildContext? context = route.navigator?.context;
  if (context == null) {
    return;
  }
  final Widget page = route.builder(context);
  logNavigationDebugPage(page.runtimeType);
}

void _logPageInfo(NavigationDebugPageInfo info) {
  // ignore: avoid_print
  print('[NavigationDebug] class=${info.className} file=${info.filePath}');
  Clipboard.setData(ClipboardData(text: info.className));
}

void _logUnknownPage(String className) {
  // ignore: avoid_print
  print('[NavigationDebug] class=$className file=<unknown>');
  Clipboard.setData(ClipboardData(text: className));
}

const Map<Type, NavigationDebugPageInfo>
_pageInfoByType = <Type, NavigationDebugPageInfo>{
  HomePage: NavigationDebugPageInfo(
    className: 'HomePage',
    filePath: 'PicData-Flutter/lib/pages/Home/home_page.dart',
  ),
  FilesPage: NavigationDebugPageInfo(
    className: 'FilesPage',
    filePath: 'PicData-Flutter/lib/pages/files/files_page.dart',
  ),
  DownloadsPage: NavigationDebugPageInfo(
    className: 'DownloadsPage',
    filePath: 'PicData-Flutter/lib/pages/downloads/downloads_page.dart',
  ),
  SettingsPage: NavigationDebugPageInfo(
    className: 'SettingsPage',
    filePath: 'PicData-Flutter/lib/pages/settings/settings_page.dart',
  ),
  TagGalleryPage: NavigationDebugPageInfo(
    className: 'TagGalleryPage',
    filePath: 'PicData-Flutter/lib/pages/Home/gallery/tag_gallery_page.dart',
  ),
  PicDetailPage: NavigationDebugPageInfo(
    className: 'PicDetailPage',
    filePath: 'PicData-Flutter/lib/pages/Home/gallery/pic_detail_page.dart',
  ),
  DownloadFailedItemsPage: NavigationDebugPageInfo(
    className: 'DownloadFailedItemsPage',
    filePath:
        'PicData-Flutter/lib/pages/downloads/download_failed_items_page.dart',
  ),
  FileBrowserPage: NavigationDebugPageInfo(
    className: 'FileBrowserPage',
    filePath: 'PicData-Flutter/lib/pages/files/file_browser_page.dart',
  ),
  LocalImageGalleryPage: NavigationDebugPageInfo(
    className: 'LocalImageGalleryPage',
    filePath: 'PicData-Flutter/lib/pages/files/local_image_gallery_page.dart',
  ),
  TextFilePreviewPage: NavigationDebugPageInfo(
    className: 'TextFilePreviewPage',
    filePath: 'PicData-Flutter/lib/pages/files/text_file_preview_page.dart',
  ),
};
