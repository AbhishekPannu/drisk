import 'dart:io';

import 'package:drisk/models/dream_model.dart';
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds"
        .replaceFirst('00:', '');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Dream' : 'Log a New Dream'),
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
                // Text Fields Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                ),
                const SizedBox(height: 24),
                // Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                        const Divider(),
                        const Text('Mood',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: DreamMood.values.map((mood) {
                            final isSelected = _selectedMood == mood;
                            return IconButton(
                              iconSize: isSelected ? 32 : 24,
                              icon: Icon(_getMoonIcon(mood)),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey,
                              onPressed: () =>
                                  setState(() => _selectedMood = mood),
                              tooltip: mood.name,
                            );
                          }).toList(),
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
                            padding: const EdgeInsets.only(top: 24.0),
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
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mark as Favorite'),
                          value: _isFavorite,
                          onChanged: (bool value) =>
                              setState(() => _isFavorite = value),
                          secondary: Icon(
                            _isFavorite ? Icons.star : Icons.star_border,
                            color:
                                _isFavorite ? Colors.yellow[600] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // --- VOICE MEMO CARD ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_voiceMemoPath == null)
                          ListTile(
                            leading: Icon(
                                _isRecording ? Icons.stop_circle : Icons.mic),
                            title: Text(
                                _isRecording ? 'Recording...' : 'Record Memo'),
                            onTap: _toggleRecording,
                            iconColor: _isRecording
                                ? Colors.redAccent
                                : Theme.of(context).colorScheme.secondary,
                          )
                        else
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(_isMemoPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled),
                                    onPressed: _playMemo,
                                    iconSize: 32,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _memoPosition.inMilliseconds
                                          .toDouble()
                                          .clamp(
                                              0.0,
                                              _memoDuration.inMilliseconds
                                                  .toDouble()),
                                      max: _memoDuration.inMilliseconds
                                          .toDouble(),
                                      onChanged: (value) async {
                                        final position = Duration(
                                            milliseconds: value.toInt());
                                        await _audioPlayer.seek(position);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.redAccent,
                                    onPressed: _deleteMemo,
                                  ),
                                ],
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_memoPosition)),
                                    Text(_formatDuration(_memoDuration)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sliders Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                        ),
                        Text('Clarity: ${_clarity.toInt()}/10'),
                        Slider(
                          value: _clarity,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: _clarity.round().toString(),
                          onChanged: (value) =>
                              setState(() => _clarity = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _saveDream,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(_isEditing ? 'Update Dream' : 'Save Dream'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
