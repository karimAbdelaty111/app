import 'package:flutter/material.dart';

import '../database/note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(note.createdAt),
    );
    final today = DateTime.now();
    final dateLabel = DateUtils.isSameDay(note.createdAt, today)
        ? 'Today'
        : DateUtils.isSameDay(
            note.createdAt,
            today.subtract(const Duration(days: 1)),
          )
        ? 'Yesterday'
        : localizations.formatShortDate(note.createdAt);
    final dateTimeLabel = note.isEdited
        ? 'Edited $dateLabel · $time'
        : '$dateLabel · $time';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shadowColor: const Color(0x14000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.content,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    if (note.hasLocation) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              note.locationName ?? 'Location saved',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                    ],
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 15, color: mutedColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            dateTimeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 6),
            child: IconButton(
              onPressed: onDelete,
              tooltip: 'Delete note',
              icon: const Icon(Icons.delete_outline),
              color: mutedColor,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
