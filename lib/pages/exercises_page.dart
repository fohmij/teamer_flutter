import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  String? localPath;
  late PDFViewController _pdfController;

  int _totalPages = 0;
  int _currentPage = 0;

  double _thumbPosition = 0; // 0 = oben, 1 = unten

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    final bytes = await rootBundle.load('assets/pdfs/Floorball-Trainingsunterlagen.pdf');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Floorball-Trainingsunterlagen.pdf');

    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    setState(() {
      localPath = file.path;
    });
  }

  void _updatePageFromThumb(double dy, double height) {
    if (_totalPages == 0) return;
    // dy relativ zur Gesamthöhe der Scrollbar
    double relative = (dy / height).clamp(0, 1);
    int targetPage = (relative * (_totalPages - 1)).round();
    setState(() {
      _thumbPosition = relative;
      _currentPage = targetPage;
    });
    _pdfController.setPage(targetPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schulregelwerk')),
      body: localPath == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    PDFView(
                      filePath: localPath!,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: false,
                      pageFling: false,
                      onRender: (pages) {
                        setState(() {
                          _totalPages = pages ?? 0;
                        });
                      },
                      onViewCreated: (controller) {
                        _pdfController = controller;
                      },
                      onPageChanged: (page, _) {
                        if (page != null && _totalPages > 0) {
                          setState(() {
                            _currentPage = page;
                            _thumbPosition = page / (_totalPages - 1);
                          });
                        }
                      },
                    ),
                    if (_totalPages > 0)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            _updatePageFromThumb(
                                details.localPosition.dy, constraints.maxHeight);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Container(
                              width: 30,
                              color: Colors.transparent, // Klickfläche
                              child: Stack(
                                children: [
                                  // Hintergrundlinie (Scrollbar)
                                  Positioned(
                                    right: 8, // etwas Abstand vom Rand
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 4,
                                      height: double.infinity,
                                      color: const Color.fromARGB(50, 223, 222, 222),
                                    ),
                                  ),
                                  // Thumb/Pille
                                  Positioned(
                                    top: _thumbPosition *
                                        (constraints.maxHeight - 40),
                                    right: 0,
                                    child: Container(
                                      width: 20,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(255, 27, 121, 197),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${_currentPage + 1}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
