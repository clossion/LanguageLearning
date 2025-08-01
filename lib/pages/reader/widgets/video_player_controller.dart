import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:math' as math;
import 'package:frontend/pages/reader/controller/reader_provider.dart';
import 'package:frontend/pages/reader/controller/reader_video_provider.dart';

class VideoControllerWidget extends ConsumerWidget {
  const VideoControllerWidget({super.key});

  // 比例常量 - 所有尺寸都将基于这些比例计算
  static const double _baseHeight = 70; // 基础高度
  static const double _paddingRatio = 0.05; // 内边距比例
  static const double _progressBarHeightRatio = 0.07; // 进度条高度比例
  static const double _playBtnSizeRatio = 0.5; // 播放按钮尺寸占总高度的比例
  static const double _controlBtnSizeRatio = 0.5; // 控制按钮尺寸占总高度的比例
  static const double _iconSizeRatio = 0.3; // 图标尺寸占总高度的比例
  static const double _spacingRatio = 0.02; // 间距比例

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(videoPlayerProvider);
    final playbackSpeed = ref.watch(playbackSpeedProvider);
    final loopMode = ref.watch(loopModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用空间计算实际尺寸
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;
        
        // 计算缩放因子 (基于高度)
        final scaleFactor = availableHeight / _baseHeight;
        
        // 计算实际尺寸
        final padding = _baseHeight * _paddingRatio * scaleFactor;
        final progressBarHeight = _baseHeight * _progressBarHeightRatio * scaleFactor;
        final playBtnSize = _baseHeight * _playBtnSizeRatio * scaleFactor;
        final controlBtnSize = _baseHeight * _controlBtnSizeRatio * scaleFactor;
        final iconSize = _baseHeight * _iconSizeRatio * scaleFactor;
        final spacing = _baseHeight * _spacingRatio * scaleFactor;
        
        // 字体大小比例
        final timeTextSize = 11 * scaleFactor * 0.9;
        final speedTextSize = 12 * scaleFactor * 0.9;
        
        return Container(
          width: availableWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20 * scaleFactor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.15),
                blurRadius: 8 * scaleFactor,
                offset: Offset(0, 2 * scaleFactor),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildProgressBar(ref, player, progressBarHeight, scaleFactor),
              
              SizedBox(height: spacing / 2),
              
              // 控制按钮
              Row(
                children: [
                  _buildPlayPauseButton(player, playBtnSize, iconSize),
                  SizedBox(width: spacing),
                  
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimeText(player, isCurrentTime: true, textSize: timeTextSize),
                        SizedBox(width: spacing),
                        
                        _buildControlButton(
                          icon: Icons.replay_5,
                          tooltip: '后退5秒',
                          onPressed: () => _rewind(player),
                          size: controlBtnSize,
                          iconSize: iconSize,
                        ),
                        
                        _buildControlButton(
                          icon: Icons.forward_5,
                          tooltip: '前进5秒',
                          onPressed: () => _fastForward(player),
                          size: controlBtnSize,
                          iconSize: iconSize,
                        ),
                        
                        _buildControlButton(
                          icon: Icons.repeat,
                          tooltip: '循环播放',
                          isActive: loopMode,
                          onPressed: () => _toggleLoop(ref, player),
                          size: controlBtnSize,
                          iconSize: iconSize,
                        ),
                        
                        _buildControlButton(
                          icon: Icons.speed,
                          tooltip: '倍速播放',
                          isActive: playbackSpeed != 1.0,
                          customChild: Text(
                            '${playbackSpeed}x',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: speedTextSize,
                            ),
                          ),
                          onPressed: () => _cyclePlaybackSpeed(ref, player),
                          size: controlBtnSize,
                          iconSize: iconSize,
                        ),
                        
                        SizedBox(width: spacing),
                        _buildTimeText(player, isCurrentTime: false, textSize: timeTextSize),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: spacing),
                  
                  _buildControlButton(
                    icon: Icons.close,
                    tooltip: '关闭视频',
                    onPressed: () {
                      player.pause();
                      final pos = player.state.position;
                      ref.read(readerProvider.notifier).rememberVideoPos(pos);
                      ref.read(readerProvider.notifier).toggleVideoComponents();
                    },
                    size: controlBtnSize,
                    iconSize: iconSize,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 构建进度条
  Widget _buildProgressBar(WidgetRef ref, Player player, double height, double scaleFactor) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, pSnap) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, dSnap) {
            final pos  = pSnap.data ?? Duration.zero;
            final dur  = dSnap.data ?? Duration.zero;
            final max  = dur.inMilliseconds > 0
                ? dur.inMilliseconds.toDouble()
                : math.max(1.0, pos.inMilliseconds.toDouble());
            final value = pos.inMilliseconds.toDouble().clamp(0.0, max);

            final cs = Theme.of(context).colorScheme;
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6 * scaleFactor),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12 * scaleFactor),
                trackHeight: height,
                activeTrackColor: cs.primary,
                thumbColor: cs.primary,
                inactiveTrackColor: cs.primary.withOpacity(.3),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: max,
                onChanged: (v) {
                  final seekTo = Duration(milliseconds: v.toInt());
                  player.seek(seekTo);
                  ref.read(readerProvider.notifier).rememberVideoPos(seekTo);
                },
              ),
            );
          },
        );
      },
    );
  }

  // 构建播放/暂停按钮
  Widget _buildPlayPauseButton(Player player, double size, double iconSize) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF050D18),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: iconSize,
            ),
            onPressed: () {
              isPlaying ? player.pause() : player.play();
            },
          ),
        );
      },
    );
  }

  // 构建控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required double size,
    required double iconSize,
    Widget? customChild,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            color: isActive ? Colors.black.withOpacity(0.05) : Colors.transparent,
          ),
          child: Center(
            child: customChild ?? Icon(
              icon,
              size: iconSize,
              color: const Color(0xFF050D18),
            ),
          ),
        ),
      ),
    );
  }

  // 构建时间文字
  Widget _buildTimeText(Player player, {required bool isCurrentTime, required double textSize}) {
    return StreamBuilder<Duration>(
      stream: isCurrentTime ? player.stream.position : player.stream.duration,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? Duration.zero;
        return SizedBox(
          width: textSize * 3.5,
          child: Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: textSize,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  // 后退5秒
  void _rewind(Player player) {
    final currentPosition = player.state.position;
    final newPosition = currentPosition - const Duration(seconds: 5);
    player.seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  // 快进5秒
  void _fastForward(Player player) {
    final currentPosition = player.state.position;
    player.seek(currentPosition + const Duration(seconds: 5));
  }

  // 循环切换播放速度
  void _cyclePlaybackSpeed(WidgetRef ref, Player player) {
    final currentSpeed = ref.read(playbackSpeedProvider);
    double newSpeed;
    
    if (currentSpeed == 1.0) {
      newSpeed = 1.5;
    } else if (currentSpeed == 1.5) {
      newSpeed = 2.0;
    } else {
      newSpeed = 1.0;
    }
    
    player.setRate(newSpeed);
    ref.read(playbackSpeedProvider.notifier).state = newSpeed;
  }

  // 切换循环模式
  void _toggleLoop(WidgetRef ref, Player player) {
    final currentLoop = ref.read(loopModeProvider);
    player.setPlaylistMode(currentLoop ? PlaylistMode.none : PlaylistMode.single);
    ref.read(loopModeProvider.notifier).state = !currentLoop;
  }

  // 格式化时间
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}