import 'package:flutter/material.dart';
import 'package:pactra/pages/pact_details_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class PactList extends StatefulWidget {
  final List<dynamic> pactParticipants;
  final String currentUserId;

  const PactList({
    Key? key,
    required this.pactParticipants,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _PactListState createState() => _PactListState();
}

class _PactListState extends State<PactList> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> pactResponses = {};
  bool _isLoading = true; // Add this line

  @override
  void initState() {
    super.initState();
    _fetchPactResponses();
  }

  /// Fetches stats for long-term pacts and responses for one-time pacts
  Future<void> _fetchPactResponses() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    final pactIds = widget.pactParticipants
        .map((p) => p['pact']['id'] as String)
        .toSet()
        .toList();

    print('Fetching data for pact IDs: $pactIds');

    try {
      final userId = widget.currentUserId;

      // Fetch stats for long-term pacts
      final data = await supabase.rpc(
        'get_user_pacts_stats',
        params: {'p_pact_ids': pactIds, 'p_user_id': userId},
      ) as List<dynamic>;

      print('Fetched long-term pact stats: $data');

      // Initialize the pactResponses map
      pactResponses = {};

      // Add stats to pactResponses
      for (var item in data) {
        pactResponses[item['pact_id']] = item;
      }

      print('pactResponses after adding long-term stats: $pactResponses');

      // Fetch responses for all pacts (including one-time pacts)
      final responses = await supabase
          .from('pact_responses')
          .select('pact_id, response')
          .eq('user_id', userId)
          .inFilter('pact_id', pactIds);

      print('Fetched pact responses: $responses');

      // Add responses to pactResponses
      for (var response in responses) {
        final pactId = response['pact_id'] as String;
        final responseValue = response['response'] as String;

        if (pactResponses.containsKey(pactId)) {
          pactResponses[pactId]['last_response'] = responseValue;
        } else {
          pactResponses[pactId] = {'last_response': responseValue};
        }
      }

      print('Final pactResponses: $pactResponses');
    } catch (error) {
      print('Error fetching pact stats or responses: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching pact stats or responses: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  /// Refreshes pact stats for a specific pact
  Future<void> _refreshPactStats(String pactId) async {
    final userId = supabase.auth.currentUser!.id;
    final stats = await supabase.rpc(
      'get_user_pact_stats',
      params: {'p_pact_id': pactId, 'p_user_id': userId},
    );

    if (stats != null && stats.isNotEmpty) {
      setState(() {
        pactResponses[pactId] = stats[0];
      });
    }
  }

  /// Builds each pact card with updated styling and content
  Widget _buildPactCard(BuildContext context, dynamic pactParticipant) {
    final pact = pactParticipant['pact'];
    final pactId = pact['id'] as String;
    final isOnce = pact['frequency'] == 'Once';

    // Ensure pactResponses contains data for this pactId
    if (!pactResponses.containsKey(pactId)) {
      return SizedBox.shrink(); // or a placeholder widget
    }

    final stats = pactResponses[pactId] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          pact['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pact['description'] != null && pact['description'].isNotEmpty)
              Text(
                pact['description'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 4),
            if (isOnce)
              _buildOneTimePactInfo(pact, pactId)
            else
              _buildLongTermPactInfo(pact, stats),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PactDetailsPage(
                pactId: pactId,
                onPactUpdated: _refreshPactStats,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds info for one-time pacts
  Widget _buildOneTimePactInfo(Map<String, dynamic> pact, String pactId) {
    final formattedDate = _formatDate(pact['start_date']);

    // Check if the user has responded
    final response = pactResponses[pactId]?['last_response'] as String?;

    if (response != null) {
      // User has responded
      return Row(
        children: [
          const Text('Result: '),
          Text(
            response.capitalize(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getResultColor(response),
            ),
          ),
        ],
      );
    } else {
      // No response yet
      return Row(
        children: [
          const Text('Due by: '),
          Text(
            formattedDate,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
  }

  /// Builds info for long-term pacts with a success rate chart
  Widget _buildLongTermPactInfo(
      Map<String, dynamic> pact, Map<String, dynamic> stats) {
    final successRate = stats['success_rate'] as num? ?? 0;
    final failureRate = 100 - successRate;
    final frequency = pact['frequency'] as String;

    final Color successColor = successRate > 50 ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          frequency,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Success Rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              children: [
                Text(
                  '${successRate.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: successColor,
                      ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: successRate.toDouble(),
                          color: successColor,
                          title: '',
                          radius: 12,
                        ),
                        PieChartSectionData(
                          value: failureRate.toDouble(),
                          color: Colors.red.withOpacity(0.5),
                          title: '',
                          radius: 12,
                        ),
                      ],
                      sectionsSpace: 0,
                      centerSpaceRadius: 0,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Gets color based on response type
  Color _getResultColor(String response) {
    switch (response) {
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Formats date string to MM/DD/YYYY
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    // Separate pacts into 'Your Pacts' and 'Your Friends' Pacts'
    final yourPacts = widget.pactParticipants.where((pactParticipant) {
      final pact = pactParticipant['pact'];
      return pact['created_by'] == widget.currentUserId;
    }).toList();

    final involvedPacts = widget.pactParticipants.where((pactParticipant) {
      final pact = pactParticipant['pact'];
      return pact['created_by'] != widget.currentUserId;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Pacts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (yourPacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('You haven\'t created any pacts yet.'),
              )
            else
              ...yourPacts
                  .map((pactParticipant) =>
                      _buildPactCard(context, pactParticipant))
                  .toList(),
            const SizedBox(height: 16),
            Text('Your Friends\' Pacts',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (involvedPacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('You\'re not involved in any friends\' pacts yet.'),
              )
            else
              ...involvedPacts
                  .map((pactParticipant) =>
                      _buildPactCard(context, pactParticipant))
                  .toList(),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  /// Capitalizes the first letter of a string
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
