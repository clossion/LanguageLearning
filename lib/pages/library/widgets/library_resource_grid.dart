import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';
import '../controller/library_provider.dart';
import 'library_resource_card.dart';



class LibraryResourceGrid extends ConsumerWidget {
  const LibraryResourceGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(filteredResourcesProvider);

    // 如果没有资源，显示空状态视图
    if (resources.isEmpty) {
      return _buildEmptyView(context, ref);
    }

    // 根据屏幕宽度自适应调整网格列数
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount;

        if (width > 1200) {
          crossAxisCount = 6; // 超大屏幕显示6列
        } else if (width > 900) {
          crossAxisCount = 5; // 大屏幕显示5列
        } else if (width > 600) {
          crossAxisCount = 4; // 中等屏幕显示4列
        } else if (width > 400) {
          crossAxisCount = 3; // 小屏幕显示3列
        } else {
          crossAxisCount = 2; // 最小屏幕显示2列
        }

        return Padding(
          padding: EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: resources.length,
            itemBuilder: (context, index) {
              final item = resources[index];
              return LibraryResourceCard(resource: item);
            },
          ),
        );
      },
    );
  }

  // 构建空状态视图
  Widget _buildEmptyView(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedResourceTypeProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selectedType?.icon ?? Icons.folder_open,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            '没有${selectedType?.displayName ?? ''}资源',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text('点击右下角的加号按钮添加资源', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
