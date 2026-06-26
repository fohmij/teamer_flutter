import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/player.dart';

Future<bool> showWhatsAppPollScanDrawer(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WhatsAppPollScanDrawer(),
  );

  return result ?? false;
}

class _WhatsAppPollScanDrawer extends StatefulWidget {
  const _WhatsAppPollScanDrawer();

  @override
  State<_WhatsAppPollScanDrawer> createState() =>
      _WhatsAppPollScanDrawerState();
}

class _WhatsAppPollScanDrawerState extends State<_WhatsAppPollScanDrawer> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _processing = false;
  bool _applying = false;
  bool _scanWasStarted = false;

  String? _errorMessage;
  String? _rawText;
  XFile? _pickedImage;
  List<_ScanSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAndScanScreenshot();
    });
  }

  Future<void> _pickAndScanScreenshot() async {
    if (_processing || _applying) return;

    setState(() {
      _processing = true;
      _scanWasStarted = true;
      _errorMessage = null;
      _rawText = null;
      _pickedImage = null;
      _suggestions = [];
    });

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedImage == null) {
        if (!mounted) return;
        setState(() {
          _processing = false;
        });
        return;
      }

      final recognizedText = await _recognizeText(pickedImage.path);
      final extractedNames = _extractNamesFromRecognizedText(recognizedText);

      debugPrint('===== OCR RAW TEXT START =====');
      debugPrint(recognizedText.text);
      debugPrint('===== OCR RAW TEXT END =====');

      final players = await _databaseService.getPlayers();
      final suggestions = _buildSuggestions(
        extractedNames: extractedNames,
        existingPlayers: players,
      );

      if (!mounted) return;
      setState(() {
        _processing = false;
        _pickedImage = pickedImage;
        _rawText = recognizedText.text.trim();
        _suggestions = suggestions;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = 'Screenshot konnte nicht ausgewertet werden: $error';
      });
    }
  }

  Future<RecognizedText> _recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      return await textRecognizer.processImage(inputImage);
    } finally {
      await textRecognizer.close();
    }
  }

  List<String> _extractNamesFromRecognizedText(RecognizedText recognizedText) {
    final lines = <String>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        lines.add(line.text);
      }
    }

    if (lines.isEmpty) {
      lines.addAll(recognizedText.text.split('\n'));
    }

    final names = <String>[];
    final normalizedNames = <String>{};

    for (final line in lines) {
      final cleanedLine = _cleanPotentialName(line);
      if (!_looksLikeName(cleanedLine)) continue;

      final normalizedName = _normalizeName(cleanedLine);
      if (normalizedName.isEmpty || normalizedNames.contains(normalizedName)) {
        continue;
      }

      normalizedNames.add(normalizedName);
      names.add(cleanedLine);
    }

    return names;
  }

  String _cleanPotentialName(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'[\u200e\u200f]'), '')
        .replaceAll(RegExp(r'^[\s•·\-–—*✓✔☑✅⬤●○]+'), '')
        .replaceAll(RegExp(r'\s*\((du|you)\)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+\d+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = cleaned.replaceAll(RegExp(r'^[@~]\s*'), '').trim();

    return cleaned;
  }

  bool _looksLikeName(String value) {
    if (value.length < 3 || value.length > 40) return false;

    final lowerValue = value.toLowerCase();
    final blockedWords = [
      'Ich',
      'bin',
      'da',
      'whatsapp',
      'umfrage',
      'abstimmung',
      'stimme',
      'stimmen',
      'antwort',
      'antworten',
      'option',
      'auswahl',
      'teilnehmer',
      'anwesend',
      'anwesende',
      'spieler',
      'anzeigen',
      'mehr anzeigen',
      'nachricht',
      'suchen',
      'bearbeiten',
      'heute',
      'gestern',
      'voted',
      'vote',
      'poll',
      'selected',
      'select',
      'view',
    ];

    if (blockedWords.any(lowerValue.contains)) return false;
    if (RegExp(r'[0-9%@:/\\]').hasMatch(value)) return false;

    return RegExp(
      r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ž'’.\- ]+$",
      unicode: true,
    ).hasMatch(value);
  }

  List<_ScanSuggestion> _buildSuggestions({
    required List<String> extractedNames,
    required List<Player> existingPlayers,
  }) {
    final existingPlayersByName = <String, Player>{
      for (final player in existingPlayers) _normalizeName(player.name): player,
    };

    return extractedNames.map((name) {
      final existingPlayer = existingPlayersByName[_normalizeName(name)];

      return _ScanSuggestion(
        recognizedName: name,
        displayName: existingPlayer?.name ?? name,
        existingPlayer: existingPlayer,
      );
    }).toList();
  }

  Future<void> _applySelectedSuggestions() async {
    final selectedSuggestions = _suggestions
        .where((suggestion) => suggestion.selected)
        .toList();

    if (selectedSuggestions.isEmpty || _applying) return;

    setState(() {
      _applying = true;
      _errorMessage = null;
    });

    try {
      for (final suggestion in selectedSuggestions) {
        final existingPlayer = suggestion.existingPlayer;
        if (existingPlayer != null) {
          await _databaseService.updatePlayerStatus(existingPlayer.id, 1);
        } else {
          await _databaseService.addPlayer(suggestion.displayName);
        }
      }

      final updatedPlayers = await _databaseService.getPlayers();
      final updatedPlayersByName = <String, Player>{
        for (final player in updatedPlayers)
          _normalizeName(player.name): player,
      };

      for (final suggestion in selectedSuggestions) {
        if (suggestion.existingPlayer != null) continue;

        final addedPlayer =
            updatedPlayersByName[_normalizeName(suggestion.displayName)];
        if (addedPlayer != null) {
          await _databaseService.updatePlayerStatus(addedPlayer.id, 1);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _errorMessage = 'Vorschlag konnte nicht übernommen werden: $error';
      });
    }
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('å', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r"[^a-z0-9 ]"), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppTheme.backgroundColorDark
        : AppTheme.backgroundColorLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  _buildDragHandle(),
                  _buildHeader(),
                  if (_errorMessage != null) _buildErrorMessage(),
                  Expanded(child: _buildBody(scrollController)),
                  _buildActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.grey600.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WhatsApp-Umfrage scannen',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Namen prüfen und als Vorschlag übernehmen',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
              ),
              SizedBox(height: 6,)
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.deleteRed.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _errorMessage!,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppTheme.deleteRed),
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_processing) {
      return _buildProcessingState();
    }

    if (_suggestions.isNotEmpty) {
      return _buildSuggestionsList(scrollController);
    }

    if (_scanWasStarted && _pickedImage != null) {
      return _buildNoNamesState(scrollController);
    }

    return _buildInitialState(scrollController);
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(
            'Screenshot wird ausgewertet...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 28),
      children: [
        Icon(Icons.image_search, size: 72, color: AppTheme.grey600),
        const SizedBox(height: 18),
        Text(
          'Wähle einen Screenshot aus deiner Galerie aus.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _pickAndScanScreenshot,
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: Text(
              'Screenshot hochladen',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoNamesState(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 18),
      children: [
        _buildImagePreview(),
        const SizedBox(height: 20),
        Icon(Icons.search_off, size: 64, color: AppTheme.grey600),
        const SizedBox(height: 12),
        Text(
          'Keine Spielernamen erkannt',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Schneide den Screenshot möglichst auf die Liste der anwesenden Spieler zu und versuche es erneut.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.grey600),
        ),
        if ((_rawText ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Erkannten Text anzeigen',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            children: [
              SelectableText(
                _rawText!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionsList(ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedSuggestions = _suggestions.where((s) => s.selected).toList();
    final selectedExistingCount = selectedSuggestions
        .where((s) => s.existingPlayer != null)
        .length;

    final allExistingCount = _suggestions
        .where((s) => s.existingPlayer != null)
        .length;

    final selectedNewCount = selectedSuggestions
        .where((s) => s.existingPlayer == null)
        .length;

    final allNewCount = _suggestions
        .where((s) => s.existingPlayer == null)
        .length;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 18),
      children: [
        _buildImagePreview(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _ScanSummaryChip(
              icon: Icons.check_circle,
              label: '${selectedSuggestions.length}/${_suggestions.length}',
            ),
            _ScanSummaryChip(
              icon: Icons.person_search,
              label: '$selectedExistingCount/$allExistingCount',
            ),
            _ScanSummaryChip(
              icon: Icons.person_add_alt_1,
              label: '$selectedNewCount/$allNewCount',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Vorschlag', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) {
              return Divider(
                thickness: 1,
                height: 1,
                color: isDark ? AppTheme.navigationBarDark : AppTheme.grey400,
              );
            },
            itemBuilder: (context, index) {
              return _buildSuggestionTile(_suggestions[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final pickedImage = _pickedImage;
    if (pickedImage == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(pickedImage.path),
            height: 130,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: IconButton(
            onPressed: _processing || _applying ? null : _pickAndScanScreenshot,
            style: TextButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.grey700
                  : Colors.white.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            icon: const Icon(Icons.delete, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionTile(_ScanSuggestion suggestion) {
    final existingPlayer = suggestion.existingPlayer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(top: 0),
      elevation: 0,
      color: suggestion.selected
          ? (isDark ? AppTheme.grey700 : AppTheme.btnBlue1)
          : Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: CheckboxListTile(
        value: suggestion.selected,
        activeColor: AppTheme.primaryBlue,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.trailing,
        onChanged: _applying
            ? null
            : (value) {
                setState(() {
                  suggestion.selected = value ?? false;
                });
              },
        secondary: Icon(
          existingPlayer == null ? Icons.person_add_alt_1 : Icons.person_search,
          color: AppTheme.secondaryBlue,
        ),
        title: Text(
          suggestion.displayName,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildActions() {
    final hasSelectedSuggestions = _suggestions.any((s) => s.selected);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.grey700 : Colors.white,
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: isDark ? Colors.transparent : AppTheme.grey300,
                  width: 1,
                ),
              ),
              onPressed: _applying
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(
                'Abbrechen',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_suggestions.isEmpty)
            Expanded(
              child: TextButton(
                onPressed: _processing || _applying
                    ? null
                    : _pickAndScanScreenshot,
                child: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Neu scannen',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
              ),
            )
          else
            Expanded(
              child: TextButton(
                onPressed: hasSelectedSuggestions && !_applying
                    ? _applySelectedSuggestions
                    : null,
                child: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Zustimmen',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanSuggestion {
  final String recognizedName;
  final String displayName;
  final Player? existingPlayer;
  bool selected;

  _ScanSuggestion({
    required this.recognizedName,
    required this.displayName,
    required this.existingPlayer,
    bool? selected,
  }) : selected = selected ?? existingPlayer != null;
}

class _ScanSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ScanSummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
    return Chip(
      avatar: Icon(icon, size: 18, color: isDark ? AppTheme.secondaryBlue : Colors.white),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 14, color: Colors.white),
      backgroundColor: isDark ? Theme.of(context).cardColor.withValues(alpha: 0.65) : AppTheme.primaryBlue,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}
