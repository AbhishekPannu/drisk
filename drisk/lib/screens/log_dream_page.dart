import 'dart:io';
import 'package:drisk/models/dream_model.dart';
import 'package:drisk/widgets/frosted_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

class LogDreamPage extends StatefulWidget {
  final Dream? dreamToEdit;
  final VoidCallback? onDreamSaved;

  const LogDreamPage({
    super.key,
    this.dreamToEdit,
    this.onDreamSaved,
  });

  @override
  State<LogDreamPage> createState() => _LogDreamPageState();
}

class _LogDreamPageState extends State<LogDreamPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  late bool _isEditing;
  DateTime _selectedDate = DateTime.now();
  DreamMood _selectedMood = DreamMood.neutral;
  DreamType _selectedType = DreamType.normal;
  double _thrillLevel = 5.0;
  double _clarity = 5.0;
  bool _isFavorite = false;
  String? _selectedRecurringGroupId;
  List<Dream> _existingRecurringDreams = [];

  // --- AUDIO STATE ---
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  String? _voiceMemoPath;
  bool _isMemoPlaying = false;
  Duration _memoDuration = Duration.zero;
  Duration _memoPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.dreamToEdit != null;
    _fetchRecurringDreams();

    // Initialize audio components
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();

    // Listen to player state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isMemoPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _memoDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _memoPosition = p);
    });

    if (_isEditing) {
      _populateFormForEditing();
    }
  }

  void _fetchRecurringDreams() {
    final box = Hive.box<Dream>('dreams');
    final allRecurring = box.values
        .where((d) =>
            d.type == DreamType.recurring && d.recurringDreamGroupId != null)
        .toList();
    final uniqueGroupIds = <String>{};
    _existingRecurringDreams = allRecurring
        .where((d) => uniqueGroupIds.add(d.recurringDreamGroupId!))
        .toList();
  }

  void _populateFormForEditing() {
    final dream = widget.dreamToEdit!;
    _titleController.text = dream.title;
    _descriptionController.text = dream.description;
    _tagsController.text = dream.tags.join(', ');
    _selectedDate = dream.date;
    _selectedMood = dream.mood;
    _selectedType = dream.type;
    _thrillLevel = dream.thrillLevel;
    _clarity = dream.clarity;
    _isFavorite = dream.isFavorite ?? false;
    _selectedRecurringGroupId = dream.recurringDreamGroupId;
    _voiceMemoPath = dream.voiceMemoPath;
    if (_voiceMemoPath != null) {
      _audioPlayer.setSourceDeviceFile(_voiceMemoPath!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _toggleRecording() async {
    if (await _audioRecorder.hasPermission()) {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _isRecording = false;
            _voiceMemoPath = path;
            _audioPlayer.setSourceDeviceFile(path);
          });
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/dream_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } else {
      // Handle permission denial
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _playMemo() async {
    if (_voiceMemoPath == null) return;

    if (_isMemoPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void _deleteMemo() {
    if (_voiceMemoPath != null) {
      File(_voiceMemoPath!)
          .delete()
          .catchError((e) => debugPrint("Error deleting file: $e"));
      _audioPlayer.stop();
      setState(() {
        _voiceMemoPath = null;
        _memoDuration = Duration.zero;
        _memoPosition = Duration.zero;
      });
    }
  }

  void _saveDream() {
    try {
      FocusScope.of(context).unfocus();
      if (!_formKey.currentState!.validate()) return;

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      String? finalRecurringId = _selectedRecurringGroupId;
      if (_selectedType == DreamType.recurring &&
          _selectedRecurringGroupId == 'new') {
        finalRecurringId = const Uuid().v4();
      } else if (_selectedType != DreamType.recurring) {
        finalRecurringId = null;
      }

      if (_isEditing) {
        final dream = widget.dreamToEdit!;
        dream.title = _titleController.text;
        dream.description = _descriptionController.text;
        dream.date = _selectedDate;
        dream.mood = _selectedMood;
        dream.type = _selectedType;
        dream.thrillLevel = _thrillLevel;
        dream.clarity = _clarity;
        dream.tags = tags;
        dream.isFavorite = _isFavorite;
        dream.recurringDreamGroupId = finalRecurringId;
        dream.voiceMemoPath = _voiceMemoPath;
        dream.save();
      } else {
        final newDream = Dream(
          id: const Uuid().v4(),
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
          mood: _selectedMood,
          type: _selectedType,
          thrillLevel: _thrillLevel,
          clarity: _clarity,
          tags: tags,
          isFavorite: _isFavorite,
          recurringDreamGroupId: finalRecurringId,
          voiceMemoPath: _voiceMemoPath,
        );
        Hive.box<Dream>('dreams').add(newDream);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dream ${_isEditing ? 'updated' : 'logged'}!'),
          backgroundColor: Colors.green[600],
        ),
      );

      if (_isEditing) {
        Navigator.of(context).pop();
      } else {
        widget.onDreamSaved?.call();
      }
    } catch (e, stacktrace) {
      debugPrint("ERROR SAVING DREAM: $e\n$stacktrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error saving dream. Check console for details.'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Dream' : 'Log a New Dream',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FrostedGlassCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration:
                            const InputDecoration(labelText: 'Dream Title'),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Dream Description'),
                        maxLines: 5,
                        validator: (v) =>
                            v!.isEmpty ? 'Please describe your dream' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FrostedGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Dream Date'),
                        subtitle:
                            Text(DateFormat.yMMMMd().format(_selectedDate)),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _selectDate(context),
                      ),
                      const Divider(color: Colors.white12),
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Text('Mood',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      _MoodSelector(
                        selectedMood: _selectedMood,
                        onMoodSelected: (mood) =>
                            setState(() => _selectedMood = mood),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<DreamType>(
                        value: _selectedType,
                        decoration:
                            const InputDecoration(labelText: 'Dream Type'),
                        items: DreamType.values
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            if (_selectedType != DreamType.recurring) {
                              _selectedRecurringGroupId = null;
                            }
                          });
                        },
                      ),
                      if (_selectedType == DreamType.recurring)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: DropdownButtonFormField<String?>(
                            value: _selectedRecurringGroupId,
                            hint: const Text('Link to a recurring series...'),
                            decoration: const InputDecoration(
                                labelText: 'Recurring Series'),
                            items: [
                              const DropdownMenuItem(
                                value: 'new',
                                child: Text('Start a New Series'),
                              ),
                              ..._existingRecurringDreams.map(
                                (dream) => DropdownMenuItem(
                                  value: dream.recurringDreamGroupId,
                                  child: Text(dream.title,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(
                                () => _selectedRecurringGroupId = value),
                          ),
                        ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma-separated)',
                          hintText: 'e.g. flying, school, family',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mark as Favorite'),
                        value: _isFavorite,
                        onChanged: (bool value) =>
                            setState(() => _isFavorite = value),
                        activeColor: Colors.yellow[600],
                        secondary: Icon(
                          _isFavorite ? Icons.star : Icons.star_border,
                          color: _isFavorite ? Colors.yellow[600] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FrostedGlassCard(
                  child: Column(
                    children: [
                      if (_voiceMemoPath == null)
                        _RecordButton(
                          isRecording: _isRecording,
                          onTap: _toggleRecording,
                        )
                      else
                        _MemoPlayer(
                          audioPlayer: _audioPlayer,
                          isPlaying: _isMemoPlaying,
                          duration: _memoDuration,
                          position: _memoPosition,
                          onPlayPause: _playMemo,
                          onDelete: _deleteMemo,
                          onSeek: (pos) => _audioPlayer.seek(pos),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FrostedGlassCard(
                  child: Column(
                    children: [
                      Text('Thrill Level: ${_thrillLevel.toInt()}/10'),
                      Slider(
                        value: _thrillLevel,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _thrillLevel.round().toString(),
                        onChanged: (value) =>
                            setState(() => _thrillLevel = value),
                        activeColor: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text('Clarity: ${_clarity.toInt()}/10'),
                      Slider(
                        value: _clarity,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: _clarity.round().toString(),
                        onChanged: (value) => setState(() => _clarity = value),
                        activeColor: Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _SaveDreamButton(
                  isEditing: _isEditing,
                  onPressed: _saveDream,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- NEW/IMPROVED HELPER WIDGETS ---

class _MoodSelector extends StatelessWidget {
  final DreamMood selectedMood;
  final ValueChanged<DreamMood> onMoodSelected;

  const _MoodSelector(
      {required this.selectedMood, required this.onMoodSelected});

  static const Map<DreamMood, IconData> _moodIcons = {
    DreamMood.nightmare: Icons.new_releases,
    DreamMood.bad: Icons.nightlight_round,
    DreamMood.neutral: Icons.circle,
    DreamMood.good: Icons.brightness_3,
    DreamMood.excellent: Icons.wb_sunny,
  };

  static const Map<DreamMood, Color> _moodColors = {
    DreamMood.nightmare: Colors.red,
    DreamMood.bad: Colors.orange,
    DreamMood.neutral: Colors.grey,
    DreamMood.good: Colors.lightBlue,
    DreamMood.excellent: Colors.yellow,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: DreamMood.values.map((mood) {
        final isSelected = selectedMood == mood;
        return GestureDetector(
          onTap: () => onMoodSelected(mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? _moodColors[mood]!.withOpacity(0.3)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? _moodColors[mood]!
                    : Colors.grey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              _moodIcons[mood],
              color: _moodColors[mood],
              size: 28,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const _RecordButton({required this.isRecording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
            color: isRecording
                ? Colors.red.withOpacity(0.2)
                : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
                color: isRecording
                    ? Colors.red
                    : Theme.of(context).colorScheme.secondary,
                width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isRecording ? Icons.stop_circle : Icons.mic,
                color: isRecording
                    ? Colors.red
                    : Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Text(isRecording ? 'Recording...' : 'Record Voice Memo',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MemoPlayer extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final VoidCallback onPlayPause;
  final VoidCallback onDelete;
  final Future<void> Function(Duration) onSeek; // <-- CORRECTED TYPE

  const _MemoPlayer({
    required this.audioPlayer,
    required this.isPlaying,
    required this.duration,
    required this.position,
    required this.onPlayPause,
    required this.onDelete,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled),
              onPressed: onPlayPause,
              iconSize: 40,
              color: Theme.of(context).colorScheme.secondary,
            ),
            Expanded(
              child: Slider(
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, duration.inMilliseconds.toDouble()),
                max: duration.inMilliseconds.toDouble() > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) async {
                  final newPosition = Duration(milliseconds: value.toInt());
                  await onSeek(newPosition); // <-- Now correctly awaited
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              color: Colors.redAccent,
              onPressed: onDelete,
              iconSize: 30,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position)),
              Text(_formatDuration(duration)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SaveDreamButton extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onPressed;

  const _SaveDreamButton({required this.isEditing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.save_alt_outlined, color: Colors.black),
        label: Text(
          isEditing ? 'Update Dream' : 'Save Dream',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
      ),
    );
  }
}
