// VERSION 2026-11-13 (BACKUP-TRANSFER): Backups exportieren/importieren inkl. Einstellungen und Eventbild.
// VERSION 2026-11-13: Einstellbare Begriffsersetzungen für den WhatsApp-Scan.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/services/app_settings_controller.dart';
import 'package:teamer/services/app_settings_service.dart';
import 'package:teamer/services/reminder_notification_service.dart';
import 'package:teamer/services/stats_backup_service.dart';
import 'package:teamer/pages/home_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _groupLinkSection = 'groupLink';
  static const String _blockedWordsSection = 'blockedWords';
  static const String _scanReplacementsSection = 'scanReplacements';

  late final TextEditingController _minGamesController;
  late final FocusNode _minGamesFocusNode;
  late final TextEditingController _whatsAppGroupLinkController;
  late final FocusNode _whatsAppGroupLinkFocusNode;
  late final TextEditingController _blockedWordsController;
  late final FocusNode _blockedWordsFocusNode;

  String? _expandedWhatsAppSection;
  int? _expandedReminderId;

  List<StatsBackup> _backups = [];
  bool _backupsLoading = true;
  bool _backupsExpanded = false;
  bool _backupSectionExpanded = false;
  bool _backupBusy = false;
  String? _backupsError;

  @override
  void initState() {
    super.initState();
    _minGamesController = TextEditingController(
      text: appSettingsController.value.minGamesForFullWeight.toString(),
    );
    _minGamesFocusNode = FocusNode();
    _whatsAppGroupLinkController = TextEditingController(
      text: appSettingsController.value.whatsAppGroupLink,
    );
    _whatsAppGroupLinkFocusNode = FocusNode();
    _blockedWordsController = TextEditingController(
      text: appSettingsController.value.blockedWords.join(', '),
    );
    _blockedWordsFocusNode = FocusNode();
    _loadBackups();
  }

  @override
  void dispose() {
    _minGamesController.dispose();
    _minGamesFocusNode.dispose();
    _whatsAppGroupLinkController.dispose();
    _whatsAppGroupLinkFocusNode.dispose();
    _blockedWordsController.dispose();
    _blockedWordsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveMinGames() async {
    final rawValue = _minGamesController.text.trim();
    final parsedValue = int.tryParse(rawValue);

    if (parsedValue == null) {
      _minGamesController.text = appSettingsController
          .value
          .minGamesForFullWeight
          .toString();
      return;
    }

    final newValue = parsedValue.clamp(0, 999).toInt();
    _minGamesController.text = newValue.toString();

    await appSettingsController.setMinGamesForFullWeight(newValue);
  }

  Future<void> _saveWhatsAppGroupLink() async {
    final groupLink = _whatsAppGroupLinkController.text.trim();
    _whatsAppGroupLinkController.text = groupLink;
    await appSettingsController.setWhatsAppGroupLink(groupLink);
  }

  Future<void> _saveBlockedWords() async {
    final blockedWords = _blockedWordsController.text
        .split(',')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();

    await appSettingsController.setBlockedWords(blockedWords);

    _blockedWordsController.text = appSettingsController.value.blockedWords
        .join(', ');
  }

  Future<void> _toggleWhatsAppSection(String section) async {
    final oldSection = _expandedWhatsAppSection;

    if (oldSection == section) {
      await _saveWhatsAppSection(section);
      _unfocusWhatsAppSection(section);

      if (!mounted) return;
      setState(() {
        _expandedWhatsAppSection = null;
      });
      return;
    }

    if (oldSection != null) {
      await _saveWhatsAppSection(oldSection);
      _unfocusWhatsAppSection(oldSection);
    }

    if (!mounted) return;
    setState(() {
      _expandedWhatsAppSection = section;
    });
  }

  Future<void> _saveWhatsAppSection(String section) async {
    if (section == _groupLinkSection) {
      await _saveWhatsAppGroupLink();
    } else if (section == _blockedWordsSection) {
      await _saveBlockedWords();
    }
  }

  void _unfocusWhatsAppSection(String section) {
    if (section == _groupLinkSection) {
      _whatsAppGroupLinkFocusNode.unfocus();
    } else if (section == _blockedWordsSection) {
      _blockedWordsFocusNode.unfocus();
    }
  }

  Future<void> _openScanReplacementEditor({int? index}) async {
    final replacements = appSettingsController.value.scanReplacements;
    final previous = index == null ? null : replacements[index];
    final edited = await showDialog<ScanReplacement>(
      context: context,
      builder: (_) => _ScanReplacementDialog(
        replacement: previous,
        existingTerms: [
          for (int i = 0; i < replacements.length; i++)
            if (i != index) replacements[i].find,
        ],
      ),
    );
    if (edited == null || !mounted) return;

    final updated = List<ScanReplacement>.from(
      appSettingsController.value.scanReplacements,
    );
    if (index == null) {
      updated.add(edited);
    } else {
      updated[index] = edited;
    }
    try {
      await appSettingsController.setScanReplacements(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zuordnung konnte nicht gespeichert werden: $error')),
      );
    }
  }

  Future<void> _removeScanReplacement(int index) async {
    final updated = List<ScanReplacement>.from(
      appSettingsController.value.scanReplacements,
    )..removeAt(index);
    try {
      await appSettingsController.setScanReplacements(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zuordnung konnte nicht gelöscht werden: $error')),
      );
    }
  }

  Future<void> _openReminderEditor({WeeklyReminder? reminder}) async {
    final result = await showDialog<_ReminderDialogResult>(
      context: context,
      builder: (_) => _ReminderDialog(reminder: reminder),
    );

    if (result == null || !mounted) return;

    try {
      if (result.deleteRequested) {
        if (reminder == null) return;

        await ReminderNotificationService.instance.cancelWeeklyReminder(
          reminder.id,
        );
        await appSettingsController.removeWeeklyReminder(reminder.id);
        if (mounted) {
          setState(() {
            _expandedReminderId = null;
          });
        }
        return;
      }

      if (reminder == null) {
        final permissionGranted = await ReminderNotificationService.instance
            .requestPermissions();

        if (!permissionGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Benachrichtigungen sind nicht erlaubt. Der Reminder wurde nicht gespeichert.',
              ),
            ),
          );
          return;
        }

        final createdReminder = await appSettingsController.addWeeklyReminder(
          name: result.name,
          weekday: result.weekday,
          hour: result.hour,
          minute: result.minute,
          playSound: result.playSound,
          enableVibration: result.enableVibration,
        );

        try {
          await ReminderNotificationService.instance.scheduleWeeklyReminder(
            createdReminder,
          );
          if (mounted) {
            setState(() {
              _expandedReminderId = null;
            });
          }
        } catch (_) {
          await appSettingsController.removeWeeklyReminder(createdReminder.id);
          rethrow;
        }
      } else {
        final updatedReminder = reminder.copyWith(
          name: result.name,
          weekday: result.weekday,
          hour: result.hour,
          minute: result.minute,
          playSound: result.playSound,
          enableVibration: result.enableVibration,
        );

        await appSettingsController.updateWeeklyReminder(updatedReminder);

        try {
          await ReminderNotificationService.instance.scheduleWeeklyReminder(
            updatedReminder,
          );
          if (mounted) {
            setState(() {
              _expandedReminderId = null;
            });
          }
        } catch (_) {
          await appSettingsController.updateWeeklyReminder(reminder);
          try {
            await ReminderNotificationService.instance.scheduleWeeklyReminder(
              reminder,
            );
          } catch (_) {
            // Der alte Reminder bleibt zumindest in den Einstellungen erhalten.
          }
          rethrow;
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder konnte nicht gespeichert werden: $error'),
        ),
      );
    }
  }

  Future<void> _loadBackups() async {
    if (!mounted) return;
    setState(() {
      _backupsLoading = true;
      _backupsError = null;
    });
    try {
      final backups = await StatsBackupService.instance.listBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _backupsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _backupsLoading = false;
        _backupsError = 'Backups konnten nicht geladen werden: $error';
      });
    }
  }

  void _showBackupMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _createManualBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await StatsBackupService.instance.createManualBackup();
      await _loadBackups();
      if (mounted) setState(() => _backupsExpanded = true);
      _showBackupMessage('Vollständiges Backup erstellt. Bitte über das Export-Symbol extern sichern.');
    } catch (error) {
      _showBackupMessage('Backup konnte nicht erstellt werden: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// Schreibt die Daten über den System-Dateidialog in einen frei wählbaren
  /// Ordner (z. B. Downloads). Der App-interne Pfad wird nicht geteilt.
  Future<void> _exportBackup(StatsBackup backup) async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final bytes = await StatsBackupService.instance.exportBackupBytes(backup);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Teamer-Backup exportieren',
        fileName: 'teamer_${backup.fileName}',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (saved != null) {
        _showBackupMessage('Backup exportiert. Bewahre die Datei außerhalb der App auf.');
      }
    } catch (error) {
      _showBackupMessage('Export fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// Importiert eine beliebig benannte JSON-Sicherung, ohne sofort Daten zu
  /// überschreiben. Die Wiederherstellung erfordert eine zweite Bestätigung.
  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    StatsBackup? imported;
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Teamer-Backup auswählen',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.single;
        final bytes = picked.bytes ??
            (picked.path == null ? null : await File(picked.path!).readAsBytes());
        if (bytes == null) {
          throw const FormatException('Die gewählte Datei konnte nicht gelesen werden.');
        }
        imported = await StatsBackupService.instance.importBackupBytes(bytes);
        await _loadBackups();
        if (mounted) {
          setState(() => _backupsExpanded = true);
          _showBackupMessage('Backup-Datei importiert. Du kannst sie jetzt wiederherstellen.');
        }
      }
    } catch (error) {
      _showBackupMessage('Import fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
    if (imported != null && mounted) {
      await _restoreBackup(imported);
    }
  }

  String _formatBackupDate(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _restoreBackup(StatsBackup backup) async {
    if (_backupBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: Text(
          'Backup vom ${_formatBackupDate(backup.createdAt)}\n'
          '${backup.playerCount} Spieler · ${backup.gameCount} Spiele\n\n'
          '${backup.includesAppData ? 'Spieler, Spiele, Einstellungen, Reminder und Eventdaten werden ersetzt.' : 'Dieses ältere Backup enthält nur Spieler und Spiele. Einstellungen und Eventdaten bleiben bestehen.'}\n\n'
          'Eine Sicherheitskopie des aktuellen Stands wird vorher angelegt.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(dialogContext).colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Wiederherstellen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _backupBusy) return;

    setState(() => _backupBusy = true);
    try {
      await StatsBackupService.instance.restoreBackup(backup);
      if (!mounted) return;
      // Nach Wiederherstellung auch den RAM-Cache und die geplanten Reminder
      // aktualisieren; ansonsten würde die alte Konfiguration weiterlaufen.
      await appSettingsController.load();
      String? reminderWarning;
      try {
        await ReminderNotificationService.instance.syncWeeklyReminders(
          appSettingsController.value.weeklyReminders,
        );
      } catch (error) {
        reminderWarning = ' Die Reminder konnten nicht neu geplant werden: $error';
      }
      if (!mounted) return;
      _showBackupMessage('Backup erfolgreich wiederhergestellt.${reminderWarning ?? ''}');
      // Alle Seiten mit zwischengespeicherten Statistiken neu aufbauen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (error) {
      _showBackupMessage('Wiederherstellung fehlgeschlagen: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _deleteBackup(StatsBackup backup) async {
    if (_backupBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup löschen?'),
        content: Text(
          'Soll die Sicherung vom ${_formatBackupDate(backup.createdAt)} '
          'wirklich dauerhaft gelöscht werden?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(dialogContext).colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: AppTheme.deleteRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Löschen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _backupBusy) return;

    setState(() => _backupBusy = true);
    try {
      await StatsBackupService.instance.deleteBackup(backup);
      await _loadBackups();
      _showBackupMessage('Backup gelöscht.');
    } catch (error) {
      _showBackupMessage('Backup konnte nicht gelöscht werden: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Widget _buildBackupSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Backups'),
        _SettingsGroup(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(
                  () => _backupSectionExpanded = !_backupSectionExpanded,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.backup_outlined,
                        size: 26,
                        color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Daten sichern',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _backupSectionExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 30,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_backupSectionExpanded) ...[
              const _SettingsDivider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _backupBusy ? null : _createManualBackup,
                    icon: _backupBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, color: Colors.white),
                    label: const Text(
                      'Jetzt Backup erstellen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _backupBusy ? null : _importBackup,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Backup-Datei importieren'),
                  ),
                ),
              ),
            const _SettingsDivider(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(
                  () => _backupsExpanded = !_backupsExpanded,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 25),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _backupsLoading
                              ? 'Backups werden geladen ...'
                              : 'Gespeicherte Backups (${_backups.length})',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _backupsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_backupsExpanded) ...[
              const _SettingsDivider(),
              if (_backupsLoading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_backupsError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_backupsError!),
                )
              else if (_backups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Noch keine Backups vorhanden.'),
                )
              else
                for (final backup in _backups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(
                          backup.kind == StatsBackupKind.automatic
                              ? Icons.update
                              : Icons.inventory_2_outlined,
                          size: 22,
                          color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatBackupDate(backup.createdAt),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${backup.typeLabel} · '
                                '${backup.playerCount} Spieler · '
                                '${backup.gameCount} Spiele · '
                                '${backup.includesAppData ? 'Vollständig' : 'Nur Statistiken'}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontSize: 12, color: AppTheme.grey600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Backup exportieren',
                          onPressed: _backupBusy
                              ? null
                              : () => _exportBackup(backup),
                          icon: const Icon(Icons.ios_share_outlined),
                        ),
                        IconButton(
                          tooltip: 'Backup wiederherstellen',
                          onPressed: _backupBusy
                              ? null
                              : () => _restoreBackup(backup),
                          icon: const Icon(Icons.restore),
                        ),
                        IconButton(
                          tooltip: 'Backup löschen',
                          onPressed: _backupBusy
                              ? null
                              : () => _deleteBackup(backup),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                  if (backup != _backups.last) const _SettingsDivider(),
                ],
            ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Text(
                  'Neue Backups enthalten Spieler, Spiele, Einstellungen, '
                  'Reminder und Eventdaten einschließlich eines eigenen Bildes. '
                  'Ältere Statistik-Backups enthalten nur Spieler und Spiele. '
                  'Ein automatisches Backup wird beim App-Start höchstens einmal '
                  'pro Monat erstellt (maximal 12 automatische Backups). '
                  'Interne Backups können bei einer Deinstallation verloren gehen. '
                  'Für Gerätewechsel oder ADB-Wiederherstellung das Backup über '
                  'das Export-Symbol in Downloads oder einem anderen Ordner '
                  'außerhalb der App speichern. Exportierte JSON-Dateien sind unverschlüsselt.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 13,
                    color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: appSettingsController,
          builder: (context, settings, _) {
            final currentMinGames = settings.minGamesForFullWeight.toString();
            final currentWhatsAppGroupLink = settings.whatsAppGroupLink;
            final currentBlockedWords = settings.blockedWords.join(', ');

            if (!_minGamesFocusNode.hasFocus &&
                _minGamesController.text != currentMinGames) {
              _minGamesController.text = currentMinGames;
            }

            if (!_whatsAppGroupLinkFocusNode.hasFocus &&
                _whatsAppGroupLinkController.text != currentWhatsAppGroupLink) {
              _whatsAppGroupLinkController.text = currentWhatsAppGroupLink;
            }

            if (!_blockedWordsFocusNode.hasFocus &&
                _blockedWordsController.text != currentBlockedWords) {
              _blockedWordsController.text = currentBlockedWords;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                const _SectionTitle('Allgemein'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: 'Darstellung der App festlegen',
                      trailing: SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: settings.themeMode,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: isDark
                              ? AppTheme.navigationBarDark
                              : Colors.white,
                          items: const [
                            DropdownMenuItem(
                              value: 'system',
                              child: Text('System'),
                            ),
                            DropdownMenuItem(
                              value: 'light',
                              child: Text('Hell'),
                            ),
                            DropdownMenuItem(
                              value: 'dark',
                              child: Text('Dunkel'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            await appSettingsController.setThemeMode(value);
                          },
                        ),
                      ),
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.sports_score_outlined,
                      title: 'Mindestspiele',
                      subtitle: 'Bis dahin zählt ein Spieler mit 0.5',
                      trailing: SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _minGamesController,
                          focusNode: _minGamesFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _saveMinGames(),
                          onEditingComplete: () {
                            _saveMinGames();
                            _minGamesFocusNode.unfocus();
                          },
                          onTapOutside: (_) {
                            _saveMinGames();
                            _minGamesFocusNode.unfocus();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildBackupSection(),
                const SizedBox(height: 24),
                const _SectionTitle('WhatsApp-Scan'),
                _SettingsGroup(
                  children: [
                    _ExpandableSettingsRow(
                      icon: Icons.chat_outlined,
                      title: 'WhatsApp-Gruppenlink',
                      subtitle:
                          'Wird beim Scan-Button direkt in WhatsApp geöffnet',
                      expanded: _expandedWhatsAppSection == _groupLinkSection,
                      onTap: () => _toggleWhatsAppSection(_groupLinkSection),
                      child: TextField(
                        controller: _whatsAppGroupLinkController,
                        focusNode: _whatsAppGroupLinkFocusNode,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(fontSize: 15),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'https://chat.whatsapp.com/...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _saveWhatsAppGroupLink(),
                        onEditingComplete: () {
                          _saveWhatsAppGroupLink();
                          _whatsAppGroupLinkFocusNode.unfocus();
                        },
                        onTapOutside: (_) {
                          _saveWhatsAppGroupLink();
                          _whatsAppGroupLinkFocusNode.unfocus();
                        },
                      ),
                    ),
                    const _SettingsDivider(),
                    _ExpandableSettingsRow(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Blockierte Scan-Wörter',
                      subtitle:
                          'Wörter oder Phrasen, die nicht als Spieler erkannt werden sollen',
                      expanded:
                          _expandedWhatsAppSection == _blockedWordsSection,
                      onTap: () => _toggleWhatsAppSection(_blockedWordsSection),
                      child: TextField(
                        controller: _blockedWordsController,
                        focusNode: _blockedWordsFocusNode,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(fontSize: 15),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'ich, nicht, da, stimmabgaben',
                          helperText: 'Kommagetrennt · leer = kein Wortfilter',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _saveBlockedWords(),
                        onEditingComplete: () {
                          _saveBlockedWords();
                          _blockedWordsFocusNode.unfocus();
                        },
                        onTapOutside: (_) {
                          _saveBlockedWords();
                          _blockedWordsFocusNode.unfocus();
                        },
                      ),
                    ),
                    const _SettingsDivider(),
                    _ExpandableSettingsRow(
                      icon: Icons.swap_horiz,
                      title: 'Begriffe ersetzen',
                      subtitle: 'Erkannte Namen beim WhatsApp-Scan automatisch ersetzen',
                      expanded:
                          _expandedWhatsAppSection == _scanReplacementsSection,
                      onTap: () => _toggleWhatsAppSection(_scanReplacementsSection),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ein erkannter Begriff wird nur bei vollständiger '
                            'Übereinstimmung ersetzt (Groß-/Kleinschreibung egal).',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 13,
                              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (settings.scanReplacements.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Noch keine Zuordnungen angelegt',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.grey600,
                                ),
                              ),
                            )
                          else
                            for (int i = 0; i < settings.scanReplacements.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _openScanReplacementEditor(index: i),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            '${settings.scanReplacements[i].find}  →  ${settings.scanReplacements[i].replaceWith}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Zuordnung bearbeiten',
                                      onPressed: () => _openScanReplacementEditor(index: i),
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                    ),
                                    IconButton(
                                      tooltip: 'Zuordnung löschen',
                                      onPressed: () => _removeScanReplacement(i),
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                          OutlinedButton.icon(
                            onPressed: () => _openScanReplacementEditor(),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Zuordnung hinzufügen'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Trainings-Reminder'),
                _SettingsGroup(
                  children: [
                    if (settings.weeklyReminders.isEmpty)
                      const _EmptyReminderRow()
                    else
                      for (
                        int i = 0;
                        i < settings.weeklyReminders.length;
                        i++
                      ) ...[
                        _ExpandableReminderRow(
                          reminder: settings.weeklyReminders[i],
                          expanded:
                              _expandedReminderId ==
                              settings.weeklyReminders[i].id,
                          onTap: () {
                            setState(() {
                              final reminderId =
                                  settings.weeklyReminders[i].id;
                              _expandedReminderId =
                                  _expandedReminderId == reminderId
                                  ? null
                                  : reminderId;
                            });
                          },
                          onEdit: () => _openReminderEditor(
                            reminder: settings.weeklyReminders[i],
                          ),
                        ),
                        if (i < settings.weeklyReminders.length - 1)
                          const _SettingsDivider(),
                      ],
                    const _SettingsDivider(),
                    _AddReminderRow(onTap: () => _openReminderEditor()),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Intelligente Teameinteilung'),
                const _SettingsGroup(
                  children: [
                    _AboutTile(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanReplacementDialog extends StatefulWidget {
  final ScanReplacement? replacement;
  final List<String> existingTerms;

  const _ScanReplacementDialog({
    required this.replacement,
    required this.existingTerms,
  });

  @override
  State<_ScanReplacementDialog> createState() => _ScanReplacementDialogState();
}

class _ScanReplacementDialogState extends State<_ScanReplacementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _findController;
  late final TextEditingController _replaceController;

  @override
  void initState() {
    super.initState();
    _findController = TextEditingController(text: widget.replacement?.find ?? '');
    _replaceController = TextEditingController(
      text: widget.replacement?.replaceWith ?? '',
    );
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ScanReplacement(
        find: _findController.text.trim(),
        replaceWith: _replaceController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.replacement == null ? 'Begriff ersetzen' : 'Zuordnung bearbeiten',
        style: Theme.of(context).textTheme.displayLarge,
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _findController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Erkannter Begriff',
                  hintText: 'Du',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final term = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
                  if (term.isEmpty) return 'Bitte einen Begriff eingeben';
                  if (widget.existingTerms.any((other) =>
                      other.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() == term)) {
                    return 'Dieser Begriff ist bereits zugeordnet';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _replaceController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Ersetzen durch',
                  hintText: 'Vorname Nachname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Bitte einen Ersatztext eingeben'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : AppTheme.grey800,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Speichern', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.grey600,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 26,
            color: isDark ? AppTheme.grey300 : AppTheme.grey700,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.grey600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _ExpandableSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _ExpandableSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppTheme.grey600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            child: child,
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _EmptyReminderRow extends StatelessWidget {
  const _EmptyReminderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none,
            size: 26,
            color: AppTheme.grey600,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Noch keine wöchentlichen Reminder eingerichtet',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.grey600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableReminderRow extends StatelessWidget {
  final WeeklyReminder reminder;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ExpandableReminderRow({
    required this.reminder,
    required this.expanded,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 26,
                    color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      reminder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 17,
                                color: AppTheme.grey600,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _weekdayLabel(reminder.weekday),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.grey600,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 18,
                                color: AppTheme.grey600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_formatTime(reminder.hour, reminder.minute)} Uhr',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.grey600,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            reminder.playSound
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            size: 17,
                            color: AppTheme.grey600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            reminder.playSound ? 'Ton' : 'Kein Ton',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppTheme.grey600,
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 14),
                          Icon(
                            reminder.enableVibration
                                ? Icons.vibration
                                : Icons.phone_android_outlined,
                            size: 17,
                            color: AppTheme.grey600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            reminder.enableVibration
                                ? 'Vibration'
                                : 'Keine Vibration',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppTheme.grey600,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Reminder bearbeiten',
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 21,
                    color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _AddReminderRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddReminderRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.add_alert_outlined,
                size: 26,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder hinzufügen',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Name, Wochentag und Uhrzeit festlegen',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.grey600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.add,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: isDark ? AppTheme.grey700 : AppTheme.grey300,
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  final WeeklyReminder? reminder;

  const _ReminderDialog({this.reminder});

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final TextEditingController _nameController;
  late int _weekday;
  late TimeOfDay _time;
  late bool _playSound;
  late bool _enableVibration;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;

    _nameController = TextEditingController(text: reminder?.name ?? '');
    _weekday = reminder?.weekday ?? DateTime.monday;
    _time = TimeOfDay(
      hour: reminder?.hour ?? 18,
      minute: reminder?.minute ?? 0,
    );
    _playSound = reminder?.playSound ?? true;
    _enableVibration = reminder?.enableVibration ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _ReminderDialogResult(
        name: name,
        weekday: _weekday,
        hour: _time.hour,
        minute: _time.minute,
        playSound: _playSound,
        enableVibration: _enableVibration,
      ),
    );
  }

  Future<void> _pickTime() async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Uhrzeit für den Reminder',
      cancelText: 'Abbrechen',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime == null || !mounted) return;
    setState(() {
      _time = newTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.reminder != null;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit_notifications : Icons.add_alert),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEditing ? 'Reminder bearbeiten' : 'Reminder hinzufügen',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: !isEditing,
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Mittwochstraining',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(
                labelText: 'Wochentag',
                border: OutlineInputBorder(),
              ),
              dropdownColor: isDark ? AppTheme.navigationBarDark : Colors.white,
              items: List.generate(7, (index) {
                final weekday = index + 1;
                return DropdownMenuItem(
                  value: weekday,
                  child: Text(_weekdayLabel(weekday)),
                );
              }),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _weekday = value;
                });
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Uhrzeit',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.schedule),
                ),
                child: Text(
                  '${_formatTime(_time.hour, _time.minute)} Uhr',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _playSound
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
              ),
              title: Text(
                'Ton',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _playSound,
              activeThumbColor: AppTheme.primaryBlue.withAlpha(120),
              activeTrackColor: AppTheme.primaryBlue,
              onChanged: (value) {
                setState(() {
                  _playSound = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _enableVibration
                    ? Icons.vibration
                    : Icons.phone_android_outlined,
              ),
              title: Text(
                'Vibration',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _enableVibration,
              activeThumbColor: AppTheme.primaryBlue.withAlpha(120),
              activeTrackColor: AppTheme.primaryBlue,
              onChanged: (value) {
                setState(() {
                  _enableVibration = value;
                });
              },
            ),
            if (isEditing) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.deleteRed,
                    side: const BorderSide(color: AppTheme.deleteRed),
                  ),
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(const _ReminderDialogResult.delete());
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Reminder löschen'),
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            SizedBox(
              height: 40,
              width: 135,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.grey700 : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.transparent : AppTheme.grey300,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Abbrechen',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 40,
              width: 135,
              child: TextButton(
                onPressed: _save,
                child: Text(
                  'Speichern',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReminderDialogResult {
  final String name;
  final int weekday;
  final int hour;
  final int minute;
  final bool playSound;
  final bool enableVibration;
  final bool deleteRequested;

  const _ReminderDialogResult({
    required this.name,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.playSound,
    required this.enableVibration,
  }) : deleteRequested = false;

  const _ReminderDialogResult.delete()
    : name = '',
      weekday = DateTime.monday,
      hour = 0,
      minute = 0,
      playSound = true,
      enableVibration = true,
      deleteRequested = true;
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 18),
        leading: Icon(
          Icons.info_outline,
          size: 26,
          color: isDark ? AppTheme.grey300 : AppTheme.grey700,
        ),
        title: Text(
          'About',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Wie die intelligente Teameinteilung funktioniert',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.grey600,
            fontSize: 13,
          ),
        ),
        iconColor: isDark ? AppTheme.grey300 : AppTheme.grey700,
        collapsedIconColor: isDark ? AppTheme.grey300 : AppTheme.grey700,
        children: [
          Text(
            'Die intelligente Teameinteilung sucht nach der besten Aufteilung der ausgewählten Spieler in zwei Teams. Technisch ist das ein Partition-Problem: Es werden mögliche Team-Kombinationen verglichen und die Variante mit dem kleinsten Unterschied ausgewählt.\n\n'
            'Als Stärke wird die Siegquote eines Spielers verwendet. Spieler, die weniger als die eingestellte Anzahl an Mindestspielen haben, werden nicht mit ihrer echten Siegquote, sondern neutral mit 0.5 berücksichtigt. Dadurch werden neue Spieler nicht durch wenige zufällige Ergebnisse zu stark bewertet.\n\n'
            'Verglichen wird nicht die Summe der Teamstärken, sondern die Durchschnittsstärke pro Team. Dadurch bleibt der Vergleich fair, auch wenn ein Team bei ungerader Spielerzahl eine Person mehr hat.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              height: 1.35,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Montag';
    case DateTime.tuesday:
      return 'Dienstag';
    case DateTime.wednesday:
      return 'Mittwoch';
    case DateTime.thursday:
      return 'Donnerstag';
    case DateTime.friday:
      return 'Freitag';
    case DateTime.saturday:
      return 'Samstag';
    case DateTime.sunday:
      return 'Sonntag';
    default:
      return 'Unbekannt';
  }
}

String _formatTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
