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
        body: SingleChildScrollView(
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

                  final filtered = snapshot.data!.where((player) => player.team == 0 && player.status == 1).toList();

                  final height = (filtered.length) * 60.0;

                  return SizedBox(
                    height: height,
                    child: ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                            title: Text(filtered[index].name));
                      },
                      separatorBuilder: (context, index) => Divider(height: 1),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'Team Rot',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red,
                  ),
                ),
              ),
              FutureBuilder<List<Player>>(
                future: _databaseService.getPlayers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();

                  final filtered = snapshot.data!.where((player) => player.team == 1 && player.status == 1).toList();

                  final height = (filtered.length) * 60.0;

                  return SizedBox(
                    height: height,
                    child: ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                            title: Text(filtered[index].name));
                      },
                      separatorBuilder: (context, index) => Divider(height: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ));
  }
}
/*
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Teams',
          ),
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.navigationBarDark
              : AppTheme.navigationBarLight,
        ),
        body: FutureBuilder(
          future: _databaseService.getPlayers(),
          builder: (context, snapshot) {
            return ListView.separated(
                itemCount: (snapshot.data?.length ?? 0) + 1,
                // itemCount: snapshot.data?.length ?? 0,
                separatorBuilder: (context, index) {
                  return Divider(
                    thickness: 1,
                    height: 1,
                  );
                },
                  );
                );      
  }
*/
