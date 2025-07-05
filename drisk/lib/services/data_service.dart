import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drisk/models/dream_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A service class to handle data import and export operations.
class DataService {
  // --- EXPORT LOGIC ---

  /// Shows a confirmation dialog before starting the export process.
  void showExportDialog(BuildContext context) {
    final box = Hive.box<Dream>('dreams');
    if (box.values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("There are no dreams to export."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Dreams'),
        content: const Text(
            'This will create a CSV file containing all your dream data. You can use this file as a backup.\n\nNote: Voice memos are not included in this export and must be backed up separately.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Export'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _exportDreamsToCsv(context);
            },
          ),
        ],
      ),
    );
  }

  /// Gathers data, converts it to CSV, and shares it.
  Future<void> _exportDreamsToCsv(BuildContext context) async {
    try {
      final box = Hive.box<Dream>('dreams');
      final List<Dream> dreams = box.values.toList();
      final List<List<dynamic>> rows = [];

      // Add CSV headers
      rows.add([
        'id',
        'title',
        'description',
        'date',
        'mood',
        'type',
        'thrillLevel',
        'clarity',
        'tags',
        'isFavorite',
        'recurringDreamGroupId',
        'voiceMemoPath'
      ]);

      // Convert each dream to a row
      for (final dream in dreams) {
        rows.add([
          dream.id,
          dream.title,
          dream.description,
          dream.date.toIso8601String(),
          dream.mood.name,
          dream.type.name,
          dream.thrillLevel,
          dream.clarity,
          dream.tags.join('|'), // Use a pipe to separate tags
          dream.isFavorite ?? false,
          dream.recurringDreamGroupId ?? '',
          dream.voiceMemoPath ?? '',
        ]);
      }

      // Convert rows to a CSV string
      final String csv = const ListToCsvConverter().convert(rows);

      // Save to a temporary file
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/dream_journal_backup_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // Use the share dialog to let the user save the file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'My Dream Journal Backup',
        subject: 'Dream Journal Backup',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- IMPORT LOGIC ---

  /// Shows a dialog explaining the import process before starting.
  Future<void> showImportDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Dreams'),
        content: const Text(
            'Select a CSV file to import dreams. This will not overwrite existing dreams with the same ID.\n\nNote: Voice memo audio files will not be imported.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Select File'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _importDreamsFromCsv(context);
            },
          ),
        ],
      ),
    );
  }

  /// Handles file picking, parsing, and adding new dreams to the database.
  Future<void> _importDreamsFromCsv(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null)
        return; // User canceled

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows =
          const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
              .convert(csvString);

      if (rows.length < 2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("The selected file is empty or invalid.")),
          );
        }
        return;
      }

      final box = Hive.box<Dream>('dreams');
      final existingIds = box.values.map((d) => d.id).toSet();
      final List<Dream> dreamsToImport = [];
      int failedRows = 0;

      // Start from 1 to skip header row
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 12) {
          failedRows++;
          continue;
        }

        try {
          final id = row[0].toString();
          if (existingIds.contains(id)) continue; // Skip duplicates

          final dream = Dream(
            id: id,
            title: row[1].toString(),
            description: row[2].toString(),
            date: DateTime.parse(row[3].toString()),
            mood: DreamMood.values.firstWhere(
                (e) => e.name == row[4].toString(),
                orElse: () => DreamMood.neutral),
            type: DreamType.values.firstWhere(
                (e) => e.name == row[5].toString(),
                orElse: () => DreamType.normal),
            thrillLevel: double.parse(row[6].toString()),
            clarity: double.parse(row[7].toString()),
            tags: row[8].toString().isEmpty ? [] : row[8].toString().split('|'),
            isFavorite: row[9].toString().toLowerCase() == 'true',
            recurringDreamGroupId:
                row[10].toString().isEmpty ? null : row[10].toString(),
            voiceMemoPath:
                row[11].toString().isEmpty ? null : row[11].toString(),
          );
          dreamsToImport.add(dream);
        } catch (e) {
          failedRows++;
          debugPrint('Failed to parse row $i: $row. Error: $e');
        }
      }

      if (dreamsToImport.isEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No new dreams found to import.")),
        );
        return;
      }

      if (context.mounted) {
        _showImportConfirmation(context, dreamsToImport, failedRows);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Import failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows a final confirmation with the number of dreams found before adding them.
  void _showImportConfirmation(
      BuildContext context, List<Dream> dreams, int failedRows) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text("Found ${dreams.length} new dreams to import." +
            (failedRows > 0 ? "\n($failedRows rows could not be read.)" : "") +
            "\n\nDo you want to add them to your journal?"),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Import'),
            onPressed: () async {
              final box = Hive.box<Dream>('dreams');
              await box.addAll(dreams);
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text("Successfully imported ${dreams.length} dreams!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
