# Memory Aligned Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

A move-only, alignment-guaranteed, growable owned byte region — `Memory.Aligned` — for direct I/O, SIMD, and page-aligned buffers, with no platform or Foundation dependency.

---

## Quick Start

`Memory.Aligned` owns a single out-of-line byte region whose base address is guaranteed to sit on a requested power-of-two boundary. It is `~Copyable` (unique ownership, no accidental copies of large allocations) and grows in place under a `Growth.Policy`, so the same region can start small and expand without losing its alignment.

```swift
import Memory_Aligned_Primitives

// A page-aligned, zero-filled scratch region — the shape O_DIRECT / DMA
// transfers require, where the buffer base must sit on a page boundary.
let pageAlignment = try Memory.Alignment(4096)
var region = try Memory.Aligned.zeroed(byteCount: 4096, alignment: pageAlignment)

precondition(region.isAligned(to: pageAlignment))

// Grow in place when a larger frame arrives: existing bytes are preserved
// and the region stays aligned across the reallocation.
try region.ensureCapacity(minimum: 8192)

// `Memory.Aligned` is move-only (~Copyable): passing it to another owner
// transfers ownership, so the compiler rules out accidental aliasing.
```

The region exposes its contents through borrow-scoped spans — `bytes` (`Span<Byte>`) and `mutableBytes` (`MutableSpan<Byte>`) — plus closure-based `withUnsafeBytes` / `withMutableRawSpan` accessors and read-only range subscripts. It conforms to `Span.Protocol`, so it plugs into any API that accepts contiguous byte storage. Allocation uses `UnsafeMutableRawPointer.allocate(byteCount:alignment:)`, so there are no platform-specific C imports and no page-size queries.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-memory-aligned-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Memory Aligned Primitives", package: "swift-memory-aligned-primitives"),
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Architecture

Two library products. Depends only on lower-tier primitives: `Byte`, `Memory.Address` / `Memory.Alignment`, `Span`, `Growth`, and `Index`.

| Product | Target | Purpose |
|---------|--------|---------|
| `Memory Aligned Primitives` | `Sources/Memory Aligned Primitives/` | The `Memory.Aligned` region: aligned allocation, in-place growth (`ensureCapacity` / `reserveDiscardingContents`), span and range-subscript access, byte copy / zero convenience, and `Span.Protocol` conformance. |
| `Memory Aligned Primitives Test Support` | `Tests/Support/` | Re-exports the main target for test consumers. |

Foundation-free.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
