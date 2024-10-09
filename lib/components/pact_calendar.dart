// pact_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

typedef DateSelectedCallback = void Function(DateTime date);

class PactCalendar extends StatefulWidget {
  final Map<String, String> userResponses;
  final DateTime startDate;
  final DateTime? endDate;
  final DateSelectedCallback? onDateSelected; // Add this line

  const PactCalendar({
    Key? key,
    required this.userResponses,
    required this.startDate,
    this.endDate,
    this.onDateSelected, // Add this line
  }) : super(key: key);

  @override
  _PactCalendarState createState() => _PactCalendarState();
}

class _PactCalendarState extends State<PactCalendar> {
  late final DateTime _firstDay;
  late final DateTime _lastDay;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();

    _firstDay = widget.startDate;
    _lastDay = widget.endDate ?? DateTime.now().add(const Duration(days: 365));

    if (_focusedDay.isBefore(_firstDay)) {
      _focusedDay = _firstDay;
    } else if (_focusedDay.isAfter(_lastDay)) {
      _focusedDay = _lastDay;
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    final dayString = _formatDateToYMD(day);
    final response = widget.userResponses[dayString];
    if (response != null) {
      return [response];
    }
    return [];
  }

  Widget? _buildMarkers(
      BuildContext context, DateTime day, List<dynamic> events) {
    if (events.isEmpty) return null;

    final response = events.first as String;
    final color = _getResponseColor(response);

    return Positioned(
      right: 1,
      bottom: 1,
      child: Icon(
        _getResponseIcon(response),
        color: color,
        size: 16,
      ),
    );
  }

  Color _getResponseColor(String response) {
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

  IconData _getResponseIcon(String response) {
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

  String _formatDateToYMD(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return TableCalendar(
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
      },
      eventLoader: _getEventsForDay,
      calendarBuilders: CalendarBuilders(
        markerBuilder: _buildMarkers,
        disabledBuilder: (context, day, focusedDay) {
          return Center(
            child: Text(
              '${day.day}',
              style: TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
      enabledDayPredicate: (day) {
        // Disable days after today
        return !day.isAfter(DateTime(
          today.year,
          today.month,
          today.day,
        ));
      },
      onDaySelected: (selectedDay, focusedDay) {
        if (!selectedDay.isAfter(DateTime(
          today.year,
          today.month,
          today.day,
        ))) {
          setState(() {
            _focusedDay = focusedDay;
          });
          if (widget.onDateSelected != null) {
            widget.onDateSelected!(selectedDay);
          }
        }
      },
    );
  }
}
