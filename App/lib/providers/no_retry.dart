/// Riverpod 3 retries a failed provider on its own; TaskFlow never has. A
/// failed load shows its error and waits for the person to try again.
Duration? noRetry(int retryCount, Object error) => null;
