import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class PlayersList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      color: playerSelected ? Color.fromARGB(255, 213, 221, 205) : Color.fromARGB(255, 243, 250, 236),
      child: Container(
        width: 10,
        child: Slidable(
          startActionPane: ActionPane(
            extentRatio: 0.2,
            motion: StretchMotion(), 
            children: [
              SlidableAction(
                backgroundColor: Color.fromARGB(255, 236, 152, 130),
                onPressed: deleteFunction, 
                icon: Icons.delete,
                borderRadius: BorderRadius.circular(7),
              ),
            ],
          ),
          endActionPane: ActionPane(
            extentRatio: 0.2,
            motion: StretchMotion(), 
            children: [
              SlidableAction(
                backgroundColor: Color.fromARGB(255, 236, 152, 130),
                onPressed: deleteFunction, 
                icon: Icons.delete,
                borderRadius: BorderRadius.circular(7),
              ),
            ],
          ),
          child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22.0,
                    vertical: 12.0,
                    ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,  // Breite der Checkbox
                        height: 26, // Höhe der Checkbox
                        child: Checkbox(
                          value: playerSelected,
                          onChanged: onChanged,
                          activeColor: Colors.green 
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14.0),
                        child: Text(
                          playersName,
                          style: TextStyle(
                            fontSize: 20,
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