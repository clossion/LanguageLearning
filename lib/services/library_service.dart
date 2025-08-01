import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

// 资源类型枚举
enum ResourceType { video, ebook, audio, other }

// 扩展ResourceType以获取显示名称和图标
extension ResourceTypeExtension on ResourceType {
  String get displayName {
    switch (this) {
      case ResourceType.video:
        return '影视';
      case ResourceType.ebook:
        return '电子书';
      case ResourceType.audio:
        return '音频';
      case ResourceType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceType.video:
        return Icons.movie;
      case ResourceType.ebook:
        return Icons.book;
      case ResourceType.audio:
        return Icons.audiotrack;
      case ResourceType.other:
        return Icons.insert_drive_file;
    }
  }

  // 获取对应的文件扩展名列表
  List<String> get fileExtensions {
    switch (this) {
      case ResourceType.video:
        return ['mp4', 'avi', 'mkv', 'ts', 'webm', 'mov'];
      case ResourceType.ebook:
        return ['pdf', 'epub', 'mobi', 'txt', 'docx', 'rtf'];
      case ResourceType.audio:
        return ['mp3', 'wav', 'ogg', 'flac', 'm4a'];
      case ResourceType.other:
        return [];
    }
  }
}

// 资源项目类
class LibraryItem {
  final String id;
  final String title;
  final String filePath;
  final ResourceType type;
  final DateTime dateAdded;

  // 可选属性
  final String? description;
  final String? thumbnailPath;
  final String? subtitlePath; 

  LibraryItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.type,
    required this.dateAdded,
    this.description,
    this.thumbnailPath,
    this.subtitlePath, 
  });

  // 从JSON创建LibraryItem
  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'],
      title: json['title'],
      filePath: json['filePath'],
      type: ResourceType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ResourceType.other,
      ),
      dateAdded: DateTime.parse(json['dateAdded']),
      description: json['description'],
      thumbnailPath: json['thumbnailPath'],
      subtitlePath: json['subtitlePath']
    );
  }

  // 添加copyWith方法
  LibraryItem copyWith({
    String? id,
    String? title,
    String? filePath,
    ResourceType? type,
    DateTime? dateAdded,
    String? description,
    String? thumbnailPath,
    String? subtitlePath,
  }) {
    return LibraryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      dateAdded: dateAdded ?? this.dateAdded,
      description: description ?? this.description,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      subtitlePath: subtitlePath ?? this.subtitlePath, 
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'type': type.toString(),
      'dateAdded': dateAdded.toIso8601String(),
      'description': description,
      'thumbnailPath': thumbnailPath,
      'subtitlePath': subtitlePath
    };
  }
}

// 图书馆服务类，用于管理所有资源
class LibraryService {
  // 按类型分组的资源列表
  final Map<ResourceType, List<LibraryItem>> _resources = {
    for (var type in ResourceType.values) type: [],
  };

  // 获取按类型筛选的资源列表
  List<LibraryItem> getResourcesByType(ResourceType type) {
    return _resources[type] ?? [];
  }

  // 获取所有资源
  List<LibraryItem> getAllResources() {
    List<LibraryItem> allItems = [];
    _resources.forEach((_, items) => allItems.addAll(items));
    return allItems;
  }

  // 添加资源
  Future<bool> addResource(LibraryItem item) async {
    try {
      // 将资源添加到对应类型的列表中
      _resources[item.type]!.add(item);

      // 保存更新后的资源列表
      await _saveResources();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 删除资源
  Future<bool> removeResource(String id) async {
    try {
      bool removed = false;
      _resources.forEach((type, items) {
        items.removeWhere((item) {
          if (item.id == id) {
            removed = true;
            return true;
          }
          return false;
        });
      });

      if (removed) {
        await _saveResources();
      }
      return removed;
    } catch (e) {
      return false;
    }
  }

  // 更新资源
  Future<bool> updateResource(LibraryItem updatedItem) async {
    try {
      // 查找并替换资源
      final itemsList = _resources[updatedItem.type]!;
      final index = itemsList.indexWhere((item) => item.id == updatedItem.id);
      
      if (index >= 0) {
        itemsList[index] = updatedItem;
        await _saveResources();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 从SharedPreferences加载资源
  Future<void> loadResources() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 清空现有资源
      _resources.forEach((key, _) => _resources[key] = []);

      // 按类型加载资源
      for (var type in ResourceType.values) {
        final String key = 'resources_${type.toString()}';
        final List<String>? jsonList = prefs.getStringList(key);

        if (jsonList != null) {
          _resources[type] =
              jsonList
                  .map((jsonStr) => LibraryItem.fromJson(jsonDecode(jsonStr)))
                  .toList();
        }
      }
    } catch (e) {
      debugPrint('加载资源失败: $e');
    }
  }

  // 保存资源到SharedPreferences
  Future<void> _saveResources() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 按类型保存资源
      for (var type in ResourceType.values) {
        final String key = 'resources_${type.toString()}';
        final List<String> jsonList =
            _resources[type]!.map((item) => jsonEncode(item.toJson())).toList();

        await prefs.setStringList(key, jsonList);
      }
    } catch (e) {
      debugPrint('保存资源失败: $e');
    }
  }

  // 选择文件并添加到资源库
  Future<LibraryItem?> pickAndAddResource(
    ResourceType type, {
    String? customTitle,
  }) async {
    try {
      // 设置文件选择器的过滤条件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type.fileExtensions,
        dialogTitle: '选择${type.displayName}文件',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        return null;
      }

      final filePath = file.path!;
      final fileName = customTitle ?? path.basename(filePath);
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // 创建新的资源项
      final newItem = LibraryItem(
        id: id,
        title: fileName,
        filePath: filePath,
        type: type,
        dateAdded: DateTime.now(),
      );

      // 添加到资源库
      final success = await addResource(newItem);
      return success ? newItem : null;
    } catch (e) {
      debugPrint('选择文件失败: $e');
      return null;
    }
  }
}
