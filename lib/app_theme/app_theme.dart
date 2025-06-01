import 'package:flutter/material.dart';

class AppTheme {
  static const Color backgroundColorLight = Color.fromARGB(255, 243, 250, 236);
  static const Color backgroundColorDark = Color.fromARGB(255, 26, 24, 32);
  static const Color navigationBarLight = Color.fromARGB(255, 233, 230, 226);
  static const Color navigationBarDark = Color.fromARGB(255, 34, 32, 43);
  static const Color playerSelected = Color.fromARGB(255, 139, 204, 101);
  static const Color grey200 = Color.fromARGB(255, 238, 238, 238);
  static const Color grey300 = Color.fromARGB(255, 224, 224, 224);
  static const Color grey400 = Color.fromARGB(255, 178, 178, 178);
  static const Color grey600 = Color.fromARGB(255, 117, 117, 117);
  static const Color grey800 = Color.fromARGB(255, 66, 66, 66);
  static const Color grey900 = Color.fromARGB(255, 33, 33, 33);
  static const Color cardColorLight = Color.fromARGB(255, 205, 225, 235);
  static const Color primaryBlue = Color.fromARGB(198, 38, 96, 171);
  static const Color secondaryBlue = Color.fromARGB(255, 30, 89, 148);
  static const Color tertiaryBlue = Color.fromARGB(255, 3, 64, 95);
  static const Color deleteRed = Color.fromARGB(255, 185, 88, 81);

  static final lightTheme = ThemeData(
      scaffoldBackgroundColor: backgroundColorLight,
      appBarTheme: const AppBarTheme(
        color: backgroundColorLight, // background AppBar
        iconTheme: IconThemeData(
          color: Colors.black,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.black,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          color: Colors.black,
          fontSize: 20,
        ),
        labelMedium: TextStyle(
          color: grey600,
          fontSize: 20.0,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: Colors.black,
          fontSize: 15,
        ),
        displayLarge: TextStyle(
          color: Colors.black,
          fontSize: 24,
        ),
        displaySmall: TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
          side: const BorderSide(
        color: grey600,
        width: 2.0,
      )),
      cardColor: cardColorLight,
      iconTheme: const IconThemeData(
        color: Colors.black,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.black, // Farbe für ausgewählte Labels
              fontWeight: FontWeight.bold,
              fontSize: 14,
            );
          }
          return const TextStyle(
            color: grey800, // Farbe für nicht ausgewählte Labels
            fontWeight: FontWeight.normal,
            fontSize: 14,
          );
        }),
        backgroundColor: navigationBarLight,
        indicatorColor: primaryBlue,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
        backgroundColor: secondaryBlue,
      ),
      dividerTheme: DividerThemeData(
        color: grey400,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: backgroundColorLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: grey600,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: tertiaryBlue, // Farbe, wenn nicht fokussiert
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: primaryBlue, // Farbe bei Fokus
            width: 2.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              backgroundColor: primaryBlue,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              textStyle: TextStyle(
                color: Colors.black,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)))));

///////////////////////////////////////////////////////
///////////////////////////////////////////////////////
///////////////////////////////////////////////////////
///////////////////////////////////////////////////////

  static final darkTheme = ThemeData(
      scaffoldBackgroundColor: backgroundColorDark,
      appBarTheme: const AppBarTheme(
        color: backgroundColorDark,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        bodyMedium: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        labelMedium: TextStyle(
          color: grey600,
          fontSize: 20.0,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
        displayLarge: TextStyle(
          color: Colors.white,
          fontSize: 24,
        ),
        displaySmall: TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
          side: const BorderSide(
        color: Colors.white,
        width: 2.0,
      )),
      cardColor: tertiaryBlue,
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.white, // Farbe für ausgewählte Labels
              fontWeight: FontWeight.bold,
              fontSize: 14,
            );
          }
          return const TextStyle(
            color: grey600, // Farbe für nicht ausgewählte Labels
            fontWeight: FontWeight.normal,
            fontSize: 14,
          );
        }),
        backgroundColor: navigationBarDark,
        indicatorColor: secondaryBlue,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
        backgroundColor: secondaryBlue,
      ),
      dividerTheme: DividerThemeData(
        color: grey800,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: backgroundColorDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: grey600,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: tertiaryBlue, // Farbe, wenn nicht fokussiert
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: primaryBlue, // Farbe bei Fokus
            width: 2.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              backgroundColor: primaryBlue,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)))));
}
