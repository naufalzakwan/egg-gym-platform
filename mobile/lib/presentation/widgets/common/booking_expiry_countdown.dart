import 'dart:async';

import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookingExpiryCountdown extends StatefulWidget {
  const BookingExpiryCountdown({
    super.key,
    required this.expiredAt,
    required this.label,
    this.onExpired,
  });

  final DateTime? expiredAt;
  final String label;
  final FutureOr<void> Function()? onExpired;

  @override
  State<BookingExpiryCountdown> createState() => _BookingExpiryCountdownState();
}

class _BookingExpiryCountdownState extends State<BookingExpiryCountdown> {
  Timer? _timer;
  bool _refreshTriggered = false;

  Duration get _remaining {
    final deadline = widget.expiredAt;
    if (deadline == null) return Duration.zero;
    final value = deadline.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant BookingExpiryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiredAt != widget.expiredAt) {
      _refreshTriggered = false;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.expiredAt == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == Duration.zero && !_refreshTriggered) {
        _refreshTriggered = true;
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiredAt == null) return const SizedBox.shrink();
    final remaining = _remaining;
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '${widget.label}: $hours:$minutes:$seconds',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                remaining == Duration.zero ? AppColors.error : AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
