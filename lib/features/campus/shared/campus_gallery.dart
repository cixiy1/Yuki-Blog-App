import 'package:flutter/material.dart';

import '../../../core/campus/media_repository.dart';
import 'campus_image.dart';

/// 详情页顶部的图片轮播：左右滑动切图，多张时出指示点，点开全屏看大图。
///
/// 图片只是附加信息，任何一张取不到都只是显示破图占位，不阻塞页面。
class CampusGallery extends StatefulWidget {
  const CampusGallery({
    super.key,
    required this.imageIds,
    required this.media,
    this.height = 230,
  });

  final List<String> imageIds;
  final MediaRepository media;
  final double height;

  @override
  State<CampusGallery> createState() => _CampusGalleryState();
}

class _CampusGalleryState extends State<CampusGallery> {
  int _page = 0;

  void _openViewer(int index) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: index),
              itemCount: widget.imageIds.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: CampusImage(
                    imageId: widget.imageIds[i],
                    media: widget.media,
                    fit: BoxFit.contain,
                    borderRadius: 0,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.imageIds;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: ids.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openViewer(i),
              child: CampusImage(
                imageId: ids[i],
                media: widget.media,
                fit: BoxFit.cover,
                borderRadius: 0,
              ),
            ),
          ),
          if (ids.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < ids.length; i++)
                    Container(
                      width: i == _page ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: i == _page ? 0.95 : 0.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
