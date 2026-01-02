import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Adaptive image widget that handles both network and file images
class AdaptiveImage extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double? width;
  final double? height;

  const AdaptiveImage.network(
    this.imageUrl, {
    Key? key,
    this.fit,
    this.errorBuilder,
    this.width,
    this.height,
  })  : imageFile = null,
        super(key: key);

  const AdaptiveImage.file(
    this.imageFile, {
    Key? key,
    this.fit,
    this.width,
    this.height,
  })  : imageUrl = null,
        errorBuilder = null,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      // Network image
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[100],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      );
    } else if (imageFile != null) {
      // File image
      return Image.file(
        imageFile!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[100],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        ),
      );
    } else {
      // No image provided
      return Container(
        color: Colors.grey[100],
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
        ),
      );
    }
  }
}

/// Widget untuk menampilkan foto fullscreen dengan aspect ratio yang benar
class FullScreenImageDialog extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;

  const FullScreenImageDialog.network({
    Key? key,
    required this.imageUrl,
  })  : imageFile = null,
        super(key: key);

  const FullScreenImageDialog.file({
    Key? key,
    required this.imageFile,
  })  : imageUrl = null,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Full screen image dengan InteractiveViewer untuk zoom/pan
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageFile != null
                  ? Image.file(
                      imageFile!,
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

