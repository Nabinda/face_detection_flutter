import 'dart:async';
import 'dart:developer';
import 'package:async/async.dart' as async;
import 'package:camera/camera.dart';
import 'package:face_detection/detection_response.dart';
import 'package:face_detection/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class MainApp extends StatefulHookConsumerWidget {
  const MainApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late List<CameraDescription> _cameras;
  late CameraController controller;
  DetectionResponse? _detectionResponse;
  bool isImageScanning = false;
  async.RestartableTimer? _timer;
  bool showWarning = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    initApp();
  }

  dissmissTimer() {
    log('Dissmiss Timer');
    if (showWarning) {
      showWarning = false;
      setState(() {});
    }
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      showWarning = false;
      setState(() {});
    }
  }

  observeTimer() {
    log('Observer Timer');
    _timer?.reset();
    _timer = async.RestartableTimer(const Duration(seconds: 3), () {
      showWarning = true;
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (!controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initApp();
    }
  }

  streamImage() {
    controller.startImageStream((image) => null);
  }

  void _processImage(CameraImage cameraImage) async {
    if (!isImageScanning && mounted) {
      isImageScanning = true;
      try {
        await Helper.scanImage(
                cameraImage: cameraImage,
                cameraDescription: controller.description)
            .then((result) async {
          setState(() {
            if (!(result?.isFocused ?? true)) {
              observeTimer();
            } else {
              dissmissTimer();
            }
            _detectionResponse = result;
          });
        });
        isImageScanning = false;
      } catch (ex, stack) {
        log('Catch Exception: $ex, $stack');
      }
      isImageScanning = false;
    }
  }

  initApp() async {
    if (await Permission.camera.request().isGranted) {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final frontCam = _cameras.firstWhere(
            (element) => element.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras[0]);
        controller = CameraController(frontCam, ResolutionPreset.max);
      }

      controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        controller.startImageStream(_processImage);
        setState(() {});
      }).catchError((Object e) {
        if (e is CameraException) {
          log('Error Initalizing Camera: $e');
          switch (e.code) {
            case 'CameraAccessDenied':
              break;
            default:
              break;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Face Detection'),
      ),
      floatingActionButton:
          FloatingActionButton(backgroundColor: Colors.teal, onPressed: () {}),
      body: (!controller.value.isInitialized)
          ? Container()
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned(
                  bottom: 20,
                  width: MediaQuery.of(context).size.width,
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'FACE: ${_detectionResponse?.face?.leftEyeOpenProbability}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan),
                        ),
                        Text(
                          'Show Warning: $showWarning',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan),
                        ),
                        Text('Foucsed: ${_detectionResponse?.isFocused}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
