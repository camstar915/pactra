import 'package:flutter/material.dart';
import 'package:pactra/components/pact_list.dart';
import 'package:pactra/pages/create_pact_page.dart';
import 'package:pactra/pages/join_pact_page.dart';
import 'package:pactra/pages/account_page.dart';
import 'package:pactra/main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  List<dynamic> _pactParticipants = [];

  @override
  void initState() {
    super.initState();
    _checkUsername();
  }

  Future<void> _checkUsername() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      // Handle the case where the user is not logged in
      return;
    }

    final data = await supabase
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .single();

    if (data['username'] == null || data['username'].isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AccountPage()),
        );
      }
    } else {
      await _fetchPacts();
    }
  }

// In HomePage's _fetchPacts() method

  Future<void> _fetchPacts() async {
    setState(() {
      _loading = true;
    });

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      setState(() {
        _pactParticipants = [];
        _loading = false;
      });
      return;
    }

    try {
      final response = await supabase.from('pact_participants').select('''
          status,
          role,
          pact: pacts (
            *,
            created_by,
            participants: pact_participants (
              status
            )
          )
        ''').eq('user_id', userId).neq('status', 'declined');

      setState(() {
        _pactParticipants = response;
        _loading = false;
      });
    } catch (error) {
      print('Error fetching pacts: $error');
      setState(() {
        _pactParticipants = [];
        _loading = false;
      });
    }
  }

  void _navigateToCreatePact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePactPage()),
    );
    if (result == true) {
      // Trigger refresh in HomePage
      await _fetchPacts();
    }
  }

  Future<void> _refreshPacts() async {
    await _fetchPacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pactra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JoinPactPage()),
              );
            },
            tooltip: 'Join Pact',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshPacts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PactList(
                    pactParticipants: _pactParticipants,
                    currentUserId: supabase.auth.currentUser!.id,
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePact,
        child: const Icon(Icons.add),
      ),
    );
  }
}
