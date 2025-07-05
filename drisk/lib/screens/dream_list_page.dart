import 'package:drisk/models/dream_model.dart';
import 'package:drisk/screens/log_dream_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class DreamListPage extends StatelessWidget {
  const DreamListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dream Journal'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children:
                          dream.tags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.3),
                                ),
                              )
                              .toList(),
                    ),
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
    );
  }

  void _confirmDelete(BuildContext context, Dream dream) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  children:
                      dream.tags
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
