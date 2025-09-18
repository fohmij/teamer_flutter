import 'package:flutter/material.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              eventCard(),
              //padding: const EdgeInsets.only(top: 20.0),
              SizedBox(
                height: 20,
              ),
              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: SizedBox(
                      height: 120,
                      child: statsCard("Beste \nSpieler", Icons.sports_hockey),
                    )),
                    SizedBox(
                      width: 20,
                    ),
                    Expanded(
                        child: SizedBox(
                      height: 120,
                      child: statsCard("Alle \nStats", Icons.equalizer),
                    )),
                  ],
                ),
              ),
              SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: statsCard("Alle \nSpiele", Icons.access_time),
              ),
              SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: statsCardColord("Coaching- \nZone", Icons.star, const Color.fromARGB(255, 221, 2, 56),
                    page: '/coachingzonepage'),
              )
            ])));
  }

  Card statsCard(String label, IconData icon, {Color? statsCardColor, String page = '/eventpage'}) {
    return Card(
      color: statsCardColor ?? Theme.of(context).cardColor,
      elevation: 1,
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
        ),
        Positioned.fill(
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, page);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
            child: SizedBox
                .shrink(), // Der Button ist unsichtbar, aber noch klickbar
          ),
        )
      ]),
    );
  }

  Card statsCardColord(String label, IconData icon, Color statsCardColor, {String page = '/eventpage'}) {
    return Card(
      color: statsCardColor ,
      elevation: 1,
      child: Stack(children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 15, left: 15),
          child: Text(
            label,
            style: TextStyle(
                height: 1.1, fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                color: Colors.white,
              ),
            ],
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
            child: SizedBox
                .shrink(), // Der Button ist unsichtbar, aber noch klickbar
          ),
        )
      ]),
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
              borderRadius: BorderRadius.circular(10),
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
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: SizedBox
                  .shrink(), // Der Button ist unsichtbar, aber noch klickbar
            ),
          )
        ]),
      ),
    );
  }
}
