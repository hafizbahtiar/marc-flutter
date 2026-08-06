import 'package:flutter/material.dart';

/// Kandungan butang semasa loading: spinner kecil + teks, sewarna teks butang.
class ButtonBusy extends StatelessWidget {
  const ButtonBusy({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator.adaptive(),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
