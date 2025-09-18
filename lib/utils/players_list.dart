import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class PlayersList extends StatefulWidget {
  const PlayersList({
    super.key, 
    required this.playersName, 
    required this.playerSelected, 
    required this.onChanged, 
    required this.deleteFunction
  });

  final String playersName;
  final bool playerSelected;
  final Function(bool?)? onChanged;
  final Function(BuildContext)? deleteFunction;

  @override
  PlayersListState createState() => PlayersListState();
}

class PlayersListState extends State<PlayersList> {
  late bool playerSelected;

  @override
  void initState() {
    super.initState();
    playerSelected = widget.playerSelected;
  }

  void toggleCheckbox() {
    setState(() {
      playerSelected = !playerSelected;
    });
    widget.onChanged?.call(playerSelected); // Benachrichtige den Elternteil über die Änderung
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: playerSelected ? Color.fromARGB(255, 213, 221, 205) : Color.fromARGB(255, 243, 250, 236),
      child: Slidable(
        startActionPane: ActionPane(
          extentRatio: 0.2,
          motion: StretchMotion(), 
          children: [
            SlidableAction(
              backgroundColor: Color.fromARGB(255, 240, 73, 31),
              onPressed: widget.deleteFunction, 
              icon: Icons.delete,
              borderRadius: BorderRadius.circular(7),
              foregroundColor: Colors.white,
            ),
          ],
        ),
        endActionPane: ActionPane(
          extentRatio: 0.2,
          motion: StretchMotion(), 
          children: [
            SlidableAction(
              backgroundColor: Color.fromARGB(255, 253, 64, 64),
              onPressed: widget.deleteFunction, 
              icon: Icons.delete,
              borderRadius: BorderRadius.circular(7),
              foregroundColor: Colors.white,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Text(
                      widget.playersName,
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Spacer(),
                  SizedBox(
                    width: 40,  // Breite der Checkbox
                    height: 26, // Höhe der Checkbox
                    child: Checkbox(
                      value: playerSelected,
                      onChanged: widget.onChanged,
                      activeColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            // Button, um die Checkbox zu toggeln
            Positioned.fill(
              child: TextButton(
                onPressed: toggleCheckbox, 
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                child: SizedBox.shrink(), // Der Button ist unsichtbar, aber noch klickbar
              ),
            ),
          ],
        ),
      ),
    );
  }
}
