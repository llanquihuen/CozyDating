import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_config.dart';

/// Modal / Screen that displays photos in 100% fullscreen with pinch-to-zoom,
/// ideal for vertical (9:16) smartphone photos without any cropping.
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String? title;

  const FullScreenPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title,
  });

  /// Convenient helper to open the viewer modally with a smooth fade transition.
  static Future<void> open(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
    String? title,
  }) {
    if (photos.isEmpty) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (ctx, anim, secondaryAnim) => FadeTransition(
          opacity: anim,
          child: FullScreenPhotoViewer(
            photos: photos,
            initialIndex: initialIndex,
            title: title,
          ),
        ),
      ),
    );
  }

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.isNotEmpty ? widget.photos.length - 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo PageView
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.photos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: InteractiveViewer(
                  transformationController: _currentIndex == index ? _transformController : null,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: _buildPhoto(photo),
                ),
              );
            },
          ),

          // Side tap zones for rapid previous / next browsing
          if (widget.photos.length > 1) ...[
            Positioned(
              left: 0,
              top: 100,
              bottom: 100,
              width: MediaQuery.of(context).size.width * 0.22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_currentIndex > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
            Positioned(
              right: 0,
              top: 100,
              bottom: 100,
              width: MediaQuery.of(context).size.width * 0.22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_currentIndex < widget.photos.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],

          // Top Overlay: Story bars & Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Story dashes
                    if (widget.photos.length > 1)
                      Row(
                        children: List.generate(widget.photos.length, (i) {
                          final isCurrent = i == _currentIndex;
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isCurrent ? Colors.white : Colors.white38,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back / Close Icon Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        // Title or Counter
                        if (widget.title != null && widget.title!.isNotEmpty)
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          )
                        else if (widget.photos.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.photos.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // Reset zoom button
                        IconButton(
                          icon: const Icon(Icons.zoom_out_map_rounded, color: Colors.white70, size: 22),
                          tooltip: 'Restablecer zoom',
                          onPressed: () {
                            _transformController.value = Matrix4.identity();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Hint Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pinch_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text(
                      'Pellizca para hacer zoom • Desliza para navegar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto(String url) {
    final resolvedUrl = AppConfig.resolveMediaUrl(url);

    if (resolvedUrl.startsWith('assets/')) {
      return Image.asset(
        resolvedUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    } else if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFD54F),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    } else {
      return _errorPlaceholder();
    }
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
            SizedBox(height: 8),
            Text(
              'No se pudo cargar la imagen',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
