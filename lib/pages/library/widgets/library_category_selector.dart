import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';
import '../controller/library_provider.dart';

class LibraryCategorySelector extends ConsumerWidget {
  const LibraryCategorySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取资源类型数量
    final typeCount = ResourceType.values.length;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      // 使用LayoutBuilder来获取可用宽度并均匀分布项目
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          // 根据类型数量均匀分配宽度
          // 减去两边的padding (32)
          final itemWidth = (availableWidth - 32) / typeCount;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final type in ResourceType.values)
                SizedBox(
                  width: itemWidth,
                  child: Center(child: _buildCategoryItem(context, ref, type)),
                ),
            ],
          );
        },
      ),
    );
  }

  // 构建单个类别选项
  Widget _buildCategoryItem(
    BuildContext context,
    WidgetRef ref,
    ResourceType type,
  ) {
    final selectedType = ref.watch(selectedResourceTypeProvider);
    final isSelected = selectedType == type;
    final resourceCount = ref.watch(resourceCountProvider(type));

    return GestureDetector(
      onTap: () => ref.read(libraryProvider.notifier).setSelectedType(type),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              size: 32,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            SizedBox(height: 8),
            Text(
              type.displayName,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              '($resourceCount)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
