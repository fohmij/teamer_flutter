class EventData {
  final String title;
  final String imagePath;
  final String markdownText;
  final String link;

  const EventData({
    required this.title,
    required this.imagePath,
    required this.markdownText,
    required this.link,
  });

  static const String defaultImagePath =
      'assets/pictures/Street_Floorball.jpg';

  static const EventData defaults = EventData(
    title: 'SFT Hannover 2026',
    imagePath: defaultImagePath,
    markdownText: '''**Floorball hat eine neue Spielform für die Sommermonate: Street Floorball**\n\nAus der Not heraus während der Corona-Pandemie in Deutschland aufgebaut, finden in immer mehr Bundesländern und Städten Street Floorball Turniere statt.\n\nImmer mehr Vereine schaffen sich auch eigene Street Floorball-Courts an, um im Sommerhalbjahr weitere Trainingsflächen zu haben oder der heißen Sporthalle zu entfliehen.\n\nStreet Floorball bietet ein völlig neues Floorball-Erlebnis und jede Menge Spielspaß. Als Mixed-Sportart spielt jeder gegen jeden, unabhängig von Geschlecht, Alter oder Können.\n\nWeitere Informationen zu der diesjährigen Tour gibt es hier:''',
    link: 'https://street.floorball.de',
  );

  EventData copyWith({
    String? title,
    String? imagePath,
    String? markdownText,
    String? link,
  }) {
    return EventData(
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      markdownText: markdownText ?? this.markdownText,
      link: link ?? this.link,
    );
  }
}
