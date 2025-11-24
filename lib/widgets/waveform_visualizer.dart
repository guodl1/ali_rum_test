import 'dart:math';
import 'package:flutter/material.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;

  const WaveformVisualizer({
    Key? key,
    required this.isPlaying,
    required this.color,
    this.barCount = 30,
  }) : super(key: key);

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  List<double> _currentHeights = [];
  List<double> _targetHeights = [];
  List<double> _previousHeights = [];

  @override
  void initState() {
    super.initState();
    _initializeHeights();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Update every 0.25s (2x speed)
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _updateTargets();
        _controller.forward(from: 0.0);
      }
    });

    _controller.addListener(() {
      setState(() {
        // Interpolate between previous and target heights
        for (int i = 0; i < widget.barCount; i++) {
          _currentHeights[i] = _lerpDouble(
            _previousHeights[i],
            _targetHeights[i],
            _controller.value,
          );
        }
      });
    });

    if (widget.isPlaying) {
      _controller.forward();
    }
  }

  void _initializeHeights() {
    _previousHeights = List.generate(widget.barCount, (_) => 0.1);
    _targetHeights = List.generate(widget.barCount, (_) => _random.nextDouble());
    _currentHeights = List.from(_previousHeights);
  }

  void _updateTargets() {
    _previousHeights = List.from(_targetHeights);
    _targetHeights = List.generate(widget.barCount, (_) => _random.nextDouble());
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.stop();
        setState(() {
          // Reset to low state smoothly or instantly? 
          // Instantly for responsiveness as per previous behavior
          _previousHeights = List.generate(widget.barCount, (_) => 0.1);
          _currentHeights = List.from(_previousHeights);
          _targetHeights = List.generate(widget.barCount, (_) => 0.1);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          double normalizedHeight = _currentHeights[index];
          
          // Apply a window function (Hanning-like) to taper ends
          double window = 0.5 * (1 - cos(2 * pi * index / (widget.barCount - 1)));
          
          double height = 4 + (100 * normalizedHeight * window);
          
          if (!widget.isPlaying) {
             height = 4 + (10 * window); 
          }

          return Container(
            width: 3,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
