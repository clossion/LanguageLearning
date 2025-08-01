import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

// 创建全局Player实例
final videoPlayerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(() {
    player.dispose();
  });
  return player;
});

// 播放速度提供者
final playbackSpeedProvider = StateProvider<double>((ref) => 1.0);

// 循环播放提供者
final loopModeProvider = StateProvider<bool>((ref) => false);