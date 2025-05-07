import 'package:flutter/material.dart';
import 'dart:math';

class PoseProgressPainter extends CustomPainter {
  final List<PoseStatus> statuses;
  final double strokeWidth;

  PoseProgressPainter({
    required this.statuses,
    this.strokeWidth = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final anglePerSlice = 2 * pi / statuses.length;

    for (int i = 0; i < statuses.length; i++) {
      final startAngle = -pi / 2 + i * anglePerSlice;
      final sweepAngle = anglePerSlice;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = _getColorForStatus(statuses[i]);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  Color _getColorForStatus(PoseStatus status) {
    switch (status) {
      case PoseStatus.notStarted:
        return Colors.grey;
      case PoseStatus.detecting:
        return Colors.yellow;
      case PoseStatus.completed:
        return Colors.green;
      case PoseStatus.holding:
        return Colors.red;
        throw UnimplementedError();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum PoseStatus {
  notStarted,
  detecting,
  holding,
  completed,
}

