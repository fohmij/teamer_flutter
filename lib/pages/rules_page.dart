import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class RulesPage extends StatefulWidget {
  RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Schulregelwerk',
        ),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      body: SfPdfViewer.asset('assets/pdfs/schulregelwerk.pdf'),
    );
  }
}
