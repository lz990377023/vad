// lib/main.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';
import 'package:vad_example/recording.dart';
import 'package:vad_example/vad_settings_dialog.dart';
import 'package:vad_example/ui/vad_ui.dart';
import 'package:vad_example/ui/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAD Example',
      theme: AppTheme.getDarkTheme(),
      home: const VadManager(),
    );
  }
}

class VadManager extends StatefulWidget {
  const VadManager({super.key});

  @override
  State<VadManager> createState() => _VadManagerState();
}

class _VadManagerState extends State<VadManager> {
  List<Recording> recordings = [];
  late VadHandlerBase _vadHandler;
  bool isListening = false;
  late VadSettings settings;
  final VadUIController _uiController = VadUIController();

  @override
  void initState() {
    super.initState();
    settings = VadSettings();
    _initializeVad();
  }

  void _initializeVad() {
    _vadHandler = VadHandler.create(isDebug: true);
    _setupVadHandler();
  }

  void _startListening() {
    _vadHandler.startListening(
      frameSamples: settings.frameSamples,
      minSpeechFrames: settings.minSpeechFrames,
      preSpeechPadFrames: settings.preSpeechPadFrames,
      redemptionFrames: settings.redemptionFrames,
      positiveSpeechThreshold: settings.positiveSpeechThreshold,
      negativeSpeechThreshold: settings.negativeSpeechThreshold,
      submitUserSpeechOnPause: settings.submitUserSpeechOnPause,
      model: settings.modelString,
      baseAssetPath: 'assets/packages/vad/assets/',
      onnxWASMBasePath: 'assets/packages/vad/assets/',
    );
    setState(() {
      isListening = true;
    });
  }

  void _stopListening() {
    _vadHandler.stopListening();
    setState(() {
      isListening = false;
    });
  }

  void _setupVadHandler() {
    _vadHandler.onSpeechStart.listen((_) {
      setState(() {
        recordings.add(Recording(
          samples: [],
          type: RecordingType.speechStart,
        ));
      });
      _uiController.scrollToBottom?.call();
      debugPrint('Speech detected.');
    });

    _vadHandler.onRealSpeechStart.listen((_) {
      setState(() {
        recordings.add(Recording(
          samples: [],
          type: RecordingType.realSpeechStart,
        ));
      });
      _uiController.scrollToBottom?.call();
      debugPrint('Real speech start detected.');
    });

    _vadHandler.onSpeechEnd.listen((List<double> samples) {
      setState(() {
        recordings.add(Recording(
          samples: samples,
          type: RecordingType.speechEnd,
        ));
      });
      _uiController.scrollToBottom?.call();
      debugPrint('Speech ended, recording added.');
    });

    _vadHandler.onFrameProcessed.listen((frameData) {
      final isSpeech = frameData.isSpeech;
      final notSpeech = frameData.notSpeech;
      final firstFiveSamples = frameData.frame.length >= 5
          ? frameData.frame.sublist(0, 5)
          : frameData.frame;

      debugPrint(
          'Frame processed - isSpeech: $isSpeech, notSpeech: $notSpeech');
      debugPrint('First few audio samples: $firstFiveSamples');
    });

    _vadHandler.onVADMisfire.listen((_) {
      setState(() {
        recordings.add(Recording(type: RecordingType.misfire));
      });
      _uiController.scrollToBottom?.call();
      debugPrint('VAD misfire detected.');
    });

    _vadHandler.onError.listen((String message) {
      setState(() {
        recordings.add(Recording(type: RecordingType.error));
      });
      _uiController.scrollToBottom?.call();
      debugPrint('Error: $message');
    });
  }

  void _applySettings(VadSettings newSettings) {
    bool wasListening = isListening;

    // If we're currently listening, stop first
    if (isListening) {
      _vadHandler.stopListening();
      isListening = false;
    }

    // Update settings
    setState(() {
      settings = newSettings;
    });

    // Dispose and recreate VAD handler
    _vadHandler.dispose();
    _initializeVad();

    // Restart listening if it was previously active
    if (wasListening) {
      _startListening();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return VadSettingsDialog(
          settings: settings,
          onSettingsChanged: _applySettings,
        );
      },
    );
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    debugPrint("Microphone permission status: $status");
  }

  @override
  Widget build(BuildContext context) {
    return VadUI(
      recordings: recordings,
      isListening: isListening,
      settings: settings,
      onStartListening: _startListening,
      onStopListening: _stopListening,
      onRequestMicrophonePermission: _requestMicrophonePermission,
      onShowSettingsDialog: _showSettingsDialog,
      controller: _uiController,
    );
  }

  @override
  void dispose() {
    if (isListening) {
      _vadHandler.stopListening();
    }
    _vadHandler.dispose();
    _uiController.dispose();
    super.dispose();
  }
}
