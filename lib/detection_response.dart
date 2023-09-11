import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionResponse {
  final Face? face;
  final bool isFocused;
  DetectionResponse({this.face, required this.isFocused});
}
