import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drisk/models/dream_model.dart';
import 'package:drisk/screens/log_dream_page.dart';
import 'package:drisk/services/data_service.dart'; // <-- ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class DreamListPage extends StatelessWidget {
  const DreamListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate the service to use its methods
    final DataService dataService = DataService();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dream Journal'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // --- ADD ACTIONS MENU FOR IMPORT/EXPORT ---
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                dataService.showExportDialog(context);
              } else if (value == 'import') {
                dataService.showImportDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Export Data'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download_done_outlined),
                  title: Text('Import Data'),
                ),
              ),
            ],
          ),
        ],
        // ------------------------------------------
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Dream>('dreams').listenable(),
        builder: (context, Box<Dream> box, _) {
          if (box.values.isEmpty) {
            return const Center(
              child: Text(
                "Your dream journal is empty.\nLog a dream to begin!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          var dreams = box.values.toList();
          dreams.sort((a, b) => b.date.compareTo(a.date));
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: dreams.length,
            itemBuilder: (context, index) {
              final dream = dreams[index];
              return DreamCard(dream: dream);
            },
          );
        },
      ),
    );
  }
}

// ... THE REST OF THE FILE (DreamCard, _MemoPlayer, etc.) REMAINS UNCHANGED ...
class DreamCard extends StatelessWidget {
  final Dream dream;
  const DreamCard({super.key, required this.dream});

  IconData _getMoonIcon(DreamMood mood) {
    switch (mood) {
      case DreamMood.nightmare:
        return Icons.new_releases;
      case DreamMood.bad:
        return Icons.nightlight_round;
      case DreamMood.neutral:
        return Icons.circle;
      case DreamMood.good:
        return Icons.brightness_3;
      case DreamMood.excellent:
        return Icons.wb_sunny;
    }
  }

  Color _getMoodColor(DreamMood mood) {
    switch (mood) {
      case DreamMood.nightmare:
        return Colors.red[800]!;
      case DreamMood.bad:
        return Colors.orange[800]!;
      case DreamMood.neutral:
        return Colors.grey[600]!;
      case DreamMood.good:
        return Colors.lightBlue[300]!;
      case DreamMood.excellent:
        return Colors.yellow[400]!;
    }
  }

  void _showDreamDetails(BuildContext context, Dream dream) {
    // Create the player here. It will be disposed when the dialog is closed.
    final audioPlayer = AudioPlayer();
    bool isPlayerInitialized = false;

    if (dream.voiceMemoPath != null && dream.voiceMemoPath!.isNotEmpty) {
      final file = File(dream.voiceMemoPath!);
      if (file.existsSync()) {
        audioPlayer.setSourceDeviceFile(dream.voiceMemoPath!);
        isPlayerInitialized = true;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900]?.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          dream.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.yMMMMd().format(dream.date),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Text(dream.description),
              const SizedBox(height: 20),
              if (dream.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: dream.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (isPlayerInitialized) ...[
                const Divider(),
                _MemoPlayer(audioPlayer: audioPlayer),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmDelete(context, dream);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LogDreamPage(dreamToEdit: dream),
                ),
              );
            },
            child: const Text("Edit"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    ).whenComplete(() {
      // This is crucial. It ensures the player is always disposed
      // when the dialog is removed from the screen, for any reason.
      audioPlayer.dispose();
    });
  }

  void _confirmDelete(BuildContext context, Dream dream) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
          "Are you sure you want to delete this dream? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              if (dream.voiceMemoPath != null &&
                  dream.voiceMemoPath!.isNotEmpty) {
                try {
                  final audioFile = File(dream.voiceMemoPath!);
                  if (audioFile.existsSync()) {
                    audioFile.delete();
                  }
                } catch (e) {
                  debugPrint('Error deleting audio file: $e');
                }
              }
              dream.delete();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () => _showDreamDetails(context, dream),
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      dream.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (dream.voiceMemoPath != null &&
                      dream.voiceMemoPath!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 4.0),
                      child: Icon(
                        Icons.mic,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 18,
                      ),
                    ),
                  if (dream.isFavorite ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 4.0),
                      child: Icon(
                        Icons.star,
                        color: Colors.yellow[600],
                        size: 18,
                      ),
                    ),
                  Icon(
                    _getMoonIcon(dream.mood),
                    color: _getMoodColor(dream.mood),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMd().format(dream.date),
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (dream.tags.isNotEmpty)
                Wrap(
                  spacing: 6.0,
                  runSpacing: 0.0,
                  children: dream.tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dedicated stateful widget for the player UI within the dialog.
/// This version is corrected for proper lifecycle management.
class _MemoPlayer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  const _MemoPlayer({required this.audioPlayer});

  @override
  State<_MemoPlayer> createState() => _MemoPlayerState();
}

class _MemoPlayerState extends State<_MemoPlayer> {
  PlayerState? _playerState;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late final List<StreamSubscription> _subscriptions;

  bool get isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    // A list to hold our subscriptions
    _subscriptions = [];

    // Listen to the streams and add the subscriptions to the list
    _subscriptions.add(
      widget.audioPlayer.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playerState = s);
      }),
    );

    _subscriptions.add(
      widget.audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
    );

    _subscriptions.add(
      widget.audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
    );
  }

  @override
  void dispose() {
    // Cancel all subscriptions in the list
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    try {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(d.inMinutes.remainder(60));
      final seconds = twoDigits(d.inSeconds.remainder(60));
      return '$minutes:$seconds';
    } catch (e) {
      return "00:00";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 32,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () {
                if (isPlaying) {
                  widget.audioPlayer.pause();
                } else {
                  widget.audioPlayer.resume();
                }
              },
            ),
            Expanded(
              child: Slider(
                value: _position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, _duration.inMilliseconds.toDouble()),
                max: _duration.inMilliseconds.toDouble() > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) async {
                  final position = Duration(milliseconds: value.toInt());
                  await widget.audioPlayer.seek(position);
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
        )
      ],
    );
  }
}
