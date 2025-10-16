import 'package:flutter/material.dart';

class TypingAnimation extends StatefulWidget {
  final String text;
  final Duration speed;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const TypingAnimation({
    super.key,
    required this.text,
    this.speed = const Duration(milliseconds: 50),
    this.style,
    this.onComplete,
  });

  @override
  State<TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<TypingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  String _displayText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.text.length * widget.speed.inMilliseconds),
      vsync: this,
    );

    _animation = IntTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _animation.addListener(() {
      if (mounted) {
        setState(() {
          _currentIndex = _animation.value;
          _displayText = widget.text.substring(0, _currentIndex);
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onComplete != null) {
        widget.onComplete!();
      }
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: _displayText,
        style: widget.style ?? const TextStyle(
          color: Colors.black,
          fontFamily: 'Poppins',
        ),
        children: [
          if (_currentIndex < widget.text.length)
            TextSpan(
              text: '|',
              style: TextStyle(
                color: widget.style?.color ?? Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AnimatedTextReveal extends StatefulWidget {
  final String text;
  final Duration duration;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const AnimatedTextReveal({
    super.key,
    required this.text,
    this.duration = const Duration(milliseconds: 800),
    this.style,
    this.onComplete,
  });

  @override
  State<AnimatedTextReveal> createState() => _AnimatedTextRevealState();
}

class _AnimatedTextRevealState extends State<AnimatedTextReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Text(
              widget.text,
              style: widget.style ?? const TextStyle(
                color: Colors.black,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
