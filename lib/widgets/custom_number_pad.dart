import 'package:flutter/material.dart';

class CustomNumberPad extends StatelessWidget {
  final Function(String) onNumber;
  final VoidCallback onClear;

  const CustomNumberPad({
    super.key,
    required this.onNumber,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildButton('7'),
                  _buildButton('8'),
                  _buildButton('9'),
                ],
              ),
              Row(
                children: [
                  _buildButton('4'),
                  _buildButton('5'),
                  _buildButton('6'),
                ],
              ),
              Row(
                children: [
                  _buildButton('1'),
                  _buildButton('2'),
                  _buildButton('3'),
                ],
              ),
              Row(
                children: [
                  _buildButton('C', isAction: true, onTap: onClear),
                  _buildButton('0'),
                  _buildButton('.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, {bool isAction = false, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Material(
          color: isAction ? Colors.red.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap ?? () => onNumber(text),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isAction ? Colors.redAccent : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
