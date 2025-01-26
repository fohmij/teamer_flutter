import 'package:flutter/material.dart';
import 'package:teamer/pages/home_page.dart';

class StatsPage extends StatefulWidget {
  StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              eventCard(),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    statsCard("Beste \nSpieler", Icons.sports_hockey),
                    SizedBox(
                      width: 20,
                    ),
                    statsCard("Alle \nStatitiken", Icons.equalizer),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [statsCard("Alle \nSpiele", Icons.access_time)],
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  SizedBox eventCard() {
    return SizedBox(
      height: 250,
      child: Card(
        elevation: 2,
        child: Stack(children: <Widget>[
          SizedBox(
            height: 300,
            width: 400,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset('assets/pictures/Street_Floorball.jpg',
                  fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 20),
            child: Text(
              "Street-Floorball 2025",
              style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Positioned.fill(
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/eventpage');
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
          )
        ]),
      ),
    );
  }

  Expanded statsCard(String label, IconData icon) {
    return Expanded(
      child: SizedBox(
        height: 120,
        child: Card(
          elevation: 1,
          color: const Color.fromARGB(255, 205, 235, 205),
          child: Stack(children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 15, left: 15),
              child: Text(
                label,
                style: TextStyle(
                    height: 1.1, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    icon,
                    size: 30,
                  ),
                ],
              ),
            )
          ]),
        ),
      ),
    );
  }
}
