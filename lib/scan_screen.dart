import 'dart:async';
import 'dart:ui';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CustomDocumentScanner extends StatefulWidget {
  const CustomDocumentScanner({super.key});

  @override
  State<CustomDocumentScanner> createState() => _CustomDocumentScannerState();
}

class _CustomDocumentScannerState extends State<CustomDocumentScanner> {
  late final TextRecognizer _textRecognizer;
  Timer? _captureTimer;
  bool _isInFrame = false;
  Color _frameColor = Colors.red;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _hasTextInFrame = false;

  @override
  void initState() {
    super.initState();
    _initDetectors();
  }

  void _initDetectors() {
    // Text recognizer
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  void _startAutoCapture() {
    setState(() {
      _frameColor = Colors.green;
    });

    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 3), () {
      _captureImage();
    });
  }

  void _cancelAutoCapture() {
    setState(() {
      _frameColor = Colors.red;
    });
    _captureTimer?.cancel();
  }

  /// Matn ramka ichida yoki yo'qligini tekshiradi
  bool _isTextInCustomFrame(List<TextBlock> textBlocks) {
    const frameWidth = 300;
    const frameHeight = 200;
    final screenSize = MediaQuery.of(context).size;

    final frameRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: frameWidth.toDouble(),
      height: frameHeight.toDouble(),
    );

    // Har bir text block ramka ichida yoki yo'qligini tekshirish
    for (final block in textBlocks) {
      if (frameRect.overlaps(block.boundingBox)) {
        return true;
      }
    }
    return false;
  }

  /// Rasmni avtomatik suratga olish va OCR qilish
  void _captureImage() async {
    if (!mounted || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    // Dialog chiqarish
    _showDocumentDetectedDialog();
  }

  /// Matnni tanib olish funksiyasi
  Future<String> _performOCR(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        return 'Matn topilmadi. Hujjatni yaxshiroq yoritib, qayta urinib ko\'ring.';
      }
      
      return recognizedText.text;
    } catch (e) {
      print('❌ OCR xatolik: $e');
      return 'Matnni o\'qishda xatolik yuz berdi. Qayta urinib ko\'ring.';
    }
  }

  /// Hujjat aniqlanganida dialog ko'rsatish
  void _showDocumentDetectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.document_scanner, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Hujjat aniqlandi!'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Container ichida hujjat muvaffaqiyatli aniqlandi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'O\'qilgan matn:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.maxFinite,
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _extractedText.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Matn o\'qilmoqda...'),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _extractedText,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Frame rangini qayta qizil qilish
                setState(() {
                  _frameColor = Colors.red;
                  _isInFrame = false;
                  _extractedText = '';
                  _isProcessing = false;
                });
              },
              child: const Text('Davom etish'),
            ),
            if (_extractedText.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Matnni clipboard ga ko'chirish
                  // Clipboard.setData(ClipboardData(text: _extractedText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Matn nusxalandi!')),
                  );
                },
                child: const Text('Nusxalash'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Bosh sahifaga qaytish yoki boshqa amal
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tugatish'),
            ),
          ],
        );
      },
    );
  }

  /// MLKit orqali har bir frame'ni tahlil qilish
  Future<void> _onImageForAnalysis(AnalysisImage img) async {
    if (_isProcessing) return;
    
    try {
      final inputImage = InputImage.fromBytes(
        bytes: img.wrapped().bytes!,
        metadata: InputImageMetadata(
          format: InputImageFormat.nv21,
          bytesPerRow: img.wrapped().planes!.first?.bytesPerRow ?? img.width,
          rotation: InputImageRotation.rotation0deg,
          size: img.size,
        ),
      );

      // Text recognition orqali matn qidirish
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.blocks.isNotEmpty) {
        final hasTextInFrame = _isTextInCustomFrame(recognizedText.blocks);

        if (hasTextInFrame && !_isInFrame) {
          _isInFrame = true;
          _hasTextInFrame = true;
          _startAutoCapture();
          
          // OCR natijasini saqlash
          if (_extractedText.isEmpty) {
            setState(() {
              _extractedText = recognizedText.text;
            });
          }
        } else if (!hasTextInFrame && _isInFrame) {
          _isInFrame = false;
          _hasTextInFrame = false;
          _cancelAutoCapture();
        }
      } else {
        _isInFrame = false;
        _hasTextInFrame = false;
        _cancelAutoCapture();
      }
    } catch (e) {
      print('❌ Tahlil qilishda xatolik: $e');
    }
  }

  /// OCR ni background da ishga tushirish
  void _performOCRInBackground(InputImage inputImage) async {
    if (_extractedText.isNotEmpty) return; // Allaqachon OCR qilingan
    
    final text = await _performOCR(inputImage);
    
    if (mounted) {
      setState(() {
        _extractedText = text;
      });
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: CameraAwesomeBuilder.awesome(
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.auto,
        ),
        saveConfig: SaveConfig.photo(),
        previewDecoratorBuilder: (state, preview) {
          return Stack(children: [
            _buildOverlayFrame(),
            _buildInstructions(),
          ]);
        },
        onImageForAnalysis: _onImageForAnalysis,
      ),
    );
  }

  Widget _buildOverlayFrame() {
    return Center(
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: _frameColor, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _isInFrame
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Hujjat aniqlandi!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Icon(Icons.text_fields, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              _isInFrame
                  ? 'Hujjat aniqlandi! 3 soniyada avtomatik suratga olinadi...'
                  : 'Hujjatni ramka ichiga joylashtiring',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Matn avtomatik tanib olinadi',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yordam'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Matn bilan hujjatni ramka ichiga joylashtiring'),
            Text('2. Kamera avtomatik matnni aniqlaydi'),
            Text('3. 3 soniyada avtomatik suratga olinadi'),
            Text('4. Matn avtomatik tanib olinadi'),
            Text('5. Natijani ko\'rib chiqing va nusxalang'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tushundim'),
          ),
        ],
      ),
    );
  }
}