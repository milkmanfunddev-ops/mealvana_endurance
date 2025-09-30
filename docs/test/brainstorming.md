# Mealvana Updated Testing Brainstorming

## Ideas

### Define and Organize
1. Define critical paths that need to be tested.  
2. Organize existing testing folders and delete old, obsolete tests. 
3. Clearly define and organize testing folder systematically to incorporate unit, widget and integration tests.

### Migrate to Riverpod 3.0 and use Enhanced Testing Utilities

New testing utilities
ProviderContainer.test
In 2.0, typical testing code would rely on a custom-made utility called createContainer.
In 3.0, this utility is now part of Riverpod, and is called ProviderContainer.test. It creates a new container, and automatically disposes it after the test ends.

void main() {
  test('My test', () {
    final container = ProviderContainer.test();
    // Use the container
    // ...
    // The container is automatically disposed after the test ends
  });
}

You can safely do a global search-and-replace for createContainer to ProviderContainer.test.

NotifierProvider.overrideWithBuild
It is now possible to mock only the Notifier.build method, without mocking the whole notifier. This is useful when you want to initialize your notifier with a specific state, but still want to use the original implementation of the notifier.

riverpod
riverpod_generator
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}

void main() {
  final container = ProviderContainer.test(
    overrides: [
      myProvider.overrideWithBuild((ref) {
        // Mock the build method to start at 42.
        // The "increment" method is unaffected.
        return 42;
      }),
    ],
  );
}

Future/StreamProvider.overrideWithValue
A while back, FutureProvider.overrideWithValue and StreamProvider.overrideWithValue were removed "temporarily" from Riverpod.
They are finally back!

riverpod
riverpod_generator
@riverpod
Future<int> myFutureProvider() async {
  return 42;
}

void main() {
  final container = ProviderContainer.test(
    overrides: [
      // Initializes the provider with a value.
      // Changing the override will update the value.
      myFutureProvider.overrideWithValue(AsyncValue.data(42)),
    ],
  );
}

WidgetTester.container
A simple way to access the ProviderContainer in your widget tree.

void main() {
  testWidgets('can access a ProviderContainer', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyWidget()));
    ProviderContainer container = tester.container();
  });
}

### Claude Code Strategies

1. get a good claude code testing agent setup
2. Define a workflow that creates a roadmap and that explicitly calls the testing agent
3. Add automatic testing for version releases

### Leverage Flutter Web
1. Get flutter web working
2. Can use integration tests with flutter web for faster integration testing

### Packages to Use

1. vitest for local supabase edge function testing
2. drift_test for local Drift testing and testing if migrations are working.
4. flutter_test for unit/widget tests
5. vitest for local edge-function testing
6. integration_test for integration testing using flutter web
7. Patrol for integration testing using ios

### Next Steps
1. Delete/organize testing folder
2. Define claude code agent
3. get flutter web working
4. Create at least 1 unit test, widget test and integration test.  
5. Get CI/CD process up and running and incorporate tests to that process.
6. mocktail/http_mock_adapter
