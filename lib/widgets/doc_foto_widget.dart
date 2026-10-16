import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Widget para visualización segura de fotos de documentos oficiales y licencias (a=docFoto)
/// Cumple con las páginas 10 y 37 (Ronda 134) de la integración Mark V3.1.
class DocFotoWidget extends StatefulWidget {
  final int idFoto;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const DocFotoWidget({
    super.key,
    required this.idFoto,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<DocFotoWidget> createState() => _DocFotoWidgetState();
}

class _DocFotoWidgetState extends State<DocFotoWidget> {
  static final Map<int, Uint8List> _imageCache = {};

  bool _isLoading = true;
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant DocFotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idFoto != widget.idFoto) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (_imageCache.containsKey(widget.idFoto)) {
      setState(() {
        _bytes = _imageCache[widget.idFoto];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await MarkApiClient.instance.getDocFoto(widget.idFoto);
      _imageCache[widget.idFoto] = data;
      if (mounted) {
        setState(() {
          _bytes = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showFullScreen(BuildContext context) {
    if (_bytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.memory(
                _bytes!,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: radius,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
          ),
        ),
      );
    }

    if (_error != null || _bytes == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, size: 28, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          _bytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
      ),
    );
  }
}
