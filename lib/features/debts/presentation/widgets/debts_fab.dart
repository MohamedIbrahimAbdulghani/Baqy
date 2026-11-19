import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/debt_providers.dart';

class DebtsFab extends ConsumerWidget {
  const DebtsFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 56.0,
      height: 56.0,
      child: FloatingActionButton(
        heroTag: 'debts_fab',
        onPressed: () {
          final direction = ref.read(debtDirectionProvider);
          context.push('/add-debt', extra: direction);
        },
        backgroundColor: const Color(0xFF4A7C59),
        foregroundColor: Colors.white,
        elevation: 3.0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30.0),
      ),
    );
  }
}

