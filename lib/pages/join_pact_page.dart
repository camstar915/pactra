import 'package:flutter/material.dart';
import 'package:pactra/main.dart';

class JoinPactPage extends StatefulWidget {
  const JoinPactPage({super.key});

  @override
  State<JoinPactPage> createState() => _JoinPactPageState();
}

class _JoinPactPageState extends State<JoinPactPage> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinPact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final inviteCode = _inviteCodeController.text.trim();
    final userId = supabase.auth.currentUser!.id;

    try {
      // Fetch the invite code
      final response = await supabase
          .from('pact_invite_codes')
          .select('pact_id, expires_at')
          .eq('invite_code', inviteCode)
          .maybeSingle();

      if (response == null) {
        context.showSnackBar('Invalid invite code', isError: true);
        return;
      }

      final expiresAt = DateTime.parse(response['expires_at']);
      if (expiresAt.isBefore(DateTime.now().toUtc())) {
        context.showSnackBar('Invite code has expired', isError: true);
        return;
      }

      final pactId = response['pact_id'] as String;

      // Check if user is already a participant
      final existingParticipant = await supabase
          .from('pact_participants')
          .select('id')
          .eq('pact_id', pactId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingParticipant != null) {
        context.showSnackBar('You are already a participant of this pact');
        return;
      }

      // Add user to pact_participants
      await supabase.from('pact_participants').insert({
        'pact_id': pactId,
        'user_id': userId,
        'role': 'participant',
        'status': 'accepted',
      });

      if (mounted) {
        context.showSnackBar('Successfully joined the pact!');
        Navigator.of(context).pop(); // Return to previous screen
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Error joining pact', isError: true);
        print('Error joining pact: $error');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Pact'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text('Enter the invite code to join a pact:'),
                    const SizedBox(height: 16),
                    TextFormField(
                      textCapitalization: TextCapitalization.characters,
                      controller: _inviteCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Invite Code',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the invite code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _joinPact,
                      child: const Text('Join Pact'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
