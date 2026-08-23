import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/event_data.dart';
import 'package:url_launcher/url_launcher.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<EventData> _eventFuture;

  @override
  void initState() {
    super.initState();
    _eventFuture = _databaseService.getEventData();
  }

  void _reloadEvent() {
    setState(() {
      _eventFuture = _databaseService.getEventData();
    });
  }

  Future<void> _editEvent(EventData event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _EventEditPage(event: event)),
    );

    if (changed == true && mounted) {
      _reloadEvent();
    }
  }

  Future<void> _openLink(String value) async {
    final uri = _normalizedUri(value);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geöffnet werden.')),
      );
    }
  }

  Uri? _normalizedUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<EventData>(
      future: _eventFuture,
      builder: (context, snapshot) {
        final event = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              event?.title ?? 'Event',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            titleTextStyle: Theme.of(context).textTheme.titleLarge,
            backgroundColor: isDark
                ? AppTheme.navigationBarDark
                : AppTheme.navigationBarLight,
            actions: event == null
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip: 'Event bearbeiten',
                        onPressed: () => _editEvent(event),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
          ),
          body: SafeArea(
            child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : snapshot.hasError
                ? Center(child: Text('Fehler: ${snapshot.error}'))
                : _buildEventContent(event ?? EventData.defaults),
          ),
          extendBody: true,
        );
      },
    );
  }

  Widget _buildEventContent(EventData event) {
    final link = event.link.trim();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildStoredImage(event.imagePath),
                  ),
                ),
                const SizedBox(height: 20),
                MarkdownBody(
                  data: event.markdownText,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 18,
                          height: 1.45,
                        ),
                        strong: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.45,
                            ),
                      ),
                  onTapLink: (_, href, __) {
                    if (href != null) _openLink(href);
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18,10,18,38),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: link.isEmpty ? null : () => _openLink(link),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      link.isEmpty ? 'Link: –' : 'Link: $link',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventEditPage extends StatefulWidget {
  final EventData event;

  const _EventEditPage({required this.event});

  @override
  State<_EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<_EventEditPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _textController;
  late final TextEditingController _linkController;

  XFile? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _textController = TextEditingController(text: widget.event.markdownText);
    _linkController = TextEditingController(text: widget.event.link);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_saving) return;

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );

    if (image == null || !mounted) return;
    setState(() {
      _pickedImage = image;
    });
  }

  Future<String> _persistPickedImage(XFile image) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final eventDirectory = Directory(p.join(documentsDirectory.path, 'event'));
    await eventDirectory.create(recursive: true);

    var extension = p.extension(image.path).toLowerCase();
    if (extension.isEmpty || extension.length > 6) {
      extension = '.jpg';
    }

    final targetPath = p.join(
      eventDirectory.path,
      'event_${DateTime.now().millisecondsSinceEpoch}$extension',
    );

    final copiedFile = await File(image.path).copy(targetPath);
    return copiedFile.path;
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Titel eingeben.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      var imagePath = widget.event.imagePath;
      final pickedImage = _pickedImage;

      if (pickedImage != null) {
        imagePath = await _persistPickedImage(pickedImage);
      }

      final updatedEvent = widget.event.copyWith(
        title: title,
        imagePath: imagePath,
        markdownText: _textController.text.trim(),
        link: _linkController.text.trim(),
      );

      await _databaseService.saveEventData(updatedEvent);

      if (pickedImage != null) {
        await _deleteOldCustomImage(widget.event.imagePath, imagePath);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event konnte nicht gespeichert werden: $error'),
        ),
      );
    }
  }

  Future<void> _deleteOldCustomImage(String oldPath, String newPath) async {
    if (oldPath.startsWith('assets/') || oldPath == newPath) return;

    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event bearbeiten'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Bild',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _pickedImage == null
                          ? _buildStoredImage(widget.event.imagePath)
                          : Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: IconButton(
                      tooltip: 'Bild auswählen',
                      onPressed: _saving ? null : _pickImage,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.grey700
                            : Colors.black.withValues(alpha: 0.55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _textController,
                keyboardType: TextInputType.multiline,
                minLines: 10,
                maxLines: 18,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Text (Markdown)',
                  alignLabelWithHint: true,
                  hintText: '**fett**, *kursiv*, # Überschrift, - Liste',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Webseite',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Speichern',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildStoredImage(String imagePath) {
  if (imagePath.startsWith('assets/')) {
    return Image.asset(imagePath, fit: BoxFit.cover);
  }

  final file = File(imagePath);
  if (file.existsSync()) {
    return Image.file(file, fit: BoxFit.cover);
  }

  return Image.asset(EventData.defaultImagePath, fit: BoxFit.cover);
}
