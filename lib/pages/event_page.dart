import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

class EventPage extends StatefulWidget {
  EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 250, 236),
      appBar: AppBar(
        title: Text('Street-Floorball 2025',
            style: TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            )),
        backgroundColor: Color.fromARGB(255, 243, 250, 236),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Image(image: AssetImage('assets/pictures/Street_Floorball.jpg')),
              Text(
                  '\nFloorball hat eine neue Spielform für die Sommermonate: Street Floorball \n',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                  'Aus der Not heraus während der Corona-Pandemie in Deutschland aufgebaut, finden in immer mehr Bundesländern und Städten Street Floorball Turniere statt.\n',
                  style: TextStyle(fontSize: 18)),
              Text(
                  'Immer mehr Vereine schaffen sich auch eigene Street Floorball-Courts an, um im Sommerhalbjahr weitere Trainingsflächen zu haben oder der heißen Sporthalle zu entfliehen.\n',
                  style: TextStyle(fontSize: 18)),
              Text(
                  'Street Floorball bietet ein völlig neues Floorball-Erlebnis und jede Menge Spielspaß. Als Mixed-Sportart spielt jeder gegen jeden, unabhängig von Geschlecht, Alter oder Können.\n',
                  style: TextStyle(fontSize: 18)),
              Padding(
                padding: const EdgeInsets.only(left: 48.0, right: 48.0),
                child: Stack(
                  children: [
                    Image(
                        image: AssetImage(
                            'assets/pictures/street_floorball_logo.png')),
                    Positioned.fill(
                      child: TextButton(
                        onPressed: () {
                          launchUrl(
                            Uri.https("street.floorball.de"),
                          );
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all<OutlinedBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        child: SizedBox
                            .shrink(), // Der Button ist unsichtbar, aber noch klickbar
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
    );
  }
}
