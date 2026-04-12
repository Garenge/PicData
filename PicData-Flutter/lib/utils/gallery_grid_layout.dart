import 'package:flutter/material.dart';

/// 套图网格：窄边 < 600 视为手机/紧凑布局（与 [PicContentGrid.resolveItemWidth] 一致）。
bool isCompactGalleryGrid(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide < 600;
}

/// Grid 单元之间的主/交叉轴间距。
double galleryGridSpacing(BuildContext context) {
  return isCompactGalleryGrid(context) ? 8.0 : 12.0;
}

/// 套图列表页与屏幕左右留白：手机 8；Mac 维持原 8。
double galleryPageHorizontalInset(BuildContext context) {
  return 8.0;
}

/// 应用内文件夹网格与屏幕左右留白：仅手机 8；Mac 为 0（仍用原居中算法）。
double fileBrowserHorizontalInset(BuildContext context) {
  return isCompactGalleryGrid(context) ? 8.0 : 0.0;
}

/// 卡片底部标题区边距（紧凑时左右略小，把宽度让给标题文字）。
EdgeInsets galleryGridCellTitleInsets(BuildContext context) {
  if (isCompactGalleryGrid(context)) {
    return const EdgeInsets.fromLTRB(3, 4, 2, 4);
  }
  return const EdgeInsets.fromLTRB(6, 8, 6, 8);
}

/// 卡片标题字号。
double galleryGridTitleFontSize(BuildContext context) {
  return isCompactGalleryGrid(context) ? 11.0 : 13.0;
}

/// 下载按钮图标逻辑大小（[IconButton.iconSize]）。
double galleryGridDownloadIconSize(BuildContext context) {
  return isCompactGalleryGrid(context) ? 27.2 : 34.0;
}
