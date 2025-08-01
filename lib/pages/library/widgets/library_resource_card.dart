import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/library_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/services/service_provider.dart';
import '../controller/library_provider.dart';
import 'package:frontend/pages/reader/text_page.dart';

class LibraryResourceCard extends ConsumerWidget {
  final LibraryItem resource;

  const LibraryResourceCard({super.key, required this.resource});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideoType = resource.type == ResourceType.video;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openResource(context, ref, resource),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 资源卡片顶部
            Expanded(
              child: Container(
                color: _getColorForType(resource.type),
                alignment: Alignment.center,
                child: Icon(resource.type.icon, size: 48, color: Colors.white),
              ),
            ),

            // 资源信息部分
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '添加于: ${_formatDate(resource.dateAdded)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

            // 底部操作按钮 - 使用Row并设置mainAxisAlignment确保均匀分布
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _showDeleteConfirmDialog(context, ref, resource),
                    tooltip: '删除',
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.all(8),
                  ),
                  // 视频类型始终显示导入字幕按钮
                  if (isVideoType)
                    IconButton(
                      icon: Icon(
                        resource.subtitlePath != null ? Icons.subtitles_off : Icons.subtitles,
                        color: Colors.green,
                      ),
                      onPressed: () => _importSubtitlesForVideo(context, ref, resource),
                      tooltip: resource.subtitlePath != null ? '更换字幕' : '导入字幕',
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.all(8),
                    ),
                  
                  // 所有类型都显示打开按钮
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: Colors.blue),
                    onPressed: () => _openResource(context, ref, resource),
                    tooltip: '打开',
                    constraints: BoxConstraints(),
                    padding: EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8), // 底部添加间距
          ],
        ),
      ),
    );
  }

  // 打开资源
  void _openResource(BuildContext context, WidgetRef ref, LibraryItem item) {
    
      // ① 电子书 → EbookReaderPage（无视频控件的滚动阅读）
  if (item.type == ResourceType.ebook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceProvider.init(
          userId: currentUserId!,                          // 已登录
          showMessage: (msg) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg))),
          child: EbookReaderPage(
            filePath: item.filePath,
            title:    item.title, userId: '',
          ),
        ),
      ),
    );
    return;   // 别往下走
  }

  // ② 其余类型（视频 / 音频…）保持老逻辑
  Navigator.pushNamed(context, '/reader', arguments: {
    'filePath':     item.filePath,
    'type':         item.type.toString(),
    'title':        item.title,
    'subtitlePath': item.subtitlePath,
  });
  }

  // 为视频导入字幕
  Future<void> _importSubtitlesForVideo(
    BuildContext context,
    WidgetRef ref,
    LibraryItem videoItem,
  ) async {
    try {
      // 设置文件选择器的过滤条件（字幕文件扩展名）
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'vtt', 'sub'],
        dialogTitle: '选择字幕文件',
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        return;
      }

      final filePath = result.files.first.path!;
      final fileName = '${videoItem.title}的字幕';
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // 创建新的字幕项 (作为"其他"类型存储)
      final subtitleItem = LibraryItem(
        id: id,
        title: fileName,
        filePath: filePath,
        type: ResourceType.other, // 将字幕作为"其他"类型存储
        dateAdded: DateTime.now(),
        description: '字幕文件  videoId:${videoItem.id}',
      );

      // 调用服务添加字幕资源
      final libraryService = ref.read(libraryServiceProvider);
      final success = await libraryService.addResource(subtitleItem);

      // 显示结果通知
      if (success && context.mounted) {
        // 更新原视频项，添加字幕路径
        final updatedVideoItem = videoItem.copyWith(subtitlePath: filePath);
        await libraryService.updateResource(updatedVideoItem);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功为 ${videoItem.title} 添加字幕'))
          );

          await ref.read(libraryProvider.notifier).loadResources();
          
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加字幕失败')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入字幕时出错: $e')));
      }
    }
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    LibraryItem item,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('删除确认'),
            content: Text('确定要删除 "${item.title}" 吗？此操作不可撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteResource(context, ref, item);
                },
                child: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  // 删除资源
  Future<void> _deleteResource(
    BuildContext context,
    WidgetRef ref,
    LibraryItem item,
  ) async {
    // 如果是视频资源且带有字幕，先找到并删除关联的字幕资源
    if (item.type == ResourceType.video && item.subtitlePath != null) {
      final allResources = ref.read(libraryServiceProvider).getAllResources();
      final subtitleItems = allResources.where((res) => 
        res.type == ResourceType.other && 
        res.description != null && 
        res.description!.contains('videoId:${item.id}')
      ).toList();
      
      // 删除找到的字幕资源
      for (final subtitleItem in subtitleItems) {
        await ref.read(libraryProvider.notifier).removeResource(subtitleItem.id);
      }
    }
    
    // 删除主要资源
    final success = await ref
        .read(libraryProvider.notifier)
        .removeResource(item.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除资源: ${item.title}')));
    }
  }

  // 获取资源类型对应的颜色
  Color _getColorForType(ResourceType type) {
    switch (type) {
      case ResourceType.video:
        return Colors.red.shade700;
      case ResourceType.ebook:
        return Colors.blue.shade700;
      case ResourceType.audio:
        return Colors.purple.shade700;
      case ResourceType.other:
        return Colors.grey.shade700;
    }
  }

  // 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
