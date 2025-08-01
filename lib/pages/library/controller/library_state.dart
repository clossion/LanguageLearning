import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';

// Library页面的状态类
class LibraryState {
  final Map<ResourceType, List<LibraryItem>> resources;
  final ResourceType? selectedType;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const LibraryState({
    required this.resources,
    this.selectedType = ResourceType.video,
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  // 获取当前类型的资源列表
  List<LibraryItem> getCurrentResources() {
    if (selectedType == null) {
      // 如果没有选择类型，返回所有资源
      List<LibraryItem> allItems = [];
      resources.forEach((_, items) => allItems.addAll(items));
      return allItems;
    }
    return resources[selectedType] ?? [];
  }

  // 搜索过滤后的资源列表
  List<LibraryItem> getFilteredResources() {
    final currentResources = getCurrentResources();

    if (searchQuery.isEmpty) {
      return currentResources;
    }

    return currentResources.where((item) {
      return item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item.description?.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ) ??
              false);
    }).toList();
  }

  // 获取指定类型的资源数量
  int getResourceCountByType(ResourceType type) {
    return resources[type]?.length ?? 0;
  }

  // 创建新的状态对象
  LibraryState copyWith({
    Map<ResourceType, List<LibraryItem>>? resources,
    ResourceType? selectedType,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    bool clearError = false,
  }) {
    return LibraryState(
      resources: resources ?? this.resources,
      selectedType: selectedType ?? this.selectedType,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Library控制器
class LibraryController extends StateNotifier<LibraryState> {
  final LibraryService libraryService;

  LibraryController(this.libraryService)
    : super(
        LibraryState(
          resources: {for (var type in ResourceType.values) type: []},
        ),
      );

  // 初始化加载资源
  Future<void> loadResources() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await libraryService.loadResources();

      // 构建按类型分类的资源Map
      final Map<ResourceType, List<LibraryItem>> resourcesByType = {
        for (var type in ResourceType.values)
          type: libraryService.getResourcesByType(type),
      };

      state = state.copyWith(resources: resourcesByType, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '加载资源失败: $e');
    }
  }

  // 设置选中的资源类型
  void setSelectedType(ResourceType? type) {
    state = state.copyWith(selectedType: type);
  }

  // 添加新资源
  Future<bool> addResource(ResourceType type, {String? customTitle}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final item = await libraryService.pickAndAddResource(
        type,
        customTitle: customTitle,
      );

      if (item != null) {
        // 重新加载所有资源，确保数据一致性
        await loadResources();
        return true;
      } else {
        state = state.copyWith(isLoading: false);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '导入资源失败: $e');
      return false;
    }
  }

  // 删除资源
  Future<bool> removeResource(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final success = await libraryService.removeResource(id);

      if (success) {
        // 重新加载所有资源，确保数据一致性
        await loadResources();
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: '无法删除资源');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '删除资源失败: $e');
      return false;
    }
  }

  // 更新搜索关键词
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // 清除搜索
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}
