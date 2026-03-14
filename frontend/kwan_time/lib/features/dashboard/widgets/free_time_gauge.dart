import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FreeTimeGauge extends ConsumerWidget {
  const FreeTimeGauge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Free Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Coming soon!', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}
