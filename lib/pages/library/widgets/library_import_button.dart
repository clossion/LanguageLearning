import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';
import '../controller/library_provider.dart';

class LibraryImportButton extends ConsumerWidget {
  const LibraryImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedResourceTypeProvider);
    final isLoading = ref.watch(
      libraryProvider.select((state) => state.isLoading),
    );

    // 如果未选择类型或正在加载，则不显示按钮
    if (selectedType == null || isLoading) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: () => _importResource(context, ref, selectedType),
      tooltip: '导入${selectedType.displayName}',
      backgroundColor: Colors.blue,
      child: Icon(Icons.add),
    );
  }

  // 导入资源
  Future<void> _importResource(
    BuildContext context,
    WidgetRef ref,
    ResourceType type,
  ) async {
    final success = await ref.read(libraryProvider.notifier).addResource(type);

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('成功添加${type.displayName}资源')));
    } else if (context.mounted) {
      final error = ref.read(libraryProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}
