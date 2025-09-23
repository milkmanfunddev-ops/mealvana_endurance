import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../application/barcode_scanner_service.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../widgets/nutrition_verification_dialog.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String category; // 'before_run', 'during_run', 'after_run'
  final String? foodToSwapId;
  final String? foodToSwapName;

  const BarcodeScannerScreen({
    super.key,
    required this.category,
    this.foodToSwapId,
    this.foodToSwapName,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isScanning = true;
  String? _lastScannedBarcode;
  BarcodeScanResult? _lastScanResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.qrCode,
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _controller!.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller!.stop();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final barcodeValue = barcode.rawValue;

    if (barcodeValue == null || barcodeValue == _lastScannedBarcode) return;

    setState(() {
      _isScanning = false;
      _lastScannedBarcode = barcodeValue;
    });

    // Stop scanning temporarily to prevent multiple scans
    _controller?.stop();

    // Perform barcode lookup
    _lookupBarcode(barcodeValue);
  }

  Future<void> _lookupBarcode(String barcode) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Barcode Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode'),
            SizedBox(height: 16.h),
            Text('Looking up product information...'),
            SizedBox(height: 16.h),
            LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );

    try {
      // Perform the actual barcode lookup
      final scannerService = ref.read(barcodeScannerServiceProvider);
      final result = await scannerService.scanBarcode(barcode);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        _lastScanResult = result; // Store the result
        _showLookupResult(result);
      }
    } catch (e) {
      // Close loading dialog and show error
      if (mounted) {
        Navigator.of(context).pop();
        _showError('An unexpected error occurred: $e');
      }
    }
  }

  void _showLookupResult(BarcodeScanResult result) {
    if (result.isSuccess) {
      _showSuccessResult(result.food!, result.barcode);
    } else if (result.isNotFound) {
      _showNotFoundResult(result.barcode, result.message!);
    } else if (result.isInvalidFormat) {
      _showInvalidFormatResult(result.barcode, result.message!);
    } else {
      _showError(result.message ?? 'Unknown error occurred');
    }
  }

  void _showSuccessResult(Food food, String barcode) {
    // Get the API product from the last scan result
    dynamic apiProduct;
    if (_lastScanResult is BarcodeScanResultSuccess) {
      apiProduct = (_lastScanResult as BarcodeScanResultSuccess).apiProduct;
    }

    _showVerificationDialog(food, apiProduct);
  }

  void _showVerificationDialog(Food food, dynamic apiProduct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NutritionVerificationDialog(
        apiProduct: apiProduct,
        mappedFood: food,
        onCancel: () {
          Navigator.of(context).pop();
          _resetScanning();
        },
        onConfirm: (updatedFood) {
          Navigator.of(context).pop();
          context.pop(updatedFood); // Return to swap food screen with the verified food
        },
      ),
    );
  }

  void _showNotFoundResult(String barcode, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode'),
            SizedBox(height: 16.h),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: Text('Try Another'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop(); // Return to swap food screen
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showInvalidFormatResult(String barcode, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invalid Barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode'),
            SizedBox(height: 16.h),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: Text('Try Another'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanning();
            },
            child: Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop(); // Return to swap food screen
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _resetScanning() {
    setState(() {
      _isScanning = true;
      _lastScannedBarcode = null;
      _lastScanResult = null;
    });
    _controller?.start();
  }

  void _toggleFlashlight() {
    _controller?.toggleTorch();
  }

  void _switchCamera() {
    _controller?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final isSwapping = widget.foodToSwapId != null;
    final title = isSwapping
        ? 'Scan to Swap ${widget.foodToSwapName ?? 'Food'}'
        : 'Scan to Add Food';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          onPressed: () => context.pop(),
          // color: Colors.white,
        ),
        title: Text(
          title,
          style: AppTheme.titleStyle.copyWith(
            color: Colors.white,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera view
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _handleBarcodeDetection,
            ),

          // Scanner overlay
          _buildScannerOverlay(),

          // Bottom controls
          Positioned(
            bottom: 60.h,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),

          // Instructions
          Positioned(
            top: 100.h,
            left: 20.w,
            right: 20.w,
            child: _buildInstructions(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      size: Size.infinite,
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        'Position the barcode within the scanning area',
        style: AppTheme.textStyle.copyWith(
          color: Colors.white,
          fontSize: 16.sp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Flashlight button
        _buildControlButton(
          icon: Icons.flashlight_on,
          onPressed: _toggleFlashlight,
          label: 'Flash',
        ),

        // Reset scanning button
        _buildControlButton(
          icon: Icons.refresh,
          onPressed: _resetScanning,
          label: 'Reset',
        ),

        // Switch camera button
        _buildControlButton(
          icon: Icons.cameraswitch,
          onPressed: _switchCamera,
          label: 'Switch',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            color: AppTheme.primary900.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: Colors.white,
              size: 28.sp,
            ),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: AppTheme.textStyle.copyWith(
            color: Colors.white,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppTheme.primary900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Calculate scanner window dimensions
    final scannerWidth = size.width * 0.8;
    final scannerHeight = scannerWidth * 0.6;
    final left = (size.width - scannerWidth) / 2;
    final top = (size.height - scannerHeight) / 2;

    final scannerRect = Rect.fromLTWH(left, top, scannerWidth, scannerHeight);

    // Draw the overlay with cut-out
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scannerRect, Radius.circular(12.r)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw scanner border
    canvas.drawRRect(
      RRect.fromRectAndRadius(scannerRect, Radius.circular(12.r)),
      borderPaint,
    );

    // Draw corner indicators
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = AppTheme.primary900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(left + scannerWidth - cornerLength, top),
      Offset(left + scannerWidth, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scannerWidth, top),
      Offset(left + scannerWidth, top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + scannerHeight - cornerLength),
      Offset(left, top + scannerHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scannerHeight),
      Offset(left + cornerLength, top + scannerHeight),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(left + scannerWidth - cornerLength, top + scannerHeight),
      Offset(left + scannerWidth, top + scannerHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scannerWidth, top + scannerHeight),
      Offset(left + scannerWidth, top + scannerHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}