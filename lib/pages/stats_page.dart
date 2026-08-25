import 'dart:io';

import 'package:teamer/app_theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/event_data.dart';
import 'package:teamer/services/app_settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
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

  Future<void> _openEventPage() async {
    await Navigator.pushNamed(context, '/eventpage');
    if (mounted) _reloadEvent();
  }

  Future<void> _openWhatsAppGroup() async {
    final storedLink = appSettingsController.value.whatsAppGroupLink.trim();

    if (storedLink.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kein WhatsApp-Gruppenlink hinterlegt.',
          ),
        ),
      );
      return;
    }

    var normalizedLink = storedLink;

    if (!normalizedLink.contains('://')) {
      normalizedLink = 'https://$normalizedLink';
    }

    final uri = Uri.tryParse(normalizedLink);

    if (uri == null || !uri.hasScheme) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der hinterlegte WhatsApp-Gruppenlink ist ungültig.',
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp konnte nicht geöffnet werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            eventCard(),
            const SizedBox(height: 12),

            // Alle Spiele + Alle Stats
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: statsCard(
                        'Alle \nSpiele',
                        Icons.history,
                        page: '/all_games',
                        statsCardColor: Colors.deepOrangeAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: statsCard(
                        'Alle \nStats',
                        Icons.equalizer,
                        page: '/all_stats',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // WhatsApp-Gruppe
            SizedBox(
              height: 110,
              width: double.infinity,
              child: whatsAppCard(),
            ),

            const SizedBox(height: 12),

            // Coaching-Zone
            SizedBox(
              height: 110,
              width: double.infinity,
              child: statsCardColord(
                'Coaching- \nZone',
                Icons.star,
                const Color.fromARGB(255, 221, 2, 56),
                page: '/coachingzonepage',
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Card statsCard(
    String label,
    IconData icon, {
    Color? statsCardColor,
    String page = '/eventpage',
  }) {
    return Card(
      color: statsCardColor ?? Theme.of(context).cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 15, left: 15),
            child: Text(
              label,
              style: const TextStyle(
                height: 1.1,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 20,
            child: Icon(
              icon,
              size: 28,
            ),
          ),
          Positioned.fill(
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, page);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Card statsCardColord(
    String label,
    IconData icon,
    Color statsCardColor, {
    String page = '/eventpage',
  }) {
    return Card(
      color: statsCardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 15, left: 15),
            child: Text(
              label,
              style: const TextStyle(
                height: 1.1,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 20,
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
          Positioned.fill(
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, page);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Card whatsAppCard() {
    return Card(
      color: const Color.fromARGB(255, 37, 211, 102),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 15, left: 15),
            child: Text(
              'WhatsApp-\nGruppe',
              style: TextStyle(
                height: 1.1,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 20,
            child: Icon(
              MdiIcons.whatsapp,
              size: 28,
              color: Colors.black,
            ),
          ),
          Positioned.fill(
            child: TextButton(
              onPressed: _openWhatsAppGroup,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget eventCard() {
    return SizedBox(
      height: 200,
      child: FutureBuilder<EventData>(
        future: _eventFuture,
        builder: (context, snapshot) {
          final event = snapshot.data ?? EventData.defaults;

          return Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildStoredImage(event.imagePath),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.48),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: TextButton(
                    onPressed: _openEventPage,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoredImage(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
      );
    }

    final file = File(imagePath);

    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
      );
    }

    return Image.asset(
      EventData.defaultImagePath,
      fit: BoxFit.cover,
    );
  }
}