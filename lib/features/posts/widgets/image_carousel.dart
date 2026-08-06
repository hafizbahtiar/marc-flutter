import 'package:flutter/material.dart';

/// Papar 1+ gambar post. Satu gambar = full width. Berbilang = swipeable
/// PageView dengan dot indicator (macam Twitter/Instagram).
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({super.key, required this.urls});

  final List<String> urls;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 8 : 6,
                    height: active ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                        alpha: active ? 0.95 : 0.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
