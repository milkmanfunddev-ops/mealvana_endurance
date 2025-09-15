How to Unit Test AsyncNotifier Subclasses with Riverpod 2.0 in Flutter
#dart
#flutter
#state-management
#riverpod
#testing
Andrea Bizzotto
Andrea Bizzotto

Nov 11, 2022
11 min read

Source code on GitHub
Writing Flutter apps got a lot easier with the release of Riverpod 2.0.

The new @riverpod syntax lets us use build_runner to generate all the providers on the fly.

And the new AsyncNotifier class makes it easier to perform asynchronous initialization with a more ergonomic API, compared to the good old StateNotifier.

I've already covered many of the Riverpod 2.0 changes in these two articles:

How to Auto-Generate your Providers with Flutter Riverpod Generator
How to use Notifier and AsyncNotifier with the new Flutter Riverpod Generator
But when it comes to writing tests, things can get tricky, and it can be challenging to get them working.

And if we upgrade our code by replacing StateNotifier with AsyncNotifier, we will find that old tests based on StateNotifier will no longer work.

So in this article, we'll learn how to write unit tests for AsyncNotifier subclasses.

Here is what we will cover:

how to work with ProviderContainer and override providers inside our tests
how to set up a provider listener using a ProviderSubscription
how to verify that the listener is called using the mocktail package
Along the way, we'll discover some gotchas and highlight the advantages of testing with listeners vs. streams.

By the end of this article, you'll have a better understanding and a clear template for writing unit tests with Riverpod. 💪

The official Riverpod docs already include a helpful page about testing, but it doesn't show how to write asynchronous tests for classes with dependencies. This article will fill the gaps.

Example: An AsyncNotifier subclass
As an example, let's consider the following AsyncNotifier subclass:

// 1. import this
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 2. declare a part file
part 'auth_controller.g.dart';

// 3. annotate
@riverpod
// 4. extend like this
class AuthController extends _$AuthController {
  // 5. override the [build] method to return a [FutureOr]
  @override
  FutureOr<void> build() {
    // 6. return a value (or do nothing if the return type is void)
  }

  Future<void> signInAnonymously() async {
    // 7. read the repository using ref
    final authRepository = ref.read(authRepositoryProvider);
    // 8. set the loading state
    state = const AsyncLoading();
    // 9. sign in and update the state (data or error)
    state = await AsyncValue.guard(authRepository.signInAnonymously);
  }
}
The purpose of this class is to:

sign-in anonymously using authRepository as a dependency
notify any listener widgets when the state changes (data, loading, or error)
I have already covered this example class in the previous article about Notifier and AsyncNotifier, so I won't repeat all the details here.

Instead, let's dive straight into the tests. 👇

Overview of the unit tests
Once again, here's the class we want to test:

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // state will be [AsyncData] once this method returns
  }

  Future<void> signInAnonymously() async {
    final authRepository = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    // state will be [AsyncData] on success, or [AsyncError] on error
    state = await AsyncValue.guard(authRepository.signInAnonymously);
  }
}
To fully test this class, we need to check that the state is correctly initialized when we create the AuthController.

And when we call the signInAnonymously method, we should verify that:

the state is set to AsyncLoading
authRepository.signInAnonymously() is called
when the AsyncValue.guard call returns, the state is set to AsyncData or AsyncError
To cover all these scenarios, we'll write three separate tests:

initial state
sign-in success
sign-in failure
So let's get started. 👇

Writing the first test (initalization)
Here's the entire code for the first test, which is based on the testing guide in the official Riverpod docs:

import 'package:mocktail/mocktail.dart';

// create a mock for the class we need to test
class MockAuthRepository extends Mock implements FakeAuthRepository {}

// a generic Listener class, used to keep track of when a provider notifies its listeners
class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  // a helper method to create a ProviderContainer that overrides the authRepositoryProvider
  ProviderContainer makeProviderContainer(MockAuthRepository authRepository) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('initial state is AsyncData', () {
    final authRepository = MockAuthRepository();
    // create the ProviderContainer with the mock auth repository
    final container = makeProviderContainer(authRepository);
    // create a listener
    final listener = Listener<AsyncValue<void>>();
    // listen to the provider and call [listener] whenever its value changes
    container.listen(
      authControllerProvider,
      listener,
      fireImmediately: true,
    );
    // verify
    verify(
      // the build method returns a value immediately, so we expect AsyncData
      () => listener(null, const AsyncData<void>(null)),
    );
    // verify that the listener is no longer called
    verifyNoMoreInteractions(listener);
    // verify that [signInAnonymously] was not called during initialization
    verifyNever(authRepository.signInAnonymously);
  });
});
The most important part of the test is the call to container.listen().

final listener = Listener<AsyncValue<void>>();
// listen to the provider and call [listener] whenever its value changes
container.listen(
  authControllerProvider,
  listener,
  fireImmediately: true,
);
Calling this method on the authControllerProvider causes the underlying AuthController to be initialized, since all providers are lazy-loaded.

And since the listener itself is a mock object, we can use it to verify if it's called:

verify(
  // the build method returns a value immediately, so we expect AsyncData
  () => listener(null, const AsyncData<void>(null)),
);
In this case, we expect the previous value to be null and the next value to be AsyncData<void>(null).

Always use type annotations when working with generics in tests. If you don't and simply use AsyncData(null), the test will fail because AsyncData<dynamic> is not the same as AsyncData<void>.

Our first test is complete, and we can reuse most of the code as we focus on the remaining tests.

Writing the second test (success)
Here's the full code for the second test:

test('sign-in success', () async {
  final authRepository = MockAuthRepository();
  // stub method to return success
  when(authRepository.signInAnonymously).thenAnswer((_) => Future.value());
  // create the ProviderContainer with the mock auth repository
  final container = makeProviderContainer(authRepository);
  // create a listener
  final listener = Listener<AsyncValue<void>>();
  // listen to the provider and call [listener] whenever its value changes
  container.listen(
    authControllerProvider,
    listener,
    fireImmediately: true,
  );
  // store this into a variable since we'll need it multiple times
  const data = AsyncData<void>(null);
  // verify initial value from the build method
  verify(() => listener(null, data));
  // get the controller via container.read
  final controller = container.read(authControllerProvider.notifier);
  // run
  await controller.signInAnonymously();
  // verify
  verifyInOrder([
    // transition from data to loading state
    () => listener(data, AsyncLoading<void>()),
    // transition from loading state to data
    () => listener(AsyncLoading<void>(), data),
  ]);
  verifyNoMoreInteractions(listener);
  verify(authRepository.signInAnonymously).called(1);
});
The setup code is quite similar to the previous test.

What is most interesting is this code:

  // get the controller via container.read
  final controller = container.read(authControllerProvider.notifier);
  // run
  await controller.signInAnonymously();
  // verify
  verifyInOrder([
    // transition from data to loading state
    () => listener(data, AsyncLoading<void>()),
    // transition from loading state to data
    () => listener(AsyncLoading<void>(), data),
  ]);
  verifyNoMoreInteractions(listener);
  verify(authRepository.signInAnonymously).called(1);
In this case, we get our controller by reading it from the container.

If you're testing a class that uses ref internally, you can't instantiate it directly, as this will lead to a LateInitializationError. Instead, read the corresponding provider from the ProviderContainer to ensure the provider's state is initialized correctly.

Then, we can use it to call controller.signInAnonymously().

And after that, we can verify that the state is set twice with the verifyInOrder method.

And finally, we can verify that the authRepository.signInAnonymously method is called.

The test fails... now what?
But if we run the test above, we get a scary-looking error:

Matching call #0 not found. All calls: [VERIFIED]
Listener<AsyncValue<void>>.call(null, AsyncData<void>(value: null)),
Listener<AsyncValue<void>>.call(AsyncData<void>(value: null), AsyncLoading<void>(value: null)),
Listener<AsyncValue<void>>.call(AsyncLoading<void>(value: null), AsyncData<void>(value: null))
At first sight, it seems like everything is in order since the listener is called for each state transition:

from null to AsyncData (during initialization)
from AsyncData to AsyncLoading (loading state)
from AsyncLoading to AsyncData (final state once sign-in completes)
But on closer inspection, there is a subtle difference between the actual and expected value:

AsyncLoading<void>(value: null) != AsyncLoading<void>()
This happens because even though we set the state to AsyncLoading() inside our controller, AsyncNotifier will inject the previous data (null in this case). And this causes the test to fail. 😭

After pulling my hair for a while and chatting to Remi about it, I figured out a solution. 👇

Solution: use a matcher
Long story short: to get the test to work, we can replace this code:

// verify
verifyInOrder([
  // transition from data to loading state
  () => listener(data, AsyncLoading<void>()),
  // transition from loading state to data
  () => listener(AsyncLoading<void>(), data),
]);
With this:

verifyInOrder([
  // set loading state
  // * use a matcher since AsyncLoading != AsyncLoading with data
  () => listener(data, any(that: isA<AsyncLoading>())),
  // data when complete
  () => listener(any(that: isA<AsyncLoading>()), data),
]);
This will result in yet another error message:

Bad state: A test tried to use `any` or `captureAny` on a parameter of type `AsyncValue<void>`, but
registerFallbackValue was not previously called to register a fallback value for `AsyncValue<void>`.
We can resolve this by adding a setUpAll method to our test file:

  setUpAll(() {
    registerFallbackValue(const AsyncLoading<void>());
  });
And with this in place, the test now succeeds. ✅

You can learn more about any and registerFallbackValue in the mocktail documentation.

Writing the third test (failure)
The last test we need to write is quite similar to the previous one:

test('sign-in failure', () async {
  // setup
  final authRepository = MockAuthRepository();
  final exception = Exception('Connection failed');
  when(authRepository.signInAnonymously).thenThrow(exception);
  final container = makeProviderContainer(authRepository);
  final listener = Listener<AsyncValue<void>>();
  container.listen(
    authControllerProvider,
    listener,
    fireImmediately: true,
  );
  const data = AsyncData<void>(null);
  // verify initial value from build method
  verify(() => listener(null, data));
  // run
  final controller = container.read(authControllerProvider.notifier);
  await controller.signInAnonymously();
  // verify
  verifyInOrder([
    // set loading state
    // * use a matcher since AsyncLoading != AsyncLoading with data
    () => listener(data, any(that: isA<AsyncLoading>())),
    // error when complete
    () => listener(
        any(that: isA<AsyncLoading>()), any(that: isA<AsyncError>())),
  ]);
  verifyNoMoreInteractions(listener);
  verify(authRepository.signInAnonymously).called(1);
});
The only differences are that:

we stub our mock auth repository to throw an exception
we verify that the final state is any(that: isA<AsyncError>())
And with this, we've completed all the tests for the AuthController class.

For reference, here is the full source code:

AuthController tests
Testing with Streams vs Testing with Listeners
Testing with streams is notoriously tricky in Dart.

In comparison, testing with listeners has one big advantage.

And that is that we run first and verify after:

// run first
final controller = container.read(authControllerProvider.notifier);
await controller.signInAnonymously();
// verify after
verifyInOrder([
  // set loading state
  // * use a matcher since AsyncLoading != AsyncLoading with data
  () => listener(data, any(that: isA<AsyncLoading>())),
  // error when complete
  () => listener(
      any(that: isA<AsyncLoading>()), any(that: isA<AsyncError>())),
]);
Compare this to the code we'd write when working with streams:

// a controller based on [StateNotifier]
final controller = container.read(authControllerProvider.notifier);
// expect later
expectLater(
  controller.stream,
  emitsInOrder(const [
    AsyncLoading<void>(),
    AsyncData<void>(null),
  ]),
);
// then run
await controller.signInAnonymously();
In this case, we're testing a StateNotifier that gives us a Stream that we can use to verify the state changes.

This is counter-intuitive because we have to use expectLater and write the expectations before calling the method under test (controller.signInAnonymously).

For more details about testing with streams, read: How to Write Tests using Stream Matchers and Predicates in Flutter

Instead, the recommended way of writing tests for our notifier classes is to use listeners:

final listener = Listener();
container.listen(
  authControllerProvider,
  listener,
  fireImmediately: true,
);
This way, we can run the code under test first, and then verify that the listener is called. 👌

Conclusion: writing tests is hard
As we have seen, writing unit tests can be hard, and there are some gotchas we need to keep in mind.

To avoid wasting precious time on failing tests:

always use type annotations (on your code and tests)
use matchers such as any when you can't create expected values that are 100% equal to the actual values
By writing this article, I wanted to pave the way, so you don't have to struggle with the same issues.

And while the code we've written above may look unfamiliar at first, you can use it as a template when testing your own Notifier classes with Riverpod.

So don't give up on writing tests! 😉

And if you want to learn more about this topic, my course contains over three hours of content about testing alone. 👇

Flutter Foundations Course Now Available
I launched a brand new course that covers testing in great depth, along with other important topics like app architecture, state management, navigation & routing, and much more: