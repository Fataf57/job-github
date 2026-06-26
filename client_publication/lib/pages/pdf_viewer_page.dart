import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String titre;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.titre,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _controller = PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _pdfBytes;
  int _currentPage = 1;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncPageIndicator);
    _loadPdf();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncPageIndicator);
    super.dispose();
  }

  void _syncPageIndicator() {
    if (!mounted || !_controller.isReady) return;
    final page = _controller.pageNumber;
    final count = _controller.pageCount;
    if (page == null || count <= 0) return;

    final clampedPage = page.clamp(1, count);
    if (clampedPage != _currentPage || count != _pageCount) {
      setState(() {
        _currentPage = clampedPage;
        _pageCount = count;
      });
    }
  }

  /// Détection fiable de la page courante (y compris la dernière page).
  int? _calculateCurrentPage(
    Rect visibleRect,
    List<Rect> pageLayouts,
    PdfViewerController controller,
  ) {
    if (pageLayouts.isEmpty) return null;

    final last = pageLayouts.last;
    if (visibleRect.bottom >= last.bottom - 12) {
      return pageLayouts.length;
    }

    final first = pageLayouts.first;
    if (visibleRect.top <= first.top + 12) {
      return 1;
    }

    int? bestPage;
    var bestRatio = 0.0;
    for (var i = 0; i < pageLayouts.length; i++) {
      final rect = pageLayouts[i];
      final intersection = rect.intersect(visibleRect);
      if (intersection.isEmpty) continue;
      final ratio = (intersection.width * intersection.height) /
          (rect.width * rect.height);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        bestPage = i + 1;
      }
    }
    return bestPage;
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pdfBytes = null;
      _currentPage = 1;
      _pageCount = 0;
    });

    try {
      final uri = Uri.parse(widget.pdfUrl);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw Exception('Délai dépassé lors du chargement du PDF'),
      );

      if (response.statusCode != 200) {
        throw Exception('Serveur inaccessible (HTTP ${response.statusCode})');
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Le fichier PDF est vide');
      }

      if (bytes.length < 4 ||
          String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Le fichier reçu n\'est pas un PDF valide');
      }

      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _goToPage(int pageNumber) async {
    if (!_controller.isReady) return;
    await _controller.goToPage(pageNumber: pageNumber);
    _syncPageIndicator();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          widget.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Color(0xFF1565C0)),
                    const SizedBox(height: 16),
                    const Text(
                      'Impossible de charger le PDF',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadPdf,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_pdfBytes != null)
            PdfViewer.data(
              _pdfBytes!,
              sourceName: widget.pdfUrl,
              controller: _controller,
              useProgressiveLoading: false,
              params: PdfViewerParams(
                calculateCurrentPageNumber: _calculateCurrentPage,
                onViewerReady: (document, controller) {
                  if (!mounted) return;
                  setState(() {
                    _pageCount = document.pages.length;
                    _currentPage = (controller.pageNumber ?? 1).clamp(1, _pageCount);
                  });
                },
                onPageChanged: (_) => _syncPageIndicator(),
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1565C0)),
                    SizedBox(height: 16),
                    Text('Chargement du PDF...'),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _pdfBytes == null || _errorMessage != null
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.navigate_before),
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    tooltip: 'Page précédente',
                  ),
                  Text(
                    _pageCount > 0
                        ? 'Page $_currentPage / $_pageCount'
                        : 'Page $_currentPage',
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next),
                    onPressed: _pageCount > 0 && _currentPage < _pageCount
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    tooltip: 'Page suivante',
                  ),
                ],
              ),
            ),
    );
  }
}
