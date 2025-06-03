import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:teamer/app_theme/app_theme.dart';

class CoachingZonePage extends StatefulWidget {
  CoachingZonePage({super.key});

  @override
  State<CoachingZonePage> createState() => _CoachingZonePageState();
}

class _CoachingZonePageState extends State<CoachingZonePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Coaching-Zone',
          ),
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.navigationBarDark
              : AppTheme.navigationBarLight,
        ),
        body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Image(image: AssetImage('assets/pictures/coaching.jpeg')),
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
                          child: linkCard(
                              "Sportreferat\nAachen", Icons.diversity_3,
                              link: "https://www.sr.rwth-aachen.de/"),
                        )),
                        SizedBox(
                          width: 20,
                        ),
                        Expanded(
                            child: SizedBox(
                          height: 120,
                          child: linkCard(
                              "Self- \nService", Icons.assignment_turned_in,
                              link:
                                  "https://buchung.hsz.rwth-aachen.de/cgi/self-service.cgi?klident=6307480c0736773ba7859a8710564fab&klcode=64c3c292e987d13c0766a19d649d4bb4c0596d15"),
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
                  child: statsCard("Schul-\nRegelwerk", Icons.sports,
                      page: '/rules'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48.0, right: 48.0),
                    child: Stack(
                      children: [
                        Image.asset(
                            Theme.of(context).brightness == Brightness.dark
                                ? 'assets/pictures/street_floorball_dark.png'
                                : 'assets/pictures/street_floorball_logo.png'),
                        Positioned.fill(
                          child: TextButton(
                            onPressed: () {
                              launchUrl(
                                Uri.https("street.floorball.de"),
                              );
                            },
                            style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent),
                            child: SizedBox
                                .shrink(), // Der Button ist unsichtbar, aber noch klickbar
                          ),
                        ),
                      ],
                    ),
                  ),
                ]))));
  }

  Card statsCard(String label, IconData icon, {String page = '/eventpage'}) {
    return Card(
      color: Theme.of(context).cardColor,
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

  Card linkCard(String label, IconData icon,
      {String link = "street.floorball.de"}) {
    return Card(
      color: Theme.of(context).cardColor,
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
              launchUrl(
                Uri.parse(link),
              );
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
}
