# VectorJIT Standalone

A clean standalone iOS JIT enabler project — **not a StikDebug fork**.

The app:
- imports and stores the entire pairing record byte-for-byte;
- does not trim fields just because the same pairing file is used for more than one purpose;
- uses StikJIT directly for RSD tunnel, DDI preparation, and debugger/JIT enablement;
- targets another process by PID;
- supports `vectorjit://enable?pid=1234`;
- exposes DDI preparation/reset and detailed logs.

Built on GitHub Actions using a macOS 26 runner. The IPA is unsigned and intended for personal SideStore signing/testing.

StikJIT is built from its upstream source during CI and remains under its MPL-2.0 license.
