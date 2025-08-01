// lib/pages/library/library_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controller/library_provider.dart';
import 'widgets/library_app_bar.dart';
import 'widgets/library_category_selector.dart';
import 'widgets/library_resource_grid.dart';
import 'widgets/library_import_button.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时，加载资源列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).loadResources();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      libraryProvider.select((state) => state.isLoading),
    );
    final errorMessage = ref.watch(
      libraryProvider.select((state) => state.errorMessage),
    );

    return Scaffold(
      appBar: const LibraryAppBar(),
      body: Column(
        children: [
          // 类别选择器区域
          const LibraryCategorySelector(),

          // 错误消息显示（如果有）
          if (errorMessage != null)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                      ref.read(libraryProvider.notifier).state = ref
                          .read(libraryProvider)
                          .copyWith(clearError: true);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ),

          // 主要内容区域
          Expanded(
            child: Stack(
              children: [
                // 资源网格视图
                const LibraryResourceGrid(),

                // 加载状态指示器
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.1),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
      // 添加资源的悬浮按钮
      floatingActionButton: const LibraryImportButton(),
    );
  }
}
