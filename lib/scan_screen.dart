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


//2-usul

/**
 * import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class ProfessionalDocumentScanner extends StatefulWidget {
  const ProfessionalDocumentScanner({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfessionalDocumentScannerState createState() =>
      _ProfessionalDocumentScannerState();
}

class _ProfessionalDocumentScannerState
    extends State<ProfessionalDocumentScanner> {
  List<String> _scannedDocumentPaths = [];
  String _extractedText = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Scan"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scan qilingan hujjatni ko'rsatish
          Expanded(
            flex: 7,
            child: Container(
              margin: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _scannedDocumentPaths.isNotEmpty
                    ? PageView.builder(
                        itemCount: _scannedDocumentPaths.length,
                        itemBuilder: (context, index) {
                          return Image.file(
                            File(_scannedDocumentPaths[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[800],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Scanning frame
                            Container(
                              width: 250,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.green,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                children: [
                                  // Corner indicators
                                  Positioned(
                                    top: -5,
                                    left: -5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -5,
                                    right: -5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -5,
                                    left: -5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -5,
                                    right: -5,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.only(
                                          bottomRight: Radius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Center icon
                                  Center(
                                    child: Icon(
                                      Icons.credit_card,
                                      color: Colors.grey[400],
                                      size: 50,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'ID Card yoki Hujjat',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Instructions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Place your front side of your card on the box',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 30),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Scan button
              GestureDetector(
                onTap: _scanDocument,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),

              // OCR button
              GestureDetector(
                onTap: _extractText,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.text_fields, color: Colors.white, size: 20),
                ),
              ),

              // Clear button
              if (_scannedDocumentPaths.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _scannedDocumentPaths.clear();
                      _extractedText = '';
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.clear, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),

          SizedBox(height: 30),

          // OCR Results
          if (_extractedText.isNotEmpty)
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Aniqlangan matn:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _extractedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Matn nusxalandi!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: Icon(Icons.copy, color: Colors.white),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _extractedText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Professional document scanner
  Future<void> _scanDocument() async {
    try {
      List<String> pictures = await CunningDocumentScanner.getPictures() ?? [];

      if (pictures.isNotEmpty) {
        setState(() {
          _scannedDocumentPaths = pictures;
        });

        // Automatic OCR after scanning
        await _extractText();
      }
    } catch (e) {
      print('Scanning error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skanerlashda xatolik: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Extract text using OCR
  Future<void> _extractText() async {
    if (_scannedDocumentPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Avval hujjatni skanerlang!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _extractedText = '';
    });

    try {
      final textRecognizer = TextRecognizer();
      String allText = '';

      // Process all scanned images
      for (String imagePath in _scannedDocumentPaths) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final recognizedText = await textRecognizer.processImage(inputImage);

        if (recognizedText.text.isNotEmpty) {
          allText += recognizedText.text + '\n\n';
        }
      }

      setState(() {
        _extractedText = allText.trim();
        _isLoading = false;
      });

      await textRecognizer.close();

      if (_extractedText.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Matn muvaffaqiyatli aniqlandi!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hech qanday matn aniqlanmadi'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR xatoligi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
 */