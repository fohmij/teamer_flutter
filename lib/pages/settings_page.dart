import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/services/app_settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _minGamesController;
  late final FocusNode _minGamesFocusNode;

  @override
  void initState() {
    super.initState();
    _minGamesController = TextEditingController(
      text: appSettingsController.value.minGamesForFullWeight.toString(),
    );
    _minGamesFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _minGamesController.dispose();
    _minGamesFocusNode.dispose();
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

            if (!_minGamesFocusNode.hasFocus &&
                _minGamesController.text != currentMinGames) {
              _minGamesController.text = currentMinGames;
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
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Intelligente Teameinteilung'),
                _SettingsGroup(
                  children: [
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
                          decoration: InputDecoration(
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
                    const _SettingsDivider(),
                    const _AboutTile(),
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
        color: isDark ? AppTheme.navigationBarDark : AppTheme.navigationBarLight,
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
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(height: 1.35, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
