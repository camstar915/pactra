import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pactra/main.dart';
import 'package:pactra/pages/invite_partners_page.dart';
import 'package:pactra/components/pact_calendar.dart';

class PactDetailsPage extends StatefulWidget {
  final String pactId;
  final Function(String) onPactUpdated; // Add this callback

  const PactDetailsPage({
    Key? key,
    required this.pactId,
    required this.onPactUpdated, // Add this parameter
  }) : super(key: key);

  @override
  State<PactDetailsPage> createState() => _PactDetailsPageState();
}

class _PactDetailsPageState extends State<PactDetailsPage> {
  Map<String, dynamic>? _pact;
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;

  String? _userResponse; // For one-time pact response
  Map<String, String> _userResponses = {}; // For recurring pact responses

  Map<String, dynamic>? _userStats; // Holds user's stats (for recurring pacts)

  @override
  void initState() {
    super.initState();
    _loadPactDetails();
  }

  Future<void> _loadPactDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      // Fetch pact data with participants
      final pactResponse = await supabase.from('pacts').select('''
            *,
            participants: pact_participants (
              id,
              user_id,
              role,
              status,
              profiles!pact_participants_user_id_fkey (
                username
              )
            )
          ''').eq('id', widget.pactId).single();

      final pactData = pactResponse;

      // Check if the pact is a one-time pact
      final isOnce = pactData['frequency'] == 'Once';

      if (isOnce) {
        // Fetch any response the user has submitted for this pact
        final responseData = await supabase
            .from('pact_responses')
            .select('response')
            .eq('pact_id', widget.pactId)
            .eq('user_id', userId)
            .maybeSingle();

        setState(() {
          _pact = pactData;
          _participants =
              List<Map<String, dynamic>>.from(pactData['participants'] ?? []);
          _userResponse =
              responseData != null ? responseData['response'] : null;
        });
      } else {
        // For recurring pacts, fetch all user responses
        final responsesData = await supabase
            .from('pact_responses')
            .select('occurrence_date, response')
            .eq('pact_id', widget.pactId)
            .eq('user_id', userId);

        // Process responses
        _userResponses = {
          for (var r in responsesData)
            r['occurrence_date'] as String: r['response'] as String
        };

        // Fetch user's stats for recurring pacts
        final userStatsResponse = await supabase.rpc(
          'get_user_pact_stats',
          params: {'p_pact_id': widget.pactId, 'p_user_id': userId},
        );

        if (userStatsResponse is List && userStatsResponse.isNotEmpty) {
          _userStats = Map<String, dynamic>.from(userStatsResponse[0]);
        }

        setState(() {
          _pact = pactData;
          _participants =
              List<Map<String, dynamic>>.from(pactData['participants'] ?? []);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pact details: $error'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error loading pact details: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnce = _pact != null && _pact!['frequency'] == 'Once';

    return Scaffold(
      appBar: AppBar(
        title: Text(_pact != null ? _pact!['name'] : 'Pact Details'),
        actions: [
          if (_isCreator())
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deletePact,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pact == null
              ? const Center(child: Text('Pact not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pact!['description'] ?? 'No description provided'),
                      const SizedBox(height: 16),

                      // Display frequency and dates
                      Text('Frequency: ${_pact!['frequency']}'),
                      Text(isOnce
                          ? 'Date: ${_formatDate(_pact!['start_date'])}'
                          : 'Start Date: ${_formatDate(_pact!['start_date'])}'),
                      if (!isOnce && _pact!['end_date'] != null)
                        Text('End Date: ${_formatDate(_pact!['end_date'])}'),

                      const SizedBox(height: 24),

                      // Response section
                      if (isOnce)
                        _buildOneTimeResponseSection()
                      else
                        _buildRecurringResponseSection(),

                      const SizedBox(height: 24),

                      // Calendar (only for recurring pacts)
                      if (!isOnce) ...[
                        const SizedBox(height: 8),
                        PactCalendar(
                          userResponses: _userResponses,
                          startDate: DateTime.parse(_pact!['start_date']),
                          endDate: _pact!['end_date'] != null
                              ? DateTime.parse(_pact!['end_date'])
                              : null,
                          onDateSelected: _onCalendarDateSelected,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Stats (only for recurring pacts)
                      if (!isOnce && _userStats != null) ...[
                        const SizedBox(height: 8),
                        _buildStatsCard(_userStats!),
                        const SizedBox(height: 24),
                      ],

                      // Accountability Partners Section
                      Text(
                        'Accountability Partners',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          if (participant['user_id'] == _pact!['created_by']) {
                            return const SizedBox.shrink();
                          }
                          return ListTile(
                            title: Text(participant['profiles']['username']),
                            // Removed the 'participant' subtitle
                            trailing: _isCreator()
                                ? TextButton(
                                    onPressed: () => _removeParticipant(
                                        participant['id'],
                                        participant['user_id']),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                    ),
                                    child: const Text('Remove'),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_isCreator())
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _navigateToInvitePartners,
                            icon: const Icon(Icons.share),
                            label: const Text('Invite'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOneTimeResponseSection() {
    if (_userResponse == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Response',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _submitUserResponse('completed'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Completed'),
              ),
              ElevatedButton(
                onPressed: () => _submitUserResponse('missed'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Missed'),
              ),
              ElevatedButton(
                onPressed: () => _submitUserResponse('skipped'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Skipped'),
              ),
            ],
          ),
        ],
      );
    } else {
      return _buildFinalResponseCard(_userResponse!, isOnce: true);
    }
  }

  Widget _buildFinalResponseCard(String response, {bool isOnce = false}) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!isOnce) ...[
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
              ],
              Icon(
                _getResultIcon(response),
                size: 48,
                color: _getResultColor(response),
              ),
              const SizedBox(height: 16),
              Text(
                response.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _getResultColor(response),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringResponseSection() {
    return Container(
      width: double.infinity,
      child: _buildTodayResponseSection(),
    );
  }

  Widget _buildTodayResponseSection() {
    final todayString = _formatDateToYMD(DateTime.now());
    final todayResponse = _userResponses[todayString];

    return todayResponse != null
        ? _buildFinalResponseCard(todayResponse)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "How did you do today?",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              _buildResponseButtons(),
            ],
          );
  }

  Widget _buildResponseButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _submitUserResponse('completed'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Completed'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _submitUserResponse('missed'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Missed'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _submitUserResponse('skipped'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Skip'),
        ),
      ],
    );
  }

  /// Submits the user's response to Supabase with onConflict handling
  Future<void> _submitUserResponse(String response, {DateTime? date}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final isOnce = _pact!['frequency'] == 'Once';

      DateTime responseDate;
      if (isOnce) {
        responseDate = DateTime.parse(_pact!['start_date']);
      } else {
        responseDate = date ?? DateTime.now();
      }

      final formattedDate = _formatDateToYMD(responseDate);

      await supabase.from('pact_responses').upsert(
        {
          'pact_id': widget.pactId,
          'user_id': userId,
          'occurrence_date': formattedDate,
          'response': response,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'pact_id,user_id,occurrence_date',
      );

      // Update local state
      if (isOnce) {
        setState(() {
          _userResponse = response;
        });
      } else {
        setState(() {
          _userResponses[formattedDate] = response;
        });
      }

      // After successful submission, call the callback
      widget.onPactUpdated(widget.pactId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting response: $error'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error submitting response: $error');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper function to format frequency
  String _formatFrequency(Map<String, dynamic> pact) {
    final frequency = pact['frequency'];
    if (frequency == 'Once') {
      return 'Once';
    } else if (frequency == 'Daily') {
      return 'Daily';
    } else if (frequency == 'Weekly') {
      final days = pact['selected_days'] ?? [];
      return 'Weekly on ${days.join(', ')}';
    } else if (frequency == 'Monthly') {
      return 'Monthly';
    } else if (frequency == 'Custom') {
      final interval = pact['custom_frequency_interval'];
      final unit = pact['custom_frequency_unit'];
      return 'Every $interval ${interval == 1 ? unit.toLowerCase().substring(0, unit.length - 1) : unit.toLowerCase()}';
    } else {
      return 'Unknown';
    }
  }

  bool _isCreator() {
    final userId = supabase.auth.currentUser?.id;
    return _pact != null && _pact!['created_by'] == userId;
  }

  Future<void> _deletePact() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pact'),
        content: const Text(
            'Are you sure you want to delete this pact? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Delete the pact
        await supabase.from('pacts').delete().eq('id', widget.pactId);

        // Navigate back
        if (mounted) {
          Navigator.of(context).pop(); // Return to the previous screen
        }
      } catch (error) {
        if (mounted) {
          context.showSnackBar('Error deleting pact', isError: true);
          print('Error deleting pact: $error');
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeParticipant(
      dynamic participantId, String? participantUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content:
            const Text('Are you sure you want to remove this participant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Delete the participant from pact_participants
        await supabase
            .from('pact_participants')
            .delete()
            .eq('id', participantId);

        if (participantUserId != null) {
          // Delete any pact_responses by this user for this pact
          await supabase
              .from('pact_responses')
              .delete()
              .eq('pact_id', widget.pactId)
              .eq('user_id', participantUserId);
        }

        // Reload the pact details
        await _loadPactDetails();

        if (mounted) {
          context.showSnackBar('Participant removed successfully');
        }
      } catch (error) {
        if (mounted) {
          context.showSnackBar('Error removing participant', isError: true);
          print('Error removing participant: $error');
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToInvitePartners() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvitePartnersPage(pactId: widget.pactId),
      ),
    );
    // Reload pact details after returning
    _loadPactDetails();
  }

  // New method to handle date selection from the calendar
  void _onCalendarDateSelected(DateTime selectedDate) async {
    // Show dialog to select new response
    final newResponse = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Edit Response for ${DateFormat('MMMM d, yyyy').format(selectedDate)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('completed'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Completed'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('missed'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Missed'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('skipped'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Skipped'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (newResponse != null) {
      await _submitUserResponse(newResponse, date: selectedDate);
    }
  }

  bool _isSelectedResponse(String response) {
    final isOnce = _pact!['frequency'] == 'Once';
    if (isOnce) {
      return _userResponse == response;
    } else {
      final todayString = _formatDateToYMD(DateTime.now());
      return _userResponses[todayString] == response;
    }
  }

  IconData _getResultIcon(String response) {
    switch (response) {
      case 'completed':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      case 'skipped':
        return Icons.skip_next;
      default:
        return Icons.help_outline;
    }
  }

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

  String _formatDateToYMD(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Method to build stats card
  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Completed', stats['total_completed']),
            _buildStatRow('Missed', stats['total_missed']),
            _buildStatRow('Skipped', stats['total_skipped']),
            _buildStatRow('Success Rate', '${stats['success_rate']}%'),
          ],
        ),
      ),
    );
  }

  // Helper method to build individual stat rows
  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          Text(value.toString(), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('MMMM d, yyyy').format(date);
  }
}
