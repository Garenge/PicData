import 'package:flutter/material.dart';

import '../../models/home_entry.dart';

/// 某个标签 / 入口对应的图集列表页面（占位实现）
class TagGalleryPage extends StatelessWidget {
  const TagGalleryPage({super.key, required this.entry});

  /// 当前选中的首页入口（包含标题和 URL）
  final HomeEntry entry;

  @override
  Widget build(BuildContext context) {
    // 占位数据：后续可替换为真实抓取结果
    final List<String> albums = List.generate(
      20,
      (index) => '图集 #${index + 1} - ${entry.title}',
    );

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 整体内容边距
          const horizontalPadding = 16.0;
          const verticalPadding = 16.0;

          // 期望的单个 cell 宽度（固定宽度）
          const targetItemWidth = 170.0;
          const spacing = 12.0;

          final maxWidth = (constraints.maxWidth - horizontalPadding * 2).clamp(
            0.0,
            double.infinity,
          );

          // 根据可用宽度和目标宽度，动态计算每行个数
          int crossAxisCount = maxWidth ~/ targetItemWidth;
          if (crossAxisCount < 1) {
            crossAxisCount = 1;
          }

          // 计算实际网格宽度，使单个 cell 宽度尽量接近 target，并整体居中
          double gridWidth =
              crossAxisCount * targetItemWidth + (crossAxisCount - 1) * spacing;
          if (gridWidth > maxWidth && crossAxisCount > 1) {
            // 退一步，避免超出
            crossAxisCount -= 1;
            gridWidth =
                crossAxisCount * targetItemWidth +
                (crossAxisCount - 1) * spacing;
          }
          gridWidth = gridWidth.clamp(0.0, maxWidth);

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: gridWidth,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final title = albums[index];
                    return Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.photo_library_outlined,
                                size: 40,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
