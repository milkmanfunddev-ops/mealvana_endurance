import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../application/barcode_scanner_service.dart';
import '../../../nutrition_plan/domain/food.dart';

/// Barcode Scanner Screen - Kyle's Design System
/// Unified scanner for all contexts (swap, add, preferences, carb loading)
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String category; // 'before_run', 'during_run', 'after_run', 'add_food', 'preferences', 'carb_loading'
  final String? foodToSwapId;
  final String? foodToSwapName;
  final String? context; // Additional context parameter

  const BarcodeScannerScreen({
    super.key,
    required this.category,
    this.foodToSwapId,
    this.foodToSwapName,
    this.context,
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
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();

    // Track scanner opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track('barcode_scanner_opened', properties: {
        'category': widget.category,
        'context': widget.context,
      });
    });
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

    // Track scan
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('barcode_scanned', properties: {
      'code': barcodeValue,
      'category': widget.category,
    });

    // Perform barcode lookup
    _lookupBarcode(barcodeValue);
  }

  Future<void> _lookupBarcode(String barcode) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Barcode Detected',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Barcode: $barcode',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Looking up product information...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

  Future<void> _showVerificationDialog(Food food, dynamic apiProduct) async {
    // Determine the context and pre-selected categories based on widget.category
    FoodDetailContext foodContext;
    List<int>? preSelectedCategories;

    switch (widget.category) {
      case 'before_run':
        foodContext = FoodDetailContext.addFood;
        preSelectedCategories = [1]; // Only before run
        break;
      case 'during_run':
        foodContext = FoodDetailContext.addFood;
        preSelectedCategories = [2]; // Only during run
        break;
      case 'after_run':
        foodContext = FoodDetailContext.addFood;
        preSelectedCategories = [3]; // Only after run
        break;
      case 'preferences':
        foodContext = FoodDetailContext.foodPreferences;
        preSelectedCategories = null; // All categories available
        break;
      case 'carb_loading':
        foodContext = FoodDetailContext.carbLoading;
        preSelectedCategories = null;
        break;
      default:
        foodContext = FoodDetailContext.addFood;
        preSelectedCategories = null;
    }

    // Navigate to FoodDetailScreen and await result
    final result = await context.pushNamed<dynamic>(
      'food-detail',
      extra: {
        'foodData': FoodDetailData.fromFood(food),
        'mode': FoodDetailMode.addFromScan,
        'screenContext': foodContext,
        'preSelectedCategories': preSelectedCategories,
        'showCategories': widget.category != 'carb_loading',
        'showProductType': true,
        'allowDelete': false,
      },
    );

    // Handle result
    if (!mounted) return;

    if (result is FoodDetailResult) {
      // Create updated Food object from result
      final updatedFood = Food(
        id: result.foodId,
        name: result.name,
        imageAddress: food.imageAddress,
        description: food.description,
        instructions: food.instructions,
        servingAmount: result.servingAmount,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        categories: result.categoryIds.map((id) {
          switch (id) {
            case 1:
              return 'before_run';
            case 2:
              return 'during_run';
            case 3:
              return 'after_run';
            default:
              return 'before_run';
          }
        }).toList(),
        servingUnit: result.servingUnit,
        servingSize: result.servingSize,
        carbsPerServing: result.carbsPerServing,
        sodiumMg: result.sodiumMg,
        fluidMlPerServing: result.fluidMlPerServing,
        caloriesPerServing: result.caloriesPerServing,
        proteinPerServing: result.proteinPerServing,
        fatPerServing: result.fatPerServing,
        productTypeId: result.productType,
        beforeRunSuitable: result.categoryIds.contains(1),
        duringRunSuitable: result.categoryIds.contains(2),
      );
      // Pop back to calling screen with the updated food
      context.pop(updatedFood);
    } else {
      // User cancelled - reset scanning
      _resetScanning();
    }
  }

  void _showNotFoundResult(String barcode, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                size: AppIconSizes.xl,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Product Not Found',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Barcode: $barcode',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: KyleSecondaryButton(
                      text: 'Try Another',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetScanning();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: KylePrimaryButton(
                      text: 'Cancel',
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleSecondaryButton(
                text: 'Create Manually',
                icon: FontAwesomeIcons.plus,
                onPressed: () {
                  Navigator.of(context).pop();
                  _openCreateFoodScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvalidFormatResult(String barcode, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.xmark,
                size: AppIconSizes.xl,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Invalid Barcode',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Barcode: $barcode',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              KyleSecondaryButton(
                text: 'Try Another',
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScanning();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleSecondaryButton(
                text: 'Create Manually',
                icon: FontAwesomeIcons.plus,
                onPressed: () {
                  Navigator.of(context).pop();
                  _openCreateFoodScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.lgRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                size: AppIconSizes.xl,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Error',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: KyleSecondaryButton(
                      text: 'Try Again',
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetScanning();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: KylePrimaryButton(
                      text: 'Cancel',
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open create food screen with empty form
  Future<void> _openCreateFoodScreen() async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailScreen(
          foodData: FoodDetailData(
            id: uuid,
            name: '',
            categoryIds: [1, 2, 3],
          ),
          mode: FoodDetailMode.createNew,
          screenContext: FoodDetailContext.addFood,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (result != null && result is FoodDetailResult && mounted) {
      // Create Food object from the result and pop back
      final food = Food(
        id: result.foodId.isEmpty ? uuid : result.foodId,
        name: result.name,
        categories: result.categoryIds.map((id) {
          switch (id) {
            case 1: return 'before_run';
            case 2: return 'during_run';
            case 3: return 'after_run';
            default: return 'before_run';
          }
        }).toList(),
        servingSize: result.servingSize,
        servingAmount: result.servingAmount,
        servingUnit: result.servingUnit,
        carbsPerServing: result.carbsPerServing,
        proteinPerServing: result.proteinPerServing,
        fatPerServing: result.fatPerServing,
        sodiumMg: result.sodiumMg,
        caloriesPerServing: result.caloriesPerServing,
        fluidMlPerServing: result.fluidMlPerServing,
        productTypeId: result.productType,
        beforeRunSuitable: result.categoryIds.contains(1),
        duringRunSuitable: result.categoryIds.contains(2),
      );
      context.pop(food);
    }
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
    setState(() {
      _flashOn = !_flashOn;
    });
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  FontAwesomeIcons.arrowLeft,
                  size: AppIconSizes.controlIcon,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Flash toggle button
          IconButton(
            onPressed: _toggleFlashlight,
            icon: Icon(
              _flashOn ? FontAwesomeIcons.bolt : FontAwesomeIcons.bolt,
              color: _flashOn ? AppColors.orange : Colors.white,
              size: AppIconSizes.md,
            ),
          ),
        ],
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
            bottom: 60,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),

          // Instructions
          if (_isScanning)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Text(
        'Position the barcode within the scanning area',
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reset scanning button
        _buildControlButton(
          icon: FontAwesomeIcons.arrowRotateRight,
          onPressed: _resetScanning,
          label: 'Reset',
        ),

        // Switch camera button
        _buildControlButton(
          icon: FontAwesomeIcons.cameraRotate,
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.electrolyte.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Colors.white,
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
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.electrolyte
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
      ..addRRect(RRect.fromRectAndRadius(scannerRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw scanner border
    canvas.drawRRect(
      RRect.fromRectAndRadius(scannerRect, const Radius.circular(12)),
      borderPaint,
    );

    // Draw corner indicators
    const cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = AppColors.electrolyte
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
