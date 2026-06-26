import 'package:flutter/material.dart';
import 'package:teamer/database/database_services.dart';
import 'package:teamer/app_theme/app_theme.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:teamer/pages/scan.dart';
import '../database/player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class TeamSelectPage extends StatefulWidget {
  const TeamSelectPage({super.key});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  final FocusNode _focusNode =
      FocusNode(); // um die Tastatur beim Spielererstellen direkt zu öffnen

  String? _player;

  bool allBtnSelected = false;

  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture = _databaseService.getPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: _playersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final players = snapshot.data!;
        final selectedCount = players.where((p) => p.status == 1).length;
        final enoughPlayers = selectedCount >= 2;
        final notTooManyPlayers = selectedCount <= 30;

        _syncAllButtonState(players);

        return _TeamSelectScaffold(
          header: _buildHeader(players, selectedCount),
          playersList: _buildPlayersList(players),
          floatingActionButton: _buildFloatingActionButtons(
            enoughPlayers: enoughPlayers,
            notTooManyPlayers: notTooManyPlayers,
          ),
        );
      },
    );
  }

  void _syncAllButtonState(List<Player> players) {
    final allAreSelected =
        players.isNotEmpty && players.every((p) => p.status == 1);

    if (allBtnSelected != allAreSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          allBtnSelected = allAreSelected;
        });
      });
    }
  }

  Widget _buildHeader(List<Player> players, int selectedCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: isDark
              ? AppTheme.navigationBarDark
              : AppTheme.navigationBarLight,
          child: Row(
            children: [
              const SizedBox(width: 15),
              Text('Name', style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              _buildSelectAllControl(),
            ],
          ),
        ),
        _SelectedCountIndicator(
          selectedCount: selectedCount,
          totalCount: players.length,
        ),
      ],
    );
  }

  Widget _buildSelectAllControl() {
    return Row(
      children: [
        Text('Alle', style: Theme.of(context).textTheme.labelMedium),
        Checkbox(
          value: allBtnSelected,
          activeColor: AppTheme.btnBlue2,
          checkColor: Colors.white,
          side: const BorderSide(color: AppTheme.grey600, width: 2),
          onChanged: _toggleAllPlayers,
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Future<void> _toggleAllPlayers(bool? value) async {
    final newStatus = value == true ? 1 : 0;
    await _databaseService.updateAllPlayersStatus(newStatus);

    setState(() {
      allBtnSelected = value ?? false;
      _playersFuture = _databaseService.getPlayers();
    });
  }

  Widget _buildPlayersList(List<Player> players) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: ListView.separated(
        itemCount: players.length + 2,
        separatorBuilder: (context, index) {
          return Divider(
            thickness: 1,
            height: 1,
            color: isDark ? AppTheme.navigationBarDark : AppTheme.grey400,
          );
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SizedBox(height: 8);
          }

          if (index == players.length + 1) {
            return _buildAddPlayerListItem();
          }

          final player = players[index - 1];
          return _buildPlayerListItem(player);
        },
      ),
    );
  }

  Widget _buildAddPlayerListItem() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppTheme.grey600),
            Padding(
              padding: const EdgeInsets.only(right: 25.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                onPressed: () => _showAddPlayerDialog(),
                child: Text(
                  'Neuer Spieler',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 190),
      ],
    );
  }

  Widget _buildPlayerListItem(Player player) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(iconColor: WidgetStatePropertyAll(Colors.white)),
        ),
      ),
      child: Slidable(
        startActionPane: ActionPane(
          extentRatio: 0.2,
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              backgroundColor: AppTheme.deleteRed,
              onPressed: (_) => _showDeletePlayerDialog(player),
              icon: Icons.delete,
              borderRadius: BorderRadius.circular(7),
              foregroundColor: Colors.white,
            ),
          ],
        ),
        child: ColoredBox(
          color: player.status == 0
              ? Theme.of(context).scaffoldBackgroundColor
              : isDark
              ? AppTheme.grey700
              : AppTheme.btnBlue1,
          child: ListTile(
            onTap: () => _togglePlayer(player),
            onLongPress: () =>
                _showDeletePlayerDialog(player, showPlayerName: true),
            title: Padding(
              padding: const EdgeInsets.only(left: 14.0),
              child: Text(
                player.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            trailing: Checkbox(
              value: player.status == 1,
              activeColor: AppTheme.primaryBlue,
              checkColor: Colors.white,
              onChanged: (value) => _setPlayerStatus(player, value),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _togglePlayer(Player player) async {
    final newStatus = player.status == 1 ? 0 : 1;
    await _databaseService.updatePlayerStatus(player.id, newStatus);

    setState(() {
      _playersFuture = _databaseService.getPlayers();
    });
  }

  Future<void> _setPlayerStatus(Player player, bool? value) async {
    final newStatus = value == true ? 1 : 0;
    await _databaseService.updatePlayerStatus(player.id, newStatus);
    final players = await _databaseService.getPlayers();

    setState(() {
      _playersFuture = Future.value(players);

      if (newStatus == 0 && allBtnSelected) {
        allBtnSelected = false;
      } else {
        allBtnSelected =
            players.isNotEmpty && players.every((p) => p.status == 1);
      }
    });
  }

  void _showAddPlayerDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isDark ? AppTheme.grey700 : Colors.white),
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        title: Text(
          'Neuer Spieler',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 30.0),
                child: TextField(
                  style: Theme.of(context).textTheme.bodyMedium,
                  onChanged: (value) {
                    setState(() {
                      _player = value;
                    });
                  },
                  onSubmitted: (value) {
                    _submitNewPlayer();
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    hintText: 'Name...',
                  ),
                  focusNode: _focusNode,
                  autofocus: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 135,
                      height: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.grey700
                              : Colors.white,
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: isDark
                                ? Colors.transparent
                                : AppTheme.grey300,
                            width: 1,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
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
                        onPressed: _submitNewPlayer,
                        child: Text(
                          'Fertig',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanPlayers() async {
    final changed = await showWhatsAppPollScanDrawer(context);

    if (changed == true && mounted) {
      setState(() {
        _playersFuture = _databaseService.getPlayers();
      });
    }
  }

  void _submitNewPlayer() {
    if (_player == null || _player == '') {
      return;
    }

    _databaseService.addPlayer(_player!).then((_) {
      setState(() {
        _player = null;
        _playersFuture = _databaseService.getPlayers();
      });

      Navigator.pop(context);
    });
  }

  void _showDeletePlayerDialog(Player player, {bool showPlayerName = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DeleteDialogTitle(),
            const Padding(padding: EdgeInsets.only(top: 6.0), child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: showPlayerName
                  ? Text.rich(
                      TextSpan(
                        text: 'Soll ',
                        children: [
                          TextSpan(
                            text: player.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: ' wirklich dauerhaft gelöscht werden?',
                          ),
                        ],
                      ),
                    )
                  : Text(
                      'Soll der Spieler wirklich dauerhaft gelöscht werden?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Divider(),
            ),
            _DeleteDialogActions(
              onCancel: () {
                Navigator.pop(context);
              },
              onDelete: () => _deletePlayer(player),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePlayer(Player player) {
    _databaseService.deletePlayer(player.id).then((_) {
      setState(() {
        _playersFuture = _databaseService.getPlayers();
      });
    });

    Navigator.pop(context);
  }

  Widget _buildFloatingActionButtons({
    required bool enoughPlayers,
    required bool notTooManyPlayers,
  }) {
    return Transform.translate(
      offset: const Offset(12, 0), // positiv = weiter nach rechts
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RevealFloatingActionButton(
            key: const ValueKey('playerRevealFab'),
            mainButton: _PlayerFloatingButton(onPressed: _showAddPlayerDialog),
            revealedButton: _ScanFloatingButton(onPressed: _scanPlayers),
          ),
          const SizedBox(height: 20, width: 150),
          _RevealFloatingActionButton(
            key: const ValueKey('teamRevealFab'),
            mainButton: _RandomTeamFloatingButton(
              onPressed: () => _randomTeam(enoughPlayers),
            ),
            revealedButton: _BalancedTeamFloatingButton(
              onPressed: () => _optimizedTeam(enoughPlayers, notTooManyPlayers),
            ),
          ),
          const SizedBox(height: 110, width: 150),
        ],
      ),
    );
  }

  Future<void> _randomTeam(bool enoughPlayers) async {
    if (enoughPlayers) {
      await _databaseService.randomTeams();
      if (!mounted) return;
      Navigator.pushNamed(context, '/team');
    } else {
      _showPlayerSelectionToast('Bitte min. 2 Spieler auswählen');
    }
  }

  Future<void> _optimizedTeam(
    bool enoughPlayers,
    bool notTooManyPlayers,
  ) async {
    if (enoughPlayers && notTooManyPlayers) {
      await _databaseService.optimizedTeam();
      if (!mounted) return;
      Navigator.pushNamed(context, '/team').then((_) {
        setState(() {
          _playersFuture = _databaseService.getPlayers();
        });
      });
    } else {
      _showPlayerSelectionToast('Bitte 2-20 Spieler auswählen');
    }
  }

  void _showPlayerSelectionToast(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isDark ? Colors.black : Colors.white,
      textColor: isDark ? Colors.white : Colors.black,
    );
  }
}

class _TeamSelectScaffold extends StatelessWidget {
  final Widget header;
  final Widget playersList;
  final Widget floatingActionButton;

  const _TeamSelectScaffold({
    required this.header,
    required this.playersList,
    required this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [header, playersList]),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _SelectedCountIndicator extends StatelessWidget {
  final int selectedCount;
  final int totalCount;

  const _SelectedCountIndicator({
    required this.selectedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, color: AppTheme.grey600, size: 18.0),
          const SizedBox(width: 5),
          Text(
            '$selectedCount/$totalCount',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight(600),
              color: AppTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialogTitle extends StatelessWidget {
  const _DeleteDialogTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2.0),
            child: Icon(Icons.delete, size: 25.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              'Löschen',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialogActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _DeleteDialogActions({required this.onCancel, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          height: 40,
          width: 135,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.grey700 : Colors.white,
              foregroundColor: Colors.white,
              side: BorderSide.none,
            ),
            onPressed: onCancel,
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
            style: TextButton.styleFrom(backgroundColor: AppTheme.deleteRed),
            onPressed: onDelete,
            child: Text(
              'Löschen',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PlayerFloatingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 65,
      height: 65,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: isDark ? AppTheme.btnBlue2 : AppTheme.btnBlue1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
            Text(
              'Player',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RandomTeamFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RandomTeamFloatingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 65,
      height: 65,
      child: FloatingActionButton(
        heroTag: 'randomBtn',
        onPressed: onPressed,
        backgroundColor: AppTheme.btnBlue3,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino_outlined),
            Text('Random', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BalancedTeamFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BalancedTeamFloatingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 65,
      height: 65,
      child: FloatingActionButton(
        heroTag: 'partitionBtn',
        backgroundColor: AppTheme.btnBlue3,
        onPressed: onPressed,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Symbols.balance), Text('Team')],
        ),
      ),
    );
  }
}

class _ScanFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScanFloatingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 65,
      height: 65,
      child: FloatingActionButton(
        heroTag: 'scanBtn',
        onPressed: onPressed,
        backgroundColor: isDark ? AppTheme.btnBlue2 : AppTheme.btnBlue1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner,
              color: isDark ? Colors.white : Colors.black,
            ),
            Text(
              'Scan',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealFloatingActionButton extends StatefulWidget {
  final Widget mainButton;
  final Widget revealedButton;

  const _RevealFloatingActionButton({
    super.key,
    required this.mainButton,
    required this.revealedButton,
  });

  @override
  State<_RevealFloatingActionButton> createState() =>
      _RevealFloatingActionButtonState();
}

class _RevealFloatingActionButtonState
    extends State<_RevealFloatingActionButton>
    with SingleTickerProviderStateMixin {
  static const double _buttonSize = 65;

  // Abstand zwischen Hauptbutton und Scan/Random im geöffneten Zustand
  static const double _buttonGap = 20;

  // Abstand zwischen Hauptbutton und Pfeil im geschlossenen Zustand
  static const double _arrowGap = 1;
  static const double _arrowSize = 22;

  // Abstand von Scan/Random zum rechten Rand des Reveal-Bereichs
  static const double _revealedButtonRightInset = 24;

  static const double _height = _buttonSize;

  static const double _width =
      (_buttonSize * 2) + _buttonGap + _revealedButtonRightInset;

  static const double _mainButtonClosedRightInset = _arrowSize + _arrowGap;

  static const double _mainButtonOpenedRightInset =
      _revealedButtonRightInset + _buttonSize + _buttonGap;

  static const double _maxRevealOffset =
      _mainButtonOpenedRightInset - _mainButtonClosedRightInset;

  double _dragOffset = 0;

  late final AnimationController _hintController;
  late final Animation<double> _hintAnimation;

  @override
  void initState() {
    super.initState();

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _hintAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 18,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_hintController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hintController.forward();
      }
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset - details.delta.dx).clamp(
        0.0,
        _maxRevealOffset,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _dragOffset = _dragOffset > _maxRevealOffset / 2 ? _maxRevealOffset : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hintAnimation,
      builder: (context, _) {
        final totalOffset = (_dragOffset + _hintAnimation.value).clamp(
          0.0,
          _maxRevealOffset,
        );

        final revealProgress = totalOffset / _maxRevealOffset;
        final isClosed = totalOffset < 0.5;

        return SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: _revealedButtonRightInset,
                child: IgnorePointer(
                  ignoring: revealProgress < 0.9,
                  child: Opacity(
                    opacity: revealProgress,
                    child: widget.revealedButton,
                  ),
                ),
              ),

              Positioned(
                right: _mainButtonClosedRightInset + totalOffset,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: _handleDragUpdate,
                  onHorizontalDragEnd: _handleDragEnd,
                  child: widget.mainButton,
                ),
              ),

              Positioned(
                right: 0,
                top: (_buttonSize - _arrowSize) / 2,
                child: AnimatedOpacity(
                  opacity: isClosed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: _arrowSize,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
