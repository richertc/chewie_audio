import 'dart:async';

import 'package:chewie_audio/src/animated_play_pause.dart';
import 'package:chewie_audio/src/chewie_player.dart';
import 'package:chewie_audio/src/chewie_progress_colors.dart';
import 'package:chewie_audio/src/material_progress_bar.dart';
import 'package:chewie_audio/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MaterialControls extends StatefulWidget {
  const MaterialControls({
    this.backgroundColor,
    this.iconColor,
    Key? key,
  }) : super(key: key);

  final Color? backgroundColor;
  final Color? iconColor;

  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<MaterialControls>
    with SingleTickerProviderStateMixin {
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;

  final barHeight = 48.0;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieAudioController? _chewieController;
  // We know that _chewieController is set in didChangeDependencies
  ChewieAudioController get chewieController => _chewieController!;

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
        context,
        chewieController.videoPlayerController.value.errorDescription,
      ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    final iconColor = widget.iconColor ?? Theme.of(context).colorScheme.secondary;

    return _buildBottomBar(context, iconColor);
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _chewieController;
    _chewieController = ChewieAudioController.of(context);
    controller = chewieController.videoPlayerController;

    if (_oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Container _buildBottomBar(
      BuildContext context,
      Color iconColor,
      ) {
    return Container(
      height: barHeight,
      color: widget.backgroundColor ?? Theme.of(context).dialogBackgroundColor,
      child: Row(
        children: <Widget>[
          _buildPlayPause(controller, iconColor),
          if (chewieController.isLive)
            const Expanded(child: Text('LIVE'))
          else
            _buildPosition(),
          if (chewieController.isLive)
            const SizedBox()
          else
            _buildProgressBar(),
          if (chewieController.allowPlaybackSpeedChanging)
            _buildSpeedButton(controller),
          if (chewieController.allowMuting) _buildMuteButton(controller),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(
      VideoPlayerController controller,
      ) {
    return GestureDetector(
      onTap: () async {
        final chosenSpeed = await showModalBottomSheet<double>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) => _PlaybackSpeedDialog(
            speeds: chewieController.playbackSpeeds,
            selected: _latestValue.playbackSpeed,
          ),
        );

        if (chosenSpeed != null) {
          controller.setPlaybackSpeed(chosenSpeed);
        }
      },
      child: ClipRect(
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: const Icon(Icons.speed),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
      VideoPlayerController controller,
      ) {
    return GestureDetector(
      onTap: () {
        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: ClipRect(
        child: Container(
          height: barHeight,
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: Icon(
            _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(VideoPlayerController controller, Color iconColor) {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: const EdgeInsets.only(left: 8.0, right: 4.0),
        padding: const EdgeInsets.only(
          left: 12.0,
          right: 12.0,
        ),
        child: AnimatedPlayPause(
          color: iconColor,
          playing: controller.value.isPlaying,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: Text(
        '${formatDuration(position)} / ${formatDuration(duration)}',
        style: const TextStyle(
          fontSize: 14.0,
        ),
      ),
    );
  }

  Future<void> _initialize() async {
    controller.addListener(_updateState);

    _updateState();
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(const Duration());
          }
          controller.play();
        }
      }
    });
  }

  void _updateState() {
    setState(() {
      _latestValue = controller.value;
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0),
        child: MaterialVideoProgressBar(
          controller,
          onDragStart: () {},
          onDragEnd: () {},
          colors: chewieController.materialProgressColors ??
              ChewieProgressColors(
                playedColor: Theme.of(context).colorScheme.secondary,
                handleColor: Theme.of(context).colorScheme.secondary,
                bufferedColor: Theme.of(context).backgroundColor.withOpacity(0.5),
                backgroundColor: Theme.of(context).disabledColor.withOpacity(.5),
              ),
        ),
      ),
    );
  }
}

class _PlaybackSpeedDialog extends StatelessWidget {
  const _PlaybackSpeedDialog({
    Key? key,
    required List<double> speeds,
    required double selected,
  })   : _speeds = speeds,
        _selected = selected,
        super(key: key);

  final List<double> _speeds;
  final double _selected;

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = Theme.of(context).primaryColor;

    return ListView.builder(
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      itemBuilder: (context, index) {
        final _speed = _speeds[index];
        return ListTile(
          dense: true,
          title: Row(
            children: [
              if (_speed == _selected)
                Icon(
                  Icons.check,
                  size: 20.0,
                  color: selectedColor,
                )
              else
                Container(width: 20.0),
              const SizedBox(width: 16.0),
              Text(_speed.toString()),
            ],
          ),
          selected: _speed == _selected,
          onTap: () {
            Navigator.of(context).pop(_speed);
          },
        );
      },
      itemCount: _speeds.length,
    );
  }
}
