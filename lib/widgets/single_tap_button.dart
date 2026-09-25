import 'package:flutter/material.dart';

//Autor: Josue Hernandez
class SingleTapButton extends StatefulWidget {
  final Widget child;
  final Function() onPressed;

  const SingleTapButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<SingleTapButton> createState() => _SingleTapButtonState();
}

class _SingleTapButtonState extends State<SingleTapButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isPressed
          ? null
          : () async {
              setState(() => _isPressed = true);
              await widget.onPressed();
              if (mounted) setState(() => _isPressed = false);
            },
      style: widget.child is Text
          ? TextButton.styleFrom(
              backgroundColor: const Color(0xFF0886B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            )
          : null,
      child: widget.child,
    );
  }
} 