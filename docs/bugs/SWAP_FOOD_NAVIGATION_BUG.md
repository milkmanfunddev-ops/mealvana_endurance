# Swap Food Navigation Bug - Unsolved

**Date**: 2025-11-28
**Status**: UNSOLVED
**Severity**: High - Core functionality broken

## Problem Summary

When swapping a food item in the nutrition plan:
1. User creates an activity
2. User attempts to swap a food item
3. The swap operation completes successfully in the controller
4. The UI does NOT navigate back to the ActivityDetailScreen
5. User is stuck on SwapFoodScreen

## What Works

- ✅ Button press is detected (`🟢 SWAP/ADD BUTTON PRESSED`)
- ✅ `_handleConfirm()` executes completely
- ✅ `SwapFoodController.swapFood()` completes successfully
- ✅ `ActivityDetailController.swapFoodItem()` succeeds with `hasUnsavedChanges: true`
- ✅ `mounted` check passes (returns `true`)
- ✅ `goRouter.canPop()` returns `true`
- ✅ `goRouter.pop()` / `navigator.pop()` is called without exceptions
- ✅ Snackbar should be shown

## What Doesn't Work

- ❌ Screen does NOT navigate back after `pop()` is called
- ❌ SwapFoodScreen rebuilds instead of being dismissed
- ❌ User cannot return to ActivityDetailScreen to see swapped food

## Approaches Tried

### 1. Using `context.pop()` (go_router extension)
```dart
context.pop();
```
**Result**: Pop called, no navigation occurs

### 2. Capturing GoRouter before async and using `goRouter.pop()`
```dart
final goRouter = GoRouter.of(context);
// ... async operation ...
goRouter.pop();
```
**Result**: Pop called, no navigation occurs

### 3. Using `Navigator.of(context).pop()`
```dart
final navigator = Navigator.of(context);
// ... async operation ...
navigator.pop();
```
**Result**: Pop called, no navigation occurs

### 4. Using `Navigator.of(context, rootNavigator: true).pop()`
```dart
final navigator = Navigator.of(context, rootNavigator: true);
// ... async operation ...
navigator.pop();
```
**Result**: Pop called, no navigation occurs

### 5. Checking `goRouter.canPop()` before popping
```dart
if (goRouter.canPop()) {
  goRouter.pop();
}
```
**Result**: `canPop()` returns `true`, pop called, no navigation occurs

## Log Evidence

From the most recent swap attempt:
```
🟢 SWAP/ADD BUTTON PRESSED - about to call _handleConfirm
🔵 _handleConfirm START
🔵 _handleConfirm: food selected = Oatmeal, isSwapping = true
🔵 _handleConfirm: calling swapFood...
[SwapFoodController] Waiting for ActivityDetailController to initialize
[SwapFoodController] ActivityDetailController ready, performing swap
[ActivityDetailController] swapFoodItem ENTRY
[ActivityDetailController] swapFoodItem SUCCESS - state updated
[SwapFoodController] swapFoodItem returned
🔵 _handleConfirm: swapFood returned
🔵 _handleConfirm: operation complete, mounted = true
🔵 _handleConfirm: showing snackbar
🔵 _handleConfirm: goRouter.canPop() = true
🔵 _handleConfirm: calling goRouter.pop()
🔵 _handleConfirm: goRouter.pop() called
🔵 _handleConfirm END
🏗️ SwapFoodScreen build() called - isProcessing: true
🏗️ SwapFoodScreen build() called - isProcessing: false
[NO NAVIGATION OCCURS - LOGS END WITH SCREEN STILL VISIBLE]
```

## Observations

1. After `pop()` is called, SwapFoodScreen immediately rebuilds twice (`isProcessing: true` then `false`)
2. There's a massive food database reload (DELETE + INSERT 30+ foods) happening after swap
3. The ActivityDetailController state IS being updated successfully
4. No exceptions are thrown at any point
5. The back button in the AppBar (which uses `context.pop()`) behavior is unknown

## Relevant Files

- `/lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart` - The screen that won't dismiss
- `/lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart` - Controller handling swap logic
- `/lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart` - Controller with nutrition plan state
- `/lib/shared/core/app_router.dart` - go_router configuration (route: `/swap-food`)

## Navigation Flow

1. ActivityDetailScreen → `context.push('/swap-food', extra: {...})`
2. SwapFoodScreen displayed
3. User selects food and taps "SWAP FOOD" button
4. `_handleConfirm()` called
5. Swap completes in controller
6. `pop()` called
7. **BUG**: Screen rebuilds instead of navigating back

## Possible Root Causes (Uninvestigated)

1. **go_router internal state issue** - Something in go_router's state preventing the pop
2. **Provider rebuild triggering** - `ref.watch(swapFoodControllerProvider)` causing rebuild that interferes with navigation
3. **Navigator stack mismatch** - go_router and Flutter Navigator might have different stacks
4. **Route guard or interceptor** - Something preventing the navigation
5. **Async timing issue** - The rebuild happening before navigation can complete

## Suggested Next Steps

1. Check if the AppBar back button works - if it does, compare implementations
2. Add logging to go_router's navigation observer to see what happens during pop
3. Try removing the `ref.watch()` in SwapFoodScreen build method temporarily
4. Check if there's a `WillPopScope` or `PopScope` somewhere in the widget tree
5. Try using `context.go()` to navigate explicitly back to `/plan` instead of popping
6. Investigate the food database reload that happens after swap - might be related
7. Check if this is a go_router bug with their GitHub issues

## Temporary Workaround

None found. User must manually press back button or navigate away.
