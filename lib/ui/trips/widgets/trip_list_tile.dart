import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../data/trip.dart';
import '../../theme.dart';

class TripListTile extends StatelessWidget {
  const TripListTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onCategoryChanged,
  });

  final Trip trip;
  final VoidCallback onTap;
  final ValueChanged<TripCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat.jm();
    final from =
        trip.startAddress ??
        '${trip.startLat.toStringAsFixed(3)}, ${trip.startLng.toStringAsFixed(3)}';
    final to = trip.isOpen
        ? 'In progress…'
        : (trip.endAddress ??
              '${trip.endLat.toStringAsFixed(3)}, ${trip.endLng.toStringAsFixed(3)}');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: categoryColor(
          context,
          trip.category,
        ).withValues(alpha: 0.15),
        child: Icon(
          trip.autoDetected ? Icons.directions_car : Icons.edit_location_alt,
          color: categoryColor(context, trip.category),
          size: 20,
        ),
      ),
      title: Text('$from → $to', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        trip.isOpen
            ? 'Started ${timeFmt.format(trip.startTime)}'
            : '${timeFmt.format(trip.startTime)} – ${timeFmt.format(trip.endTime!)} · ${formatDuration(trip.duration!)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${trip.distanceKm.toStringAsFixed(1)} km',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (!trip.isOpen)
            _CategoryMenu(
              category: trip.category,
              onChanged: onCategoryChanged,
            ),
        ],
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.category, required this.onChanged});

  final TripCategory category;
  final ValueChanged<TripCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TripCategory>(
      initialValue: category,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final c in TripCategory.values)
          PopupMenuItem(value: c, child: Text(c.label)),
      ],
      child: Chip(
        label: Text(category.label, style: const TextStyle(fontSize: 11)),
        backgroundColor: categoryColor(
          context,
          category,
        ).withValues(alpha: 0.15),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
