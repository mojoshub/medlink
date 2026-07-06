import 'package:flutter/material.dart';

class PhoneButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final double? elevation;
  final double? iconSize;
  final String label;
  final String heroTag;

  const PhoneButton({
    super.key,
    required this.onPressed,
    this.backgroundColor = Colors.red,
    this.icon = Icons.phone,
    this.elevation,
    this.iconSize,
    this.label = 'Call',
    this.heroTag = 'phoneFab',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: heroTag,
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          elevation: elevation,
          child: Icon(
            icon,
            size: iconSize,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
