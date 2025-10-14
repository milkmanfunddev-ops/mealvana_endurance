Testing your providers
A core part of the Riverpod API is the ability to test your providers in isolation.

For a proper test suite, there are a few challenges to overcome:

Tests should not share state. This means that new tests should not be affected by the previous tests.
Tests should give us the ability to mock certain functionalities to achieve the desired state.
The test environment should be as close as possible to the real environment.
Fortunately, Riverpod makes it easy to achieve all of these goals.

Setting up a test
When defining a test with Riverpod, there are two main scenarios:

Unit tests, usually with no Flutter dependency. This can be useful for testing the behavior of a provider in isolation.
Widget tests, usually with a Flutter dependency. This can be useful for testing the behavior of a widget that uses a provider.
Unit tests
Unit tests are defined using the test function from package:test.

The main difference with any other test is that we will want to create a ProviderContainer object. This object will enable our test to interact with providers.

A typical test using ProviderContainer will look like:

void main() {
  test('Some description', () {
    // Create a ProviderContainer for this test.
    // DO NOT share ProviderContainers between tests.
    final container = ProviderContainer.test();

    // TODO: use the container to test your application.
    expect(
      container.read(provider),
      equals('some value'),
    );
  });
}

Now that we have a ProviderContainer, we can use it to read providers using:

container.read, to read the current value of a provider.
container.listen, to listen to a provider and be notified of changes.
caution
Be careful when using container.read when providers are automatically disposed.
If your provider is not listened to, chances are that its state will get destroyed in the middle of your test.

In that case, consider using container.listen.
Its return value enables reading the current value of provider anyway, but will also ensure that the provider is not disposed in the middle of your test:

final subscription = container.listen<String>(provider, (_, __) {});

expect(
  // Equivalent to `container.read(provider)`
  // But the provider will not be disposed unless "subscription" is disposed.
  subscription.read(),
  'Some value',
);

Widget tests
Widget tests are defined using the testWidgets function from package:flutter_test.

In this case, the main difference with usual Widget tests is that we must add a ProviderScope widget at the root of tester.pumpWidget:

void main() {
  testWidgets('Some description', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: YourWidgetYouWantToTest()),
    );
  });
}

This is similar to what we do when we enable Riverpod in our Flutter app.

Then, we can use tester to interact with our widget. Alternatively if you want to interact with providers, you can obtain a ProviderContainer. One can be obtained using tester.container().
By using tester, we can therefore write the following:

final container = tester.container();

We can then use it to read providers. Here's a full example:

void main() {
  testWidgets('Some description', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: YourWidgetYouWantToTest()),
    );

    final container = tester.container();

    // TODO interact with your providers
    expect(
      container.read(provider),
      'some value',
    );
  });
}

Mocking providers
So far, we've seen how to set up a test and basic interactions with providers. However, in some cases, we may want to mock a provider.

The cool part: All providers can be mocked by default, without any additional setup.
This is possible by specifying the overrides parameter on either ProviderScope or ProviderContainer.

Consider the following provider:

riverpod
riverpod_generator
// An eagerly initialized provider.
@riverpod
Future<String> example(Ref ref) async => 'Hello world';

We can mock it using:

// In unit tests, by reusing our previous "createContainer" utility.
final container = ProviderContainer.test(
  // We can specify a list of providers to mock:
  overrides: [
    // In this case, we are mocking "exampleProvider".
    exampleProvider.overrideWith((ref) {
      // This function is the typical initialization function of a provider.
      // This is where you normally call "ref.watch" and return the initial state.

      // Let's replace the default "Hello world" with a custom value.
      // Then, interacting with `exampleProvider` will return this value.
      return 'Hello from tests';
    }),
  ],
);

// We can also do the same thing in widget tests using ProviderScope:
await tester.pumpWidget(
  ProviderScope(
    // ProviderScopes have the exact same "overrides" parameter
    overrides: [
      // Same as before
      exampleProvider.overrideWith((ref) => 'Hello from tests'),
    ],
    child: const YourWidgetYouWantToTest(),
  ),
);

Spying on changes in a provider
Since we obtained a ProviderContainer in our tests, it is possible to use it to "listen" to a provider:

container.listen<String>(
  provider,
  (previous, next) {
    print('The provider changed from $previous to $next');
  },
);

You can then combine this with packages such as mockito or mocktail to use their verify API.
Or more simply, you can add all changes in a list and assert on it.

Awaiting asynchronous providers
In Riverpod, it is very common for providers to return a Future/Stream.
In that case, chances are that our tests need to await for that asynchronous operation to be completed.

One way to do so is to read the .future of a provider:

// TODO: use the container to test your application.
// Our expectation is asynchronous, so we should use "expectLater"
await expectLater(
  // We read "provider.future" instead of "provider".
  // This is possible on asynchronous providers, and returns a future
  // which will resolve with the value of the provider.
  container.read(provider.future),
  // We can verify that the future resolves with the expected value.
  // Alternatively we can use "throwsA" for errors.
  completion('some value'),
);

Mocking Notifiers
It is generally discouraged to mock Notifiers. This is because Notifiers cannot be instantiated on their own, and only work when used as part of a Provider.

Instead, you should likely introduce a level of abstraction in the logic of your Notifier, such that you can mock that abstraction. For instance, rather than mocking a Notifier, you could mock a "repository" that the Notifier uses to fetch data from.

If you insist on mocking a Notifier, there is a special consideration to create such a mock: Your mock must subclass the original Notifier base class: You cannot "implement" Notifier, as this would break the interface.

As such, when mocking a Notifier, instead of writing the following mockito code:

class MyNotifierMock with Mock implements MyNotifier {}

You should instead write:

riverpod
riverpod_generator
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => throw UnimplementedError();
}

// Your mock needs to subclass the Notifier base-class corresponding
// to whatever your notifier uses
class MyNotifierMock extends _$MyNotifier with Mock implements MyNotifier {}

info
If using code-generation, for the above to work, your mock will have to be placed in the same file as the Notifier you are mocking. Otherwise you would not have access to the _$MyNotifier class.

Then, to use your notifier you could do:

void main() {
  test('Some description', () {
    final container = ProviderContainer.test(
      // Override the provider to have it create our mock Notifier.
      overrides: [myProvider.overrideWith(MyNotifierMock.new)],
    );

    // Then obtain the mocked notifier through the container:
    final notifier = container.read(myProvider.notifier);

    // You can then interact with the notifier as you would with the real one:
    notifier.state = 42;
  });
}