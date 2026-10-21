import 'dart:io';
import 'package:flutter/material.dart';

/// Caja reutilizable de captura y previsualización de fotografías de documentos estilo Apple Card
class DocumentPhotoBox extends StatelessWidget {
  final String title;
  final String tag;
  final File? image;
  final String? networkUrl;
  final bool isScanning;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isRequired;
  final double height;

  const DocumentPhotoBox({
    super.key,
    required this.title,
    required this.tag,
    required this.image,
    this.networkUrl,
    this.isScanning = false,
    required this.onTap,
    required this.onRemove,
    this.isRequired = false,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = image != null;
    final hasNetworkImage = networkUrl != null && networkUrl!.isNotEmpty;
    final hasImage = hasLocalImage || hasNetworkImage;
    final isOcrFront = tag == 'IA OCR';

    return GestureDetector(
      onTap: isScanning ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF0284C7)
                : (isOcrFront
                    ? const Color(0xFFBAE6FD)
                    : const Color(0xFFE2E8F0)),
            width: hasImage ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasLocalImage) ...[
                Image.file(
                  image!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ] else if (hasNetworkImage) ...[
                Image.network(
                  networkUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                ),
              ],
              if (hasImage) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withOpacity(0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onRemove,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOcrFront
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOcrFront
                            ? Icons.document_scanner_rounded
                            : Icons.add_a_photo_outlined,
                        size: 20,
                        color: isOcrFront
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRequired ? '$tag (Obligatorio)' : tag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isRequired
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
              if (isScanning) ...[
                Container(
                  color: Colors.black.withOpacity(0.65),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
