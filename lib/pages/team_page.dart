import 'package:flutter/material.dart';
import 'package:teamer/app_theme/app_theme.dart';
import '../database/player.dart';
import 'package:teamer/database/database_services.dart';

class TeamPage extends StatefulWidget {
  TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  final DatabaseService _databaseService = DatabaseService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teams'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                  child: Text(
                    'Team Grün',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.green,
                    ),
                  ),
                ),
                FutureBuilder<List<Player>>(
                  future: _databaseService.getPlayers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();

                    final filtered = snapshot.data!
                        .where(
                            (player) => player.team == 0 && player.status == 1)
                        .toList();

                    final height = (filtered.length) * 60.0;

                    return SizedBox(
                      height: height,
                      child: ListView.separated(
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                              title: Text(
                            filtered[index].name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ));
                        },
                        separatorBuilder: (context, index) =>
                            Divider(height: 1),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      'Team Rot',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                FutureBuilder<List<Player>>(
                  future: _databaseService.getPlayers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return CircularProgressIndicator();
                    }
                    final filtered = snapshot.data!
                        .where(
                            (player) => player.team == 1 && player.status == 1)
                        .toList();

                    final height = (filtered.length) * 60.0;

                    return SizedBox(
                      height: height,
                      child: ListView.separated(
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                              title: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              filtered[index].name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ));
                        },
                        separatorBuilder: (context, index) =>
                            Divider(height: 1),
                      ),
                    );
                  },
                ),
                SizedBox(height: 40),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 100,
                      width: 100,
                      child: TextField(
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                        keyboardType: TextInputType.numberWithOptions(),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Grün',
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32, left: 20, right: 20),
                      child: Text(
                        'Tore',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      width: 100,
                      child: TextField(
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                        ),
                        keyboardType: TextInputType.numberWithOptions(),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Rot',
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Speichern',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 100,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
