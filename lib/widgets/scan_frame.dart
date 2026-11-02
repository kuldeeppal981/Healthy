import 'package:flutter/material.dart';

import '../theme.dart';

/// Soft panel with corner brackets and text lines, shown on the photo scan screen.
class ScanFrame extends StatelessWidget {
  const ScanFrame({super.key});

  Widget _corner({bool top = true, bool left = true}) {
    final side = BorderSide(color: AppColors.primary, width: 4);
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            top: top ? side : BorderSide.none,
            bottom: top ? BorderSide.none : side,
            left: left ? side : BorderSide.none,
            right: left ? BorderSide.none : side,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top && left ? 14 : 0),
            topRight: Radius.circular(top && !left ? 14 : 0),
            bottomLeft: Radius.circular(!top && left ? 14 : 0),
            bottomRight: Radius.circular(!top && !left ? 14 : 0),
          ),
        ),
      ),
    );
  }

  Widget _line(double f) => FractionallySizedBox(
        widthFactor: f,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: SizedBox(
          width: 220,
          height: 150,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_line(1), _line(0.8), _line(1), _line(0.6)],
                  ),
                ),
              ),
              _corner(top: true, left: true),
              _corner(top: true, left: false),
              _corner(top: false, left: true),
              _corner(top: false, left: false),
            ],
          ),
        ),
      ),
    );
  }
}
