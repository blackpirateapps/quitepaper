import 'package:flutter/material.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';

enum NotesCommand { newNote, newFromTemplate }

/// Uses the application's spotlight presentation and the same creation handlers
/// as the notes menu. The baseline had the primitive, but no command registry.
Future<NotesCommand?> showNotesCommandPalette(BuildContext context) =>
    QuietAdaptiveModal.show<NotesCommand>(
      context: context,
      type: AdaptiveModalType.spotlight,
      builder: (_) => const _NotesCommandPalette(),
    );

class _NotesCommandPalette extends StatefulWidget {
  const _NotesCommandPalette();
  @override
  State<_NotesCommandPalette> createState() => _NotesCommandPaletteState();
}

class _NotesCommandPaletteState extends State<_NotesCommandPalette> {
  String _query = '';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search commands'),
          onChanged: (value) => setState(() {
            _query = value.trim().toLowerCase();
          }),
        ),
        for (final command in NotesCommand.values)
          if ((command == NotesCommand.newNote
                  ? 'New Note'
                  : 'New from Template')
              .toLowerCase()
              .contains(_query))
            ListTile(
              leading: Icon(
                command == NotesCommand.newNote
                    ? Icons.add
                    : Icons.description_outlined,
              ),
              title: Text(
                command == NotesCommand.newNote
                    ? 'New Note'
                    : 'New from Template',
              ),
              onTap: () => Navigator.pop(context, command),
            ),
      ],
    ),
  );
}
