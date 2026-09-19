import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

class LetterPhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final VoidCallback? onTap;
  final void Function(int index)? onExpand;
  final double height;

  const LetterPhotoCarousel({
    super.key,
    required this.photos,
    this.onTap,
    this.onExpand,
    this.height = 340,
  });

  @override
  State<LetterPhotoCarousel> createState() => _LetterPhotoCarouselState();
}

class _LetterPhotoCarouselState extends State<LetterPhotoCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF28253B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.account_circle, size: 90, color: Color(0xFFFFD54F)),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _buildPhoto(photo);
              },
            ),

            // Left / Right touch zones for quick tapping between photos
            if (widget.photos.length > 1)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentIndex > 0) {
                            _controller.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.onTap?.call();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onTap,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentIndex < widget.photos.length - 1) {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.onTap?.call();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onTap,
                ),
              ),

            // Story-style dash indicators on top
            if (widget.photos.length > 1)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(
                    widget.photos.length,
                    (i) => Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _currentIndex == i
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Photo counter badge top-right
            if (widget.photos.length > 1)
              Positioned(
                top: 20,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentIndex + 1}/${widget.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom gradient hint overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.photos.length > 1)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 13, color: Colors.white.withOpacity(0.85)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Toca laterales o desliza',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.onExpand != null) {
                          widget.onExpand!(_currentIndex);
                        } else {
                          widget.onTap?.call();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded, size: 15, color: Colors.white.withOpacity(0.95)),
                            const SizedBox(width: 3),
                            Text(
                              'Ampliar',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(String photo) {
    final resolved = AppConfig.resolveMediaUrl(photo);
    if (resolved.startsWith('assets/')) {
      return Image.asset(resolved, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFF28253B),
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                color: const Color(0xFFFFD54F),
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF28253B),
          child: const Center(child: Icon(Icons.person, size: 60, color: Colors.white30)),
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF28253B),
        child: const Center(child: Icon(Icons.person, size: 60, color: Colors.white30)),
      );
    }
  }
}
