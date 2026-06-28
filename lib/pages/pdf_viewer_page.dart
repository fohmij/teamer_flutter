import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:teamer/app_theme/app_theme.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  bool _showSearchBar = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
    });

    if (_showSearchBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _clearSearch();
    }
  }

  void _startSearch(String value) {
    final query = value.trim();

    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();

    if (query.isEmpty) {
      setState(() {
        _searchResult = PdfTextSearchResult();
      });
      return;
    }

    final result = _pdfController.searchText(query);
    result.addListener(_onSearchResultChanged);

    setState(() {
      _searchResult = result;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchResult.removeListener(_onSearchResultChanged);
    _searchResult.clear();
    setState(() {
      _searchResult = PdfTextSearchResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        backgroundColor: isDark
            ? AppTheme.navigationBarDark
            : AppTheme.navigationBarLight,
        actions: [
          IconButton(
            tooltip: 'Suchen',
            onPressed: _toggleSearchBar,
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showSearchBar) _buildSearchBar(isDark),
            Expanded(
              child: Stack(
                children: [
                  SfPdfViewer.asset(
                    widget.assetPath,
                    controller: _pdfController,
                    scrollDirection: PdfScrollDirection.vertical,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    interactionMode: PdfInteractionMode.pan,
                    enableTextSelection: false,
                    canShowScrollHead: false,
                    canShowScrollStatus: false,
                    enableDoubleTapZooming: false,
                    pageSpacing: 0,
                    onDocumentLoaded: (details) {
                      setState(() {
                        _totalPages = details.document.pages.count;
                      });
                    },
                    onPageChanged: (details) {
                      _currentPage = details.newPageNumber;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final hasResult = _searchResult.hasResult;
    final currentIndex = hasResult ? _searchResult.currentInstanceIndex : 0;
    final totalCount = hasResult ? _searchResult.totalInstanceCount : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: isDark ? AppTheme.navigationBarDark : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 16,
                    ),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Wort suchen...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onSubmitted: _startSearch,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '$currentIndex/$totalCount',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.grey600,
                    fontSize: 13,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Vorheriger Treffer',
            onPressed: hasResult ? _searchResult.previousInstance : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Nächster Treffer',
            onPressed: hasResult ? _searchResult.nextInstance : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }


}
