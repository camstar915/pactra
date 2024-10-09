import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pactra/main.dart';
import 'dart:math';

class InvitePartnersPage extends StatefulWidget {
  final String pactId;

  const InvitePartnersPage({super.key, required this.pactId});

  @override
  State<InvitePartnersPage> createState() => _InvitePartnersPageState();
}

class _InvitePartnersPageState extends State<InvitePartnersPage> {
  String? _inviteCode;
  bool _isLoading = true;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
  }

  Future<void> _loadInviteCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if there's an existing invite code that is not expired
      final response = await supabase
          .from('pact_invite_codes')
          .select('invite_code, expires_at')
          .eq('pact_id', widget.pactId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final expiresAt = DateTime.parse(response['expires_at']);
        if (expiresAt.isAfter(DateTime.now().toUtc())) {
          // Existing invite code is valid
          setState(() {
            _inviteCode = response['invite_code'];
            _expiresAt = expiresAt;
          });
        } else {
          // Existing invite code is expired, generate a new one
          await _generateInviteCode();
        }
      } else {
        // No existing invite code, generate a new one
        await _generateInviteCode();
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Error loading invite code', isError: true);
        print('Error loading invite code: $error');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateInviteCode({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = supabase.auth.currentUser!.id;

      // Generate a unique invite code
      final inviteCode = _generateRandomCode();

      // Set expiration date (e.g., 3 days from now)
      final expiresAt = DateTime.now().add(const Duration(days: 3));

      // Insert the invite code into the database
      await supabase.from('pact_invite_codes').insert({
        'pact_id': widget.pactId,
        'invite_code': inviteCode,
        'created_by': userId,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      });

      setState(() {
        _inviteCode = inviteCode;
        _expiresAt = expiresAt;
      });
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Error generating invite code', isError: true);
        print('Error generating invite code: $error');
      }
    } finally {
      if (showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[Random().nextInt(chars.length)])
        .join();
  }

  void _shareInviteCode() {
    if (_inviteCode != null) {
      final message =
          'Join my pact on Pactra! Use this invite code: $_inviteCode';
      Share.share(message);
    }
  }

  void _regenerateInviteCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate New Invite Code'),
        content: const Text(
            'Are you sure you want to generate a new invite code? The previous code will no longer be valid.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _generateInviteCode();
    }
  }

  String _formatExpirationDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays >= 1) {
      return '${difference.inDays} day(s)';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hour(s)';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute(s)';
    } else {
      return 'less than a minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expirationText = _expiresAt != null
        ? 'This invite code will expire in ${_formatExpirationDate(_expiresAt!)}'
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Partners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Generate New Invite Code',
            onPressed: _regenerateInviteCode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inviteCode == null
              ? const Center(child: Text('Failed to load invite code'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Share this invite code with your partners:'),
                      const SizedBox(height: 8),
                      SelectableText(
                        _inviteCode!,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _shareInviteCode,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Invite Code'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        expirationText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
    );
  }
}
