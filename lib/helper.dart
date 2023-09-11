import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:face_detection/detection_response.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class Helper {
  static Future<DetectionResponse?> scanImage(
      {required CameraImage cameraImage,
      required CameraDescription cameraDescription}) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());
    InputImageRotation imageRotation = InputImageRotation.rotation0deg;

    final InputImageFormat imageFormat =
        InputImageFormatValue.fromRawValue(cameraImage.format.raw) ??
            InputImageFormat.nv21;

    final imageMetaData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: imageFormat,
        bytesPerRow: 0);
    final inputImage =
        InputImage.fromBytes(bytes: bytes, metadata: imageMetaData);
    final face = await detectFace(inputImage: inputImage);
    return face;
  }

  static Future<DetectionResponse?> detectFace(
      {required InputImage inputImage}) async {
    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);
    try {
      final List<Face> faces = await faceDetector.processImage(inputImage);
      final faceDetect = extractFace(faces);
      return faceDetect;
    } catch (error) {
      debugPrint(error.toString());
      return null;
    }
  }

  static DetectionResponse extractFace(List<Face> faces) {
    bool wellPositioned = faces.isNotEmpty;
    Face? detectedFace;

    for (Face face in faces) {
      detectedFace = face;

      // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
      // eyes, cheeks, and nose available):

      final FaceLandmark? leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final FaceLandmark? rightEye = face.landmarks[FaceLandmarkType.rightEye];

      if (leftEye != null && rightEye != null) {
        if (leftEye.position.y < 0 ||
            leftEye.position.x < 0 ||
            rightEye.position.y < 0 ||
            rightEye.position.x < 0) {
          wellPositioned = false;
        }
      }

      if (face.leftEyeOpenProbability != null) {
        if (face.leftEyeOpenProbability! < 0.5) {
          wellPositioned = false;
        }
      }

      if (face.rightEyeOpenProbability != null) {
        if (face.rightEyeOpenProbability! < 0.5) {
          wellPositioned = false;
        }
      }
    }

    return DetectionResponse(isFocused: wellPositioned, face: detectedFace);
  }
}
