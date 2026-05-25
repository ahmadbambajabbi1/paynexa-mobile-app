import 'package:flutter/material.dart';

/// Opens a near-fullscreen gallery: images fit the screen ([BoxFit.contain]), pinch-to-zoom per page, swipe between photos.
void showProductImageLightbox(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
}) {
  if (urls.isEmpty) return;
  final i = initialIndex.clamp(0, urls.length - 1);
  Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: _ProductImageLightboxScaffold(urls: urls, initialIndex: i),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
    ),
  );
}

class _ProductImageLightboxScaffold extends StatefulWidget {
  const _ProductImageLightboxScaffold({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ProductImageLightboxScaffold> createState() => _ProductImageLightboxScaffoldState();
}

class _ProductImageLightboxScaffoldState extends State<_ProductImageLightboxScaffold> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: widget.urls.length,
              itemBuilder: (context, index) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(64),
                      child: Center(
                        child: Image.network(
                          widget.urls[index],
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.broken_image_outlined,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              top: 4,
              left: 12,
              right: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.urls.length > 1
                          ? 'Image ${_current + 1} of ${widget.urls.length}'
                          : 'View image',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.urls.length > 1) ...[
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _current > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 36),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _current < widget.urls.length - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 36),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 8 + bottomInset,
              child: Center(
                child: Text(
                  widget.urls.length > 1
                      ? 'Pinch to zoom · swipe between images'
                      : 'Pinch to zoom',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
