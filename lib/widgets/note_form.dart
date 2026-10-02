import 'package:flutter/material.dart';

import '../database/note.dart';
import '../services/location_service.dart';

/// Stores the note built by [NoteForm].
///
/// Returns `true` when the note has been written to the database and `false`
/// when the save failed, in which case the form stays open and shows an error.
typedef NoteSaveCallback = Future<bool> Function(Note note);

/// Editor that is shared by the add and the edit note screen.
///
/// The form only collects the input and the optional location, persisting the
/// note is done by the screen that hosts the form.
class NoteForm extends StatefulWidget {
  const NoteForm({
    super.key,
    this.note,
    required this.onSave,
    this.locationService = const LocationService(),
  });

  /// The note that is edited, `null` when a new note is written.
  final Note? note;

  /// Called with the note to store when the user saves the form.
  final NoteSaveCallback onSave;

  final LocationService locationService;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;

  bool _attachLocation = false;
  DeviceLocation? _location;
  bool _isReadingLocation = false;
  bool _isSaving = false;
  bool _showValidationError = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _contentFocusNode = FocusNode();

    final note = widget.note;
    if (note != null && note.hasLocation) {
      _attachLocation = true;
      _location = DeviceLocation(
        latitude: note.latitude!,
        longitude: note.longitude!,
        accuracy: note.accuracy,
        name: note.locationName,
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  bool get _isBusy => _isReadingLocation || _isSaving;

  Future<void> _toggleLocation(bool attach) {
    if (!attach) {
      setState(() {
        _attachLocation = false;
        _location = null;
      });
      return Future<void>.value();
    }
    return _refreshLocation();
  }

  /// Reads the current position and attaches it to the form.
  ///
  /// A failure is explained to the user, in that case the form keeps its
  /// previous location.
  Future<void> _refreshLocation() async {
    setState(() {
      _isReadingLocation = true;
      _saveError = null;
    });
    final result = await widget.locationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() => _isReadingLocation = false);
    await _handleLocationResult(result);
  }

  Future<void> _handleLocationResult(LocationResult result) async {
    switch (result.outcome) {
      case LocationOutcome.success:
        setState(() {
          _attachLocation = true;
          _location = result.location;
        });
        return;
      case LocationOutcome.serviceDisabled:
        await _explainProblem(
          title: 'Location is turned off',
          message:
              'Switch on the location services of your device to attach '
              'your position to this note.',
          actionLabel: 'Open settings',
          onAction: widget.locationService.openLocationSettings,
        );
        return;
      case LocationOutcome.permissionDenied:
        final retry = await _explainProblem(
          title: 'Location permission denied',
          message:
              'The app needs the location permission to read your '
              'position. The note is saved without a location.',
          actionLabel: 'Try again',
        );
        if (retry) {
          await _refreshLocation();
        }
        return;
      case LocationOutcome.permissionDeniedForever:
        await _explainProblem(
          title: 'Location permission blocked',
          message:
              'The location permission was denied permanently. Grant it '
              'in the app settings to attach a position. The note is saved '
              'without a location.',
          actionLabel: 'Open app settings',
          onAction: widget.locationService.openAppSettings,
        );
        return;
      case LocationOutcome.failed:
        setState(
          () => _saveError =
              result.errorMessage ??
              'Your position could not be read, please try again.',
        );
        return;
    }
  }

  /// Shows a dialog that explains a location problem and optionally opens the
  /// matching settings page. Returns `true` when the user wants to continue.
  Future<bool> _explainProblem({
    required String title,
    required String message,
    required String actionLabel,
    Future<bool> Function()? onAction,
  }) async {
    final continueFlow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (continueFlow != true || !mounted) {
      return false;
    }
    await onAction?.call();
    return true;
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _showValidationError = true;
        _saveError = null;
      });
      _contentFocusNode.requestFocus();
      return;
    }
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _showValidationError = false;
      _saveError = null;
    });

    final now = DateTime.now();
    final location = _attachLocation ? _location : null;
    var saved = false;
    try {
      saved = await widget.onSave(
        Note(
          id: widget.note?.id,
          content: content,
          createdAt: widget.note?.createdAt ?? now,
          updatedAt: now,
          latitude: location?.latitude,
          longitude: location?.longitude,
          accuracy: location?.accuracy,
          locationName: location?.name,
        ),
      );
    } catch (error) {
      debugPrint('NoteForm: the note could not be saved - $error');
    }

    if (!mounted) {
      return;
    }
    if (!saved) {
      setState(() {
        _isSaving = false;
        _saveError = 'The note could not be saved, please try again.';
      });
      return;
    }
    // The list uses the result to know that it has to reload the notes.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = widget.note;
    final localizations = MaterialLocalizations.of(context);
    final date = note == null
        ? null
        : localizations.formatMediumDate(note.createdAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            note == null ? 'Capture a thought' : 'Your note',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            note == null
                ? 'Write it down before it slips away.'
                : '${note.isEdited ? 'Updated' : 'Created'} $date',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contentController,
            focusNode: _contentFocusNode,
            autofocus: widget.note == null,
            minLines: 10,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: 'Your note',
              hintText: 'Start writing...',
              alignLabelWithHint: true,
              errorText: _showValidationError
                  ? 'The note cannot be empty'
                  : null,
            ),
            onChanged: (_) {
              if (_showValidationError) {
                setState(() => _showValidationError = false);
              }
            },
          ),
          const SizedBox(height: 18),
          Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: _attachLocation,
              onChanged: _isBusy ? null : _toggleLocation,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Add location'),
              subtitle: Text(
                _isReadingLocation
                    ? 'Getting your current position...'
                    : 'Save where this note was written',
              ),
            ),
          ),
          if (_location != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location saved',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _location!.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Read location again',
                    onPressed: _isBusy ? null : _refreshLocation,
                  ),
                ],
              ),
            ),
          ],
          if (_saveError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isBusy ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(note == null ? Icons.add : Icons.check),
            label: Text(
              _isSaving
                  ? 'Saving...'
                  : note == null
                  ? 'Add note'
                  : 'Update note',
            ),
          ),
        ],
      ),
    );
  }
}
