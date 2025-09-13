import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class FacialRegistrationLogic {
  late CameraController cameraController;
  bool isCameraInitialized = false;
  bool isCapturing = false;
  bool isUploading = false;
  int capturedCount = 0;
  List<File> capturedImages = [];
  int currentAngleIndex = 0;
  double progress = 0.0;
  Timer? angleTimer;
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
    );
    await cameraController.initialize();
    isCameraInitialized = true;
  }

  void startAngleLoop(VoidCallback onUpdate) {
    if (isCapturing) return;
    isCapturing = true;
    currentAngleIndex = 0;
    anglePhotoIndex = 0;
    progress = 0.0;

    angleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      progress += 0.05;
      onUpdate();

      if (progress >= 1.0) {
        progress = 0.0;
        await captureAngleImage(currentAngleIndex, anglePhotoIndex);
        anglePhotoIndex++;

        if (anglePhotoIndex >= photosPerAngle) {
          anglePhotoIndex = 0;
          currentAngleIndex++;
        }

        if (currentAngleIndex >= angleInstructions.length) {
          angleTimer?.cancel();
          isCapturing = false;
          readyToUpload = true;
          showResetButton = true;
          onUpdate();
        }
      }
    });
  }

  Future<void> captureAngleImage(int angleIndex, int photoIndex) async {
    if (!cameraController.value.isInitialized) return;
    final tempDir = await getTemporaryDirectory();
    final XFile file = await cameraController.takePicture();
    final File imgFile = File('${tempDir.path}/angle_${angleIndex}_$photoIndex.jpg');
    await file.saveTo(imgFile.path);
    capturedImages.add(imgFile);
    capturedCount = capturedImages.length;
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

  Future<http.StreamedResponse> uploadImages(
      String uid,
      String name,
      String role,
      VoidCallback onProgress,
      ) async {
    isUploading = true;
    final tempDir = await getTemporaryDirectory();
    final uri = Uri.parse('http://192.168.165.246:8000/register-face');
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
    }

    final streamed = await request.send();
    int sent = 0;
    streamed.stream.listen((_) {
      sent++;
      progress = (sent / capturedImages.length).clamp(0.0, 1.0);
      onProgress();
    });
    return streamed;
  }

  void dispose() {
    angleTimer?.cancel();
    if (isCameraInitialized) cameraController.dispose();
  }
}
