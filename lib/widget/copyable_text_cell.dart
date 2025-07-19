import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableTextCell extends StatelessWidget {
  final String text;
  final String tooltip;

  const CopyableTextCell({
    Key? key,
    required this.text,
    required this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$tooltip copied')),
          );
        },
        child: Text(
          text,
        ),
      ),
    );
  }
}
