import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/database/team_generator.dart';
import 'package:teamer/services/app_settings_controller.dart';

class TeamAnalysisPage extends StatefulWidget {
  const TeamAnalysisPage({super.key});

  @override
  State<TeamAnalysisPage> createState() => _TeamAnalysisPageState();
}

class _TeamAnalysisPageState extends State<TeamAnalysisPage> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<TeamSplitResult> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _databaseService.getOptimizedTeamPreview();
  }

  void _openTeamPage() {
    Navigator.pushReplacementNamed(
      context,
      '/team',
      arguments: const TeamPageArgs(showAnalysisButton: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team-Analyse'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor:
            isDark ? AppTheme.navigationBarDark : AppTheme.navigationBarLight,
      ),
      body: SafeArea(
        child: FutureBuilder<TeamSplitResult>(
          future: _previewFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final result = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                children: [
                  _SummaryCard(result: result),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        _TeamAnalysisCard(
                          title: 'Team A',
                          players: result.teamA,
                          color: AppTheme.btnBlue3,
                        ),
                        const SizedBox(height: 12),
                        _TeamAnalysisCard(
                          title: 'Team B',
                          players: result.teamB,
                          color: AppTheme.btnBlue2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _openTeamPage,
                      child: Text(
                        'Teams anzeigen',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TeamPageArgs {
  final bool showAnalysisButton;

  const TeamPageArgs({required this.showAnalysisButton});
}

class _SummaryCard extends StatelessWidget {
  final TeamSplitResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minGames = appSettingsController.value.minGamesForFullWeight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey700 : AppTheme.cardColorLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.balance, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intelligente Zuteilung',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      'Unter $minGames Spielen = Wert 0.5 (default Wert)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.grey600,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: 'Ø Team A',
                value: (result.averageTeamA * 100).toStringAsFixed(1),
              ),
              _InfoChip(
                label: 'Ø Team B',
                value: (result.averageTeamB * 100).toStringAsFixed(1),
              ),
              _InfoChip(
                label: 'Diff.',
                value: (result.difference * 100).toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamAnalysisCard extends StatelessWidget {
  final String title;
  final List<WeightedPlayer> players;
  final Color color;

  const _TeamAnalysisCard({
    required this.title,
    required this.players,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: color,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${players.length} Spieler',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: AppTheme.grey400.withValues(alpha: 0.45),
            ),
            itemBuilder: (context, index) {
              final weightedPlayer = players[index];
              final player = weightedPlayer.player;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            'A: ${player.attendance} | echte WR: ${(player.winRate * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.grey600,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _ValueBadge(
                      value:
                          (weightedPlayer.effectiveWinRate * 100).toStringAsFixed(1),
                      fallback: weightedPlayer.usesFallbackWeight,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.navigationBarDark : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.grey300 : AppTheme.grey700,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.grey400 : AppTheme.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String value;
  final bool fallback;

  const _ValueBadge({required this.value, required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          fallback ? 'default Wert' : 'echter Wert',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fallback ? AppTheme.deleteRed : AppTheme.grey600,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}
