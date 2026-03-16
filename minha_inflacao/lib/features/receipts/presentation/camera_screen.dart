import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/exceptions.dart';
import '../data/receipt_repository.dart';
import '../providers/receipts_provider.dart';

// Concrete subclass that reads local files on device.
// Overrides the public `readFileBytes` method from ReceiptRepository.
class _MobileReceiptRepository extends ReceiptRepository {
  _MobileReceiptRepository({required super.apiClient});

  @override
  Future<Uint8List> readFileBytes(String path) async {
    return File(path).readAsBytes();
  }
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String _processingStep = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _error = 'Câmera não disponível neste dispositivo.');
      return;
    }
    _controller = CameraController(cameras.first, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  Future<void> _captureAndProcess() async {
    if (!_isCameraReady || _isProcessing) return;
    setState(() { _isProcessing = true; _error = null; });

    try {
      setState(() => _processingStep = 'Capturando imagem…');
      final file = await _controller!.takePicture();

      setState(() => _processingStep = 'Enviando imagem…');
      final repo = _MobileReceiptRepository(apiClient: ref.read(apiClientProvider));

      setState(() => _processingStep = 'Lendo itens com IA…');
      final result = await repo.processReceipt(file.path);

      setState(() => _processingStep = 'Salvando…');
      if (mounted) {
        context.pushReplacement(
          '/receipts/review?receiptId=${result.receiptId}',
          extra: result.parsedData,
        );
      }
    } on RateLimitException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Não foi possível processar a nota. Tente novamente com melhor iluminação.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fotografar Nota')),
      body: Column(
        children: [
          Expanded(
            child: _isCameraReady
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller!),
                      // Receipt guide overlay
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: MediaQuery.of(context).size.height * 0.55,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  )
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_error != null && _isCameraReady)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_isProcessing)
                  Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(_processingStep, style: const TextStyle(color: Colors.white)),
                    ],
                  )
                else
                  Column(
                    children: [
                      const Text(
                        'Enquadre a nota fiscal para iniciar o escaneamento.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _captureAndProcess,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Fotografar'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
