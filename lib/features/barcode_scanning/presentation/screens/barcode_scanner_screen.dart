import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass_sheet.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/barcode_scanner_service.dart';
import '../../../nutrition_plan/domain/food.dart';

/// Barcode Scanner Screen - Kyle's Design System
/// Unified scanner for all contexts (swap, add, preferences, carb loading)
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final String
  category; // 'before_run', 'during_run', 'after_run', 'add_food', 'preferences', 'carb_loading'
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
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isScanning = true;

  /// The start in flight, if any. A second start while one is running
  /// joins it instead of reaching the platform (finding 28-001).
  Future<void>? _startInFlight;

  /// True only when this screen stopped a running camera because the app
  /// went inactive or paused; resume restarts only in that case.
  bool _stoppedForLifecycle = false;
  String? _lastScannedBarcode;
  BarcodeScanResult? _lastScanResult;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
    // autoStart is disabled on the controller (see _initializeController) so
    // that every start() call in this screen goes through the same guarded
    // entry point (_safeStartScanner). Kick off the initial start here.
    _safeStartScanner();

    // Track scanner opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track(
        'barcode_scanner_opened',
        properties: {'category': widget.category, 'context': widget.context},
      );
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
      // Disabled so every start() call is funneled through
      // _safeStartScanner, which guards against the
      // `controllerInitializing` race (Sentry MEALVANA-ENDURANCE-79).
      autoStart: false,
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
        _resumeScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (_controller!.value.isRunning) {
          _stoppedForLifecycle = true;
          _safeStopScanner();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Start the scanner. All start() calls in this screen go through here
  /// (the controller is created with `autoStart: false`).
  ///
  /// - A call while a start is in flight joins that start rather than
  ///   starting again. Sentry MEALVANA-ENDURANCE-79 was the
  ///   `controllerInitializing` throw from that race.
  /// - After a start that ended in an error, only a permission error is
  ///   worth retrying. The iOS plugin leaves its capture session open when a
  ///   start fails (e.g. no camera), so any later start answers "already
  ///   started", and that error replaced the useful one on screen
  ///   (finding 28-001).
  Future<void> _safeStartScanner() {
    final controller = _controller;
    if (controller == null) return Future.value();
    final inFlight = _startInFlight;
    if (inFlight != null) return inFlight;
    final error = controller.value.error;
    if (error != null &&
        error.errorCode != MobileScannerErrorCode.permissionDenied) {
      return Future.value();
    }
    final start = () async {
      try {
        await controller.start();
      } on MobileScannerException catch (_) {
        // Still initializing or disposed: benign, nothing to do.
      }
    }();
    _startInFlight = start;
    return start.whenComplete(() {
      if (identical(_startInFlight, start)) _startInFlight = null;
    });
  }

  /// App resumed: wait for any start still in flight (the camera
  /// permission alert resumes the app while the first start waits on it),
  /// then restart only a camera that the inactive/paused state stopped.
  Future<void> _resumeScanner() async {
    await _startInFlight;
    if (!mounted || !_stoppedForLifecycle) return;
    _stoppedForLifecycle = false;
    await _safeStartScanner();
  }

  Future<void> _safeStopScanner() async {
    try {
      await _controller?.stop();
    } on MobileScannerException catch (_) {
      // Not initialized yet — nothing to stop.
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
    analytics.analytics.track(
      'barcode_scanned',
      properties: {'code': barcodeValue, 'category': widget.category},
    );

    // Perform barcode lookup
    _lookupBarcode(barcodeValue);
  }

  String _text(String key) => ref.read(contentServiceProvider).getValue(key);

  /// "Enter": a typed barcode for a device with no working camera
  /// (testing-wave 28-004). Takes the same lookup → confirm → pop path a
  /// scan does, from [_lookupBarcode] on.
  Future<void> _showEnterBarcodeSheet() async {
    final digits = await showGlassSheet<String>(
      context,
      builder: (_) => _EnterBarcodeSheet(
        title: _text(ContentKeys.barcodeScannerEnterTitle),
        body: _text(ContentKeys.barcodeScannerEnterBody),
        hint: _text(ContentKeys.barcodeScannerEnterHint),
        submit: _text(ContentKeys.barcodeScannerEnterSubmit),
      ),
    );
    if (digits == null || !mounted) return;

    setState(() {
      _isScanning = false;
      _lastScannedBarcode = digits;
    });
    await _safeStopScanner();
    if (!mounted) return;

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'barcode_entered',
          properties: {
            'code': digits,
            'category': widget.category,
            'context': widget.context,
          },
        );
    await _lookupBarcode(digits);
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
      _trackLookupFailed('not_found', result.barcode);
      _showNotFoundResult(result.barcode, result.message!);
    } else if (result.isInvalidFormat) {
      _trackLookupFailed('invalid_format', result.barcode);
      _showInvalidFormatResult(result.barcode, result.message!);
    } else {
      _trackLookupFailed('error', result.barcode);
      _showError(result.message ?? 'Unknown error occurred');
    }
  }

  /// Fire the scan-failure event so the barcode funnel can measure no-match /
  /// invalid / error rate (OpenFoodFacts coverage is barcode's make-or-break).
  void _trackLookupFailed(String reason, String code) {
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'barcode_lookup_failed',
          properties: {
            'reason': reason,
            'code': code,
            'category': widget.category,
            'context': widget.context,
          },
        );
  }

  void _showSuccessResult(Food food, String barcode) {
    // Get the API product from the last scan result
    dynamic apiProduct;
    if (_lastScanResult is BarcodeScanResultSuccess) {
      apiProduct = (_lastScanResult as BarcodeScanResultSuccess).apiProduct;
    }

    _showVerificationDialog(food, apiProduct);
  }

  /// Whether this scan originated from the meal-log ("Discover") flow rather
  /// than from adding/swapping a food in the nutrition plan.
  ///
  /// In that flow the user is logging what they ate, so the nutrition-plan
  /// before/during/after-run [FoodDetailScreen] is the wrong destination — we
  /// hand the raw scanned [Food] straight back to the caller, which routes to
  /// the logging-specific confirmation page.
  /// `build_meal_add_food` is the Build-a-Meal component search — also meal
  /// logging, also general food. It was previously omitted, so scanning there
  /// fell through to [FoodDetailScreen]'s "When would you eat this?
  /// Before/During/After Run" picker inside a plain meal builder.
  static const _mealLogContexts = {'meal_log_discover', 'build_meal_add_food'};

  bool get _isMealLogContext => _mealLogContexts.contains(widget.context);

  Future<void> _showVerificationDialog(Food food, dynamic apiProduct) async {
    // Meal logging: bypass the plan's category page and return the scanned food.
    if (_isMealLogContext) {
      context.pop(food);
      return;
    }

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
              FaIcon(
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
                icon: FontAwesomeIcons.plus.data,
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
              FaIcon(
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
                icon: FontAwesomeIcons.plus.data,
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
              FaIcon(
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
              const SizedBox(height: AppSpacing.sm),
              KyleSecondaryButton(
                text: 'Create Manually',
                icon: FontAwesomeIcons.plus.data,
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

  /// Open create food screen with empty form
  Future<void> _openCreateFoodScreen() async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailScreen(
          foodData: FoodDetailData(id: uuid, name: '', categoryIds: [1, 2, 3]),
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
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _lastScannedBarcode = null;
      _lastScanResult = null;
    });
    // Route through the guarded starter — a rapid double-tap of the reset
    // button (or a resume racing with it) can otherwise throw
    // `MobileScannerException(controllerInitializing)` unhandled.
    _safeStartScanner();
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
            const CustomAppBarBackButton(
              key: ValueKey('barcode.back_button'),
              margin: EdgeInsets.zero,
              iconColor: Colors.white,
              backgroundColor: Color(0x80000000),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              key: const ValueKey('barcode.title'),
              title,
              style: AppTextStyles.sectionTitle.copyWith(color: Colors.white),
            ),
          ],
        ),
        actions: [
          // Flash toggle button
          IconButton(
            key: const ValueKey('barcode.flash_button'),
            onPressed: _toggleFlashlight,
            icon: Icon(
              _flashOn
                  ? FontAwesomeIcons.bolt.data
                  : FontAwesomeIcons.bolt.data,
              semanticLabel: 'Flash',
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
              errorBuilder: (context, error) => _buildScannerError(error),
            ),

          // Scanner frame and instructions: only over a camera. Once the
          // camera has errored the error message and its link sit here, so
          // the frame is dropped and never takes their taps.
          if (_controller != null)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller!,
              builder: (context, value, _) {
                if (value.error != null) return const SizedBox.shrink();
                return IgnorePointer(
                  child: Stack(
                    children: [
                      _buildScannerOverlay(),
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
              },
            ),

          // Bottom controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  /// The camera could not start. The app's own words (content system)
  /// instead of the package's error widget with its developer text
  /// (findings 28-001, 28-004), and a way on: back to the caller's search.
  Widget _buildScannerError(MobileScannerException error) {
    final message = _text(switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        ContentKeys.barcodeScannerPermissionDenied,
      MobileScannerErrorCode.unsupported => ContentKeys.barcodeScannerNoCamera,
      _ => ContentKeys.barcodeScannerCameraFailed,
    });
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                key: const ValueKey('barcode.error'),
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                key: const ValueKey('barcode.search_link'),
                onPressed: () => context.pop(),
                child: Text(
                  _text(ContentKeys.barcodeScannerSearchInstead),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.electrolyte,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.electrolyte,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(painter: ScannerOverlayPainter(), size: Size.infinite);
  }

  Widget _buildInstructions() {
    return Container(
      key: const ValueKey('barcode.instructions'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Text(
        'Position the barcode within the scanning area',
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
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
          buttonKey: const ValueKey('barcode.reset_button'),
          icon: FontAwesomeIcons.arrowRotateRight.data,
          onPressed: _resetScanning,
          label: 'Reset',
        ),

        // Switch camera button
        _buildControlButton(
          buttonKey: const ValueKey('barcode.switch_button'),
          icon: FontAwesomeIcons.cameraRotate.data,
          onPressed: _switchCamera,
          label: 'Switch',
        ),

        // Type the barcode: the path for a device with no working camera.
        _buildControlButton(
          buttonKey: const ValueKey('barcode.enter_button'),
          icon: FontAwesomeIcons.keyboard.data,
          onPressed: _showEnterBarcodeSheet,
          label: _text(ContentKeys.barcodeScannerEnterLabel),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
    Key? buttonKey,
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
            key: buttonKey,
            // The caption names the button for a screen reader; the caption
            // itself is excluded so it is not read twice (testing-wave
            // 28-006: only the captions read, as text).
            icon: Icon(
              icon,
              semanticLabel: label,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ExcludeSemantics(
          child: Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// The "Enter a barcode" sheet: a numeric field that pops its digits.
/// Owns its text controller so the field outlives the sheet's exit.
class _EnterBarcodeSheet extends StatefulWidget {
  const _EnterBarcodeSheet({
    required this.title,
    required this.body,
    required this.hint,
    required this.submit,
  });

  final String title;
  final String body;
  final String hint;
  final String submit;

  @override
  State<_EnterBarcodeSheet> createState() => _EnterBarcodeSheetState();
}

class _EnterBarcodeSheetState extends State<_EnterBarcodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes the sheet with the typed digits; an empty entry stays open.
  void _submit(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    Navigator.of(context).pop(digits);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KyleInputField(
            key: const ValueKey('barcode.enter_field'),
            controller: _controller,
            hintText: widget.hint,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onSubmitted: _submit,
          ),
          const SizedBox(height: AppSpacing.md),
          KylePrimaryButton(
            key: const ValueKey('barcode.enter_submit'),
            text: widget.submit,
            onPressed: () => _submit(_controller.text),
          ),
        ],
      ),
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
      ..addRRect(
        RRect.fromRectAndRadius(scannerRect, const Radius.circular(12)),
      )
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
