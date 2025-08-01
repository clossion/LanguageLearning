import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/library_service.dart';
import 'library_state.dart';

// 创建LibraryService提供者
final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

// 创建Library状态提供者
final libraryProvider = StateNotifierProvider<LibraryController, LibraryState>((
  ref,
) {
  final service = ref.watch(libraryServiceProvider);
  return LibraryController(service);
});

// 创建当前选定资源类型提供者(方便快速访问)
final selectedResourceTypeProvider = Provider<ResourceType?>((ref) {
  return ref.watch(libraryProvider).selectedType;
});

// 创建当前过滤后资源列表提供者(方便快速访问)
final filteredResourcesProvider = Provider<List<LibraryItem>>((ref) {
  return ref.watch(libraryProvider).getFilteredResources();
});

// 每种类型对应的资源数量提供者
final resourceCountProvider = Provider.family<int, ResourceType>((ref, type) {
  return ref.watch(libraryProvider).getResourceCountByType(type);
});
