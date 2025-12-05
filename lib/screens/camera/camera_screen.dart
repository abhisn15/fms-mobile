import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  final String title;

  const CameraScreen({
    super.key,
    required this.title,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
        );
        await _controller!.initialize();
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengakses kamera: $e')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      debugPrint('[CameraScreen] Capturing photo...');
      final image = await _controller!.takePicture();
      final file = File(image.path);
      debugPrint('[CameraScreen] ✓ Photo captured: ${file.path}');
      
      // Dispose camera before navigating back to prevent dead thread warnings
      await _disposeCamera();
      
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (e) {
      debugPrint('[CameraScreen] ✗ Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      debugPrint('[CameraScreen] Picking image from gallery...');
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        debugPrint('[CameraScreen] ✓ Image selected: ${image.path}');
        // Dispose camera before navigating back
        await _disposeCamera();
        Navigator.of(context).pop(File(image.path));
      }
    } catch (e) {
      debugPrint('[CameraScreen] ✗ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    debugPrint('[CameraScreen] Disposing camera...');
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isInitialized) {
          debugPrint('[CameraScreen] Disposing initialized camera controller...');
          await _controller!.dispose();
          debugPrint('[CameraScreen] ✓ Camera disposed successfully');
        } else {
          debugPrint('[CameraScreen] Disposing uninitialized camera controller...');
          _controller!.dispose();
        }
      } catch (e) {
        debugPrint('[CameraScreen] ⚠ Camera disposal error (ignored): $e');
        // Ignore disposal errors - camera may already be disposed
      } finally {
        _controller = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isInitialized && _controller != null
          ? Stack(
              children: [
                CameraPreview(_controller!),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.photo_library, color: Colors.white),
                          onPressed: _pickFromGallery,
                        ),
                        GestureDetector(
                          onTap: _isCapturing ? null : _capturePhoto,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.grey, width: 4),
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.camera_alt, size: 40),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}

