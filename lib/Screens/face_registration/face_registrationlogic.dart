import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

// === Cloud Run base URL ===
const String baseUrl = 'https://face-api-3uuxgggz7a-as.a.run.app';

class FacialRegistrationLogic {
  late CameraController cameraController;
  bool isCameraInitialized = false;
  bool isCapturing = false;
  bool isUploading = false;
  int capturedCount = 0;
  List<File> capturedImages = [];
  int currentAngleIndex = 0;
  double progress = 0.0;
  Timer? angleTimer; // kept for compatibility
  bool readyToUpload = false;
  bool showResetButton = false;
  int photosPerAngle = 2;
  int anglePhotoIndex = 0;

  final List<String> angleInstructions = [
    'Look in front',
    'Turn Left',
    'Turn Right',
    'Look Up',
    'Look Down',
  ];

  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    final frontCameras = cameras.where((c) => c.lensDirection == CameraLensDirection.front);
    final cameraDesc = frontCameras.isNotEmpty ? frontCameras.first : cameras.first;

    cameraController = CameraController(
      cameraDesc,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await cameraController.initialize();
    isCameraInitialized = true;
  }

  Future<void> startAngleLoop(VoidCallback onUpdate) async {
    if (isCapturing || !isCameraInitialized) return;
    isCapturing = true;
    readyToUpload = false;
    showResetButton = false;
    capturedImages.clear();
    capturedCount = 0;
    currentAngleIndex = 0;
    anglePhotoIndex = 0;
    progress = 0.0;
    onUpdate();

    try {
      for (currentAngleIndex = 0; currentAngleIndex < angleInstructions.length; currentAngleIndex++) {
        for (anglePhotoIndex = 0; anglePhotoIndex < photosPerAngle; anglePhotoIndex++) {
          // simple progress animation (~2s per shot)
          progress = 0.0; onUpdate();
          for (int t = 0; t < 20; t++) {
            await Future.delayed(const Duration(milliseconds: 100));
            progress = (t + 1) / 20.0;
            onUpdate();
          }

          final f = await _safeCapture(angleIndex: currentAngleIndex, photoIndex: anglePhotoIndex);
          if (f != null) {
            capturedImages.add(f);
            capturedCount = capturedImages.length;
            onUpdate();
          }
          await Future.delayed(const Duration(milliseconds: 120));
        }
      }

      currentAngleIndex = angleInstructions.length - 1; // clamp for UI safety
      readyToUpload = true;
      showResetButton = true;
      onUpdate();
    } finally {
      isCapturing = false;
    }
  }

  Future<File?> _safeCapture({required int angleIndex, required int photoIndex}) async {
    if (!isCameraInitialized) return null;

    if (cameraController.value.isTakingPicture) {
      for (int i = 0; i < 10 && cameraController.value.isTakingPicture; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (cameraController.value.isTakingPicture) return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final XFile file = await cameraController.takePicture();
      final File imgFile = File('${tempDir.path}/angle_${angleIndex}_$photoIndex.jpg');
      await file.saveTo(imgFile.path);
      return imgFile;
    } on CameraException catch (_) {
      await _recoverCamera();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recoverCamera() async {
    try { await cameraController.dispose(); } catch (_) {}
    isCameraInitialized = false;
    final cams = await availableCameras();
    await initializeCamera(cams);
  }

  // IMPORTANT: Do NOT listen to response stream here.
  // The caller will read the stream exactly once using Response.fromStream(...).
  Future<http.StreamedResponse> uploadImages(
      String uid,
      String name,
      String role,
      VoidCallback onProgress,
      ) async {
    isUploading = true;
    final tempDir = await getTemporaryDirectory();
    final uri = Uri.parse('$baseUrl/register-face');
    final request = http.MultipartRequest('POST', uri)
      ..fields['uid'] = uid
      ..fields['name'] = name
      ..fields['role'] = role;

    for (int i = 0; i < capturedImages.length; i++) {
      final bytes = await capturedImages[i].readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) continue;

      final resized = img.copyResize(originalImage, width: 480);
      final compressed = File('${tempDir.path}/compressed_$i.jpg')
        ..writeAsBytesSync(img.encodeJpg(resized, quality: 70));

      request.files.add(await http.MultipartFile.fromPath('image', compressed.path));
      // Optional: faux progress per file attached (client-visible)
      progress = ((i + 1) / capturedImages.length).clamp(0.0, 1.0);
      onProgress();
    }

    final streamed = await request.send();
    // Leave the stream unread here. Caller will consume it once.
    return streamed;
  }

  Future<void> resetCapture(VoidCallback onUpdate) async {
    for (final file in capturedImages) {
      if (await file.exists()) await file.delete();
    }
    capturedImages.clear();
    capturedCount = 0;
    currentAngleIndex = 0;
    progress = 0.0;
    readyToUpload = false;
    showResetButton = false;
    isCapturing = false;
    anglePhotoIndex = 0;
    onUpdate();
  }

  void dispose() {
    angleTimer?.cancel();
    if (isCameraInitialized) {
      try { cameraController.dispose(); } catch (_) {}
    }
  }
}
