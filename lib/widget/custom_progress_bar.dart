import 'package:flutter/material.dart';

class CustomProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color completedColor;
  final Color remainingColor;
  final double borderRadius;

  const CustomProgressBar({
    super.key,
    required this.progress,
    this.height = 10.0,
    this.completedColor = Colors.blue,
    this.remainingColor = Colors.grey,
    this.borderRadius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double completedWidth = totalWidth * progress.clamp(0.0, 1.0);
        final double remainingWidth = totalWidth - completedWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            height: height,
            child: Row(
              children: <Widget>[
                // 已完成部分
                Container(
                  width: completedWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: completedColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                // 未完成部分 (如果需要明确显示，但通常由背景色表示)
                // 如果需要明确的两个组件，可以这样：
                if (progress > 0.0 || progress < 1.0) SizedBox(width: 2),
                Expanded(
                  child: Container(
                    width: remainingWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: remainingColor,
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
