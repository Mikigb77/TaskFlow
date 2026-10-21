# Provisional source review of the primary-session frame repair

Configured independent reviewer: `gpt-6.1-sol` / `max`. Source blob `50141eab8ad5cb28543658954ced9445d903678e` passes source inspection with no new finding. This is not empirical sign-off and does not close WEB-903.

- Bounds and header clearance are read inside one animation-frame callback, after the native activation task can finish. Existing instant reveal and zero-distance cancellation remain.
- Effect cleanup cancels the frame on completion reversal, reset or unmount. The callback also rechecks the banner ref, preventing scrolling after removal.
- Pointer-origin and keyboard latch guards are unchanged. Keyboard and assistive completion schedule no reveal.
- Native input/label identity and focus behavior are unchanged.
- The one-shot latch is consumed before scheduling; the effect depends only on `allComplete`, so ordinary completed-state rerenders cannot schedule another frame. No loop, timeout or focus operation was added.

The original EN desktop and CA mobile failures, deterministic pending-frame undo/close probes and refreshed capture matrix still require passing evidence. Source inspection cannot prove that one frame is sufficient. The three workflow source rounds remain exhausted and the primary-session repairs remain explicit escalations. The reviewer ran no tests/builds/captures and changed no files.
