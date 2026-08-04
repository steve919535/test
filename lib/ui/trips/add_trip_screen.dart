import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';

/// Manual trip entry, for trips automatic tracking missed (tracking was
/// off, phone was off, etc.) or historical trips from before the app was
/// installed.
class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _distanceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  TripCategory _category = TripCategory.business;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _distanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final startTime = _combine(_date, _startTime);
    var endTime = _combine(_date, _endTime);
    if (!endTime.isAfter(startTime)) {
      endTime = endTime.add(const Duration(days: 1));
    }

    final distanceKm = double.parse(_distanceController.text.trim());
    final trip = Trip(
      startTime: startTime,
      endTime: endTime,
      startLat: 0,
      startLng: 0,
      endLat: 0,
      endLng: 0,
      startAddress: _fromController.text.trim().isEmpty
          ? null
          : _fromController.text.trim(),
      endAddress: _toController.text.trim().isEmpty
          ? null
          : _toController.text.trim(),
      distanceMeters: distanceKm * 1000,
      category: _category,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      autoDetected: false,
    );

    await context.read<TripRepository>().insertManualTrip(trip);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add trip'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(dateFmt.format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_startTime.format(context)),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_endTime.format(context)),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distanceController,
              decoration: const InputDecoration(
                labelText: 'Distance (km)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a distance greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TripCategory>(
              segments: const [
                ButtonSegment(
                  value: TripCategory.business,
                  label: Text('Business'),
                ),
                ButtonSegment(
                  value: TripCategory.personal,
                  label: Text('Personal'),
                ),
                ButtonSegment(
                  value: TripCategory.unclassified,
                  label: Text('Unset'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (selection) =>
                  setState(() => _category = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
