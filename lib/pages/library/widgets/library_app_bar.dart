import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/library_provider.dart';

class LibraryAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const LibraryAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      libraryProvider.select((state) => state.isLoading),
    );

    return AppBar(
      automaticallyImplyLeading: false,
      title: Text('学习资料库'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        // 搜索按钮
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            _showSearchDialog(context, ref);
          },
          tooltip: '搜索资源',
        ),
        // 刷新按钮
        IconButton(
          icon:
              isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Icon(Icons.refresh),
          onPressed:
              isLoading
                  ? null
                  : () => ref.read(libraryProvider.notifier).loadResources(),
          tooltip: '刷新资源列表',
        ),
      ],
    );
  }

  // 显示搜索对话框
  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController(
      text: ref.read(libraryProvider).searchQuery,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('搜索资源'),
            content: TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入关键词',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                ref.read(libraryProvider.notifier).updateSearchQuery(value);
                Navigator.pop(context);
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(libraryProvider.notifier).clearSearch();
                  Navigator.pop(context);
                },
                child: Text('清除'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(libraryProvider.notifier)
                      .updateSearchQuery(textController.text);
                  Navigator.pop(context);
                },
                child: Text('搜索'),
              ),
            ],
          ),
    );
  }
}
