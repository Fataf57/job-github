import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Hauteur de l'aperçu PDF dans les publications.
const double kPdfPreviewHeight = 220;

/// Aperçu PDF + bouton flottant « Lire le fichier ».
class PdfPreviewCard extends StatelessWidget {
  final String pdfUrl;
  final double height;

  const PdfPreviewCard({
    super.key,
    required this.pdfUrl,
    this.height = kPdfPreviewHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.35), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PdfPreview(pdfUrl: pdfUrl),
            const Positioned(
              left: 10,
              bottom: 10,
              child: _FloatingReadButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingReadButton extends StatelessWidget {
  const _FloatingReadButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1565C0),
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Lire le fichier',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu du haut de la 1ère page (en-tête, proportions naturelles).
class PdfPreview extends StatelessWidget {
  final String pdfUrl;

  const PdfPreview({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: IgnorePointer(child: _PdfPreviewLoader(pdfUrl: pdfUrl)),
    );
  }
}

class _PdfPreviewLoader extends StatelessWidget {
  final String pdfUrl;

  const _PdfPreviewLoader({required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder.uri(
      Uri.parse(pdfUrl),
      builder: (context, document) {
        final ref = PdfDocumentViewBuilder.maybeOf(context)?.documentRef;
        final loadError = ref?.resolveListenable().error;

        if (loadError != null) {
          return const _PreviewPlaceholder(
            icon: Icons.broken_image_outlined,
            label: 'Aperçu indisponible',
          );
        }

        if (document == null) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1565C0),
              ),
            ),
          );
        }

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: PdfPageView(
              document: document,
              pageNumber: 1,
              alignment: Alignment.topCenter,
              backgroundColor: Colors.white,
              maximumDpi: 96,
              decoration: const BoxDecoration(color: Colors.white),
              decorationBuilder: (context, size, page, image) {
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: image ??
                      Container(
                        width: size.width,
                        height: size.height,
                        color: Colors.white,
                      ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreviewPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: Color(0xFF1565C0)),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
