import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pactra/main.dart';
import 'invite_partners_page.dart';

class CreatePactPage extends StatefulWidget {
  const CreatePactPage({super.key});

  @override
  State<CreatePactPage> createState() => _CreatePactPageState();
}

class _CreatePactPageState extends State<CreatePactPage> {
  final _formKey = GlobalKey<FormState>();

  // Stepper current step
  int _currentStep = 0;

  // Controllers and variables to store user inputs
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  String _selectedFrequency = 'Once';
  final List<String> _frequencies = [
    'Once',
    'Daily',
    'Weekly',
    'Monthly',
    'Custom'
  ];
  final List<String> _selectedDays = [];
  TimeOfDay? _selectedTime;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isIndefinite = false;

  // For custom frequency
  String _customFrequencyUnit = 'Days';
  int _customFrequencyInterval = 1;
  final List<String> _frequencyUnits = ['Days', 'Weeks', 'Months'];

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  // Function to pick time
  Future<void> _pickTime() async {
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  // Function to pick date
  Future<void> _pickDate({required bool isStartDate}) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2100);

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          isStartDate ? (_startDate ?? initialDate) : (_endDate ?? initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  // Function to create pact
  void _createPact() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userId = supabase.auth.currentUser!.id;

      // Prepare pact data
      final pactData = {
        'created_by': userId,
        'name': _nameController.text,
        'description': _goalController.text,
        'frequency': _selectedFrequency,
        'custom_frequency_interval':
            _selectedFrequency == 'Custom' ? _customFrequencyInterval : null,
        'custom_frequency_unit':
            _selectedFrequency == 'Custom' ? _customFrequencyUnit : null,
        'selected_days': _selectedFrequency == 'Weekly' ? _selectedDays : null,
        'time_of_day': _selectedTime != null
            ? '${_selectedTime!.hour}:${_selectedTime!.minute}'
            : null,
        'start_date': _startDate != null
            ? _startDate!.toIso8601String()
            : DateTime.now().toIso8601String(),
        'end_date': !_isIndefinite && _endDate != null
            ? _endDate!.toIso8601String()
            : null,
        'is_indefinite': _isIndefinite,
        'time_zone': DateTime.now().timeZoneName,
      };

      // Insert pact into database
      final pactResponse =
          await supabase.from('pacts').insert(pactData).select().single();
      final pactId = pactResponse['id'];

      // Add creator as a participant
      await supabase.from('pact_participants').insert({
        'pact_id': pactId,
        'user_id': userId,
        'role': 'creator',
        'status': 'accepted',
        'created_by': userId,
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Pact Created'),
            content: const Text('Your pact has been created successfully!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog

                  // Navigate to InvitePartnersPage
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvitePartnersPage(pactId: pactId),
                    ),
                  );
                },
                child: const Text('Invite Friends'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Error creating pact', isError: true);
        print('Error creating pact: $error');
      }
    }
  }

  // Weekday names
  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Pact'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep += 1;
              });
            } else {
              // Last step, create pact
              _createPact();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep -= 1;
              });
            } else {
              Navigator.pop(context);
            }
          },
          onStepTapped: (int index) {
            setState(() {
              _currentStep = index;
            });
          },
          steps: [
            // Step 1: Goal Description
            Step(
              title: const Text('Pact'),
              content: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name for your pact';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _goalController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            // Step 2: Set Frequency and Schedule
            Step(
              title: const Text('Set Frequency and Schedule'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: _frequencies
                        .map((freq) =>
                            DropdownMenuItem(value: freq, child: Text(freq)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFrequency = value!;
                        _selectedDays.clear();
                        _customFrequencyInterval = 1;
                        _customFrequencyUnit = 'Days';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedFrequency == 'Once') ...[
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(_startDate != null
                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                          : 'No date selected'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickDate(isStartDate: true),
                    ),
                  ] else ...[
                    if (_selectedFrequency == 'Weekly') _buildWeeklySelection(),
                    if (_selectedFrequency == 'Custom') _buildCustomFrequency(),
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_startDate != null
                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                          : 'No start date selected'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _pickDate(isStartDate: true),
                    ),
                    SwitchListTile(
                      title: const Text('Indefinite Pact'),
                      value: _isIndefinite,
                      onChanged: (value) {
                        setState(() {
                          _isIndefinite = value;
                        });
                      },
                    ),
                    if (!_isIndefinite)
                      ListTile(
                        title: const Text('End Date'),
                        subtitle: Text(_endDate != null
                            ? DateFormat('yyyy-MM-dd').format(_endDate!)
                            : 'No end date selected'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _pickDate(isStartDate: false),
                      ),
                  ],
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Select Time (Optional)'),
                    subtitle: Text(_selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'No time selected'),
                    trailing: const Icon(Icons.access_time),
                    onTap: _pickTime,
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            // Step 3: Review and Confirm
            Step(
              title: const Text('Review and Confirm'),
              content: _buildReviewSection(),
              isActive: _currentStep >= 2,
              state: _currentStep == 2 ? StepState.indexed : StepState.complete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _nameController.text,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (_goalController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_goalController.text),
        ],
        const SizedBox(height: 16),
        if (_selectedFrequency == 'Once') ...[
          Text('One-time pact'),
          const SizedBox(height: 8),
          Text(
              'To be completed on ${DateFormat('MMMM d, yyyy').format(_startDate!)}'),
        ] else ...[
          Text(_getFrequencyText()),
          const SizedBox(height: 8),
          Text('Starting on ${DateFormat('MMMM d, yyyy').format(_startDate!)}'),
          if (_isIndefinite)
            const Text('Continuing indefinitely')
          else if (_endDate != null)
            Text('Ending on ${DateFormat('MMMM d, yyyy').format(_endDate!)}'),
        ],
        if (_selectedTime != null) ...[
          const SizedBox(height: 8),
          Text('At ${_selectedTime!.format(context)}'),
        ],
      ],
    );
  }

  String _getFrequencyText() {
    switch (_selectedFrequency) {
      case 'Daily':
        return 'Every day';
      case 'Weekly':
        return 'Every week on ${_selectedDays.join(", ")}';
      case 'Monthly':
        return 'Every month';
      case 'Custom':
        return 'Every $_customFrequencyInterval ${_customFrequencyInterval == 1 ? _customFrequencyUnit.toLowerCase().substring(0, _customFrequencyUnit.length - 1) : _customFrequencyUnit.toLowerCase()}';
      default:
        return '';
    }
  }

  Widget _buildWeeklySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Days:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 5.0,
          children: _weekdays.map((day) {
            return FilterChip(
              label: Text(day),
              selected: _selectedDays.contains(day),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomFrequency() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _customFrequencyInterval.toString(),
            decoration: const InputDecoration(labelText: 'Every'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null ||
                  int.tryParse(value) == null ||
                  int.parse(value) < 1) {
                return 'Enter a valid number';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _customFrequencyInterval = int.tryParse(value) ?? 1;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _customFrequencyUnit,
            decoration: InputDecoration(
              labelText: _customFrequencyInterval == 1 ? 'Unit' : 'Units',
            ),
            items: _frequencyUnits.map((unit) {
              String label = unit;
              if (_customFrequencyInterval == 1) {
                if (unit == 'Days') label = 'Day';
                if (unit == 'Weeks') label = 'Week';
                if (unit == 'Months') label = 'Month';
              }
              return DropdownMenuItem(value: unit, child: Text(label));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _customFrequencyUnit = value!;
              });
            },
          ),
        ),
      ],
    );
  }
}
