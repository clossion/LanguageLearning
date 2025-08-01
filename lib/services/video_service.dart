// lib/services/video_service.dart
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 视频管理服务，处理视频播放、控制和状态管理
class VideoService {
  // 视频控制器
  Player? _player;
  VideoController? _videoController;

  // 播放速度
  double playbackSpeed = 1.0;

  // 视频信息
  String currentVideoPath = '';
  Duration videoDuration = Duration.zero;
  Duration videoPosition = Duration.zero;

  // 视频状态
  bool isPlaying = false;
  bool isVideoLoaded = false;
  bool isBuffering = false;

  // 状态更新回调
  final Function(VideoService)? onStateChanged;

  // 位置更新回调
  final Function(Duration)? onPositionChanged;

  // 消息回调
  final Function(String)? onMessage;

  // 位置更新定时器
  Timer? _positionTimer;

  VideoService({this.onStateChanged, this.onPositionChanged, this.onMessage});

  /// 加载视频文件
  Future<bool> loadVideo(String videoPath) async {
    try {
      // 释放旧的控制器
      await dispose();

      currentVideoPath = videoPath;

      // 创建新的视频播放器
      _player = Player();
      _videoController = VideoController(_player!);
      
      // 加载视频
      await _player!.open(Media(videoPath));

      // 获取视频总时长
      _player!.stream.duration.listen((duration) {
        videoDuration = duration;
        if (onStateChanged != null) {
          onStateChanged!(this);
        }
      });

      // 更新状态
      isVideoLoaded = true;
      isPlaying = false;

      // 监听位置变化
      _startPositionTimer();

      // 监听播放状态变化
      _player!.stream.playing.listen((playing) {
        isPlaying = playing;
        if (onStateChanged != null) {
          onStateChanged!(this);
        }
      });
      
      _player!.stream.buffering.listen((buffering) {
        isBuffering = buffering;
        if (onStateChanged != null) {
          onStateChanged!(this);
        }
      });

      // 通知状态更新
      if (onStateChanged != null) {
        onStateChanged!(this);
      }

      return true;
    } catch (e) {
      if (onMessage != null) {
        onMessage!('加载视频错误: $e');
      }
      return false;
    }
  }

  /// 开始位置更新定时器
  void _startPositionTimer() {
    _positionTimer?.cancel();

    _positionTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (_player != null) {
        _player!.stream.position.first.then((position) {
          videoPosition = position;
          if (onPositionChanged != null) {
            onPositionChanged!(videoPosition);
          }
        });
      }
    });
  }

  /// 播放
  Future<void> play() async {
    if (_player == null || !isVideoLoaded) return;

    await _player!.play();
    isPlaying = true;

    if (onStateChanged != null) {
      onStateChanged!(this);
    }
  }

  /// 暂停
  Future<void> pause() async {
    if (_player == null || !isVideoLoaded) return;

    await _player!.pause();
    isPlaying = false;

    if (onStateChanged != null) {
      onStateChanged!(this);
    }
  }

  /// 切换播放/暂停状态
  Future<void> togglePlayPause() async {
    if (_player == null || !isVideoLoaded) return;

    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 设置播放速度
  Future<void> setPlaybackSpeed(double speed) async {
    if (_player == null || !isVideoLoaded) return;

    await _player!.setRate(speed);
    playbackSpeed = speed;

    if (onStateChanged != null) {
      onStateChanged!(this);
    }
  }

  /// 跳转到指定时间
  Future<void> seekTo(Duration position) async {
    if (_player == null || !isVideoLoaded) return;

    await _player!.seek(position);
    videoPosition = position;

    if (onPositionChanged != null) {
      onPositionChanged!(position);
    }

    if (onStateChanged != null) {
      onStateChanged!(this);
    }
  }

  /// 跳转并播放
  Future<void> seekToAndPlay(Duration position) async {
    await seekTo(position);
    await play();
  }

  /// 获取视频总时长字符串
  String getDurationString() {
    final int hours = videoDuration.inHours;
    final int minutes = videoDuration.inMinutes % 60;
    final int seconds = videoDuration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 获取当前位置字符串
  String getPositionString() {
    final int hours = videoPosition.inHours;
    final int minutes = videoPosition.inMinutes % 60;
    final int seconds = videoPosition.inSeconds % 60;

    if (hours > 0 || videoDuration.inHours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 向前快进
  Future<void> fastForward(Duration amount) async {
    if (_player == null || !isVideoLoaded) return;

    final newPosition = videoPosition + amount;
    await seekTo(newPosition);
  }

  /// 向后快退
  Future<void> rewind(Duration amount) async {
    if (_player == null || !isVideoLoaded) return;

    final newPosition = videoPosition - amount;
    await seekTo(newPosition.inMilliseconds > 0 ? newPosition : Duration.zero);
  }

  /// 清理资源
  Future<void> dispose() async {
    _positionTimer?.cancel();

    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }
    
    _videoController = null;
    isVideoLoaded = false;
    isPlaying = false;
    isBuffering = false;

    currentVideoPath = '';
    videoDuration = Duration.zero;
    videoPosition = Duration.zero;
  }
  
  /// 获取视频控制器 - 用于在UI中显示视频
  VideoController? get videoController => _videoController;
}