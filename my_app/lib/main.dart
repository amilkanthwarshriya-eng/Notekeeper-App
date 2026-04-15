// import 'package:flutter/material.dart';
// import 'package:my_app/Screens/note_list.dart';
// import 'package:my_app/Screens/note_detail.dart';
//
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'NoteKeeper',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(primarySwatch: Colors.deepPurple),
//       home: NoteList(),
//     );
//   }
// }
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:my_app/screens/note_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: NoteList(),
      debugShowCheckedModeBanner: false,
    );
  }
}