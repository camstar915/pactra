import 'package:flutter/material.dart';

class ProgressSummary extends StatelessWidget {
  final List<Map<String, dynamic>> pacts;

  const ProgressSummary({super.key, required this.pacts});

  @override
  Widget build(BuildContext context) {
    final totalPacts = pacts.length;
    final completedPacts =
        pacts.where((pact) => pact['status'] == 'completed').length;
    final successRate = totalPacts > 0
        ? (completedPacts / totalPacts * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, 'Total Pacts', totalPacts.toString()),
                _buildStatItem(context, 'Completed', completedPacts.toString()),
                _buildStatItem(context, 'Success Rate', '$successRate%'),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalPacts > 0 ? completedPacts / totalPacts : 0,
              backgroundColor: Colors.grey[300],
              valueColor:
                  AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
