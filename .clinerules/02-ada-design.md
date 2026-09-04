# Ada API Design Rules

## Idiomatic Ada First

The public API must look and feel like native Ada.

Do not mechanically transliterate the OpenCV C++ API.

Preserve OpenCV semantics, capabilities, and expected performance, but choose Ada constructs that best express those semantics.

Prefer:

- strong Ada types over integer constants
- enumerations over magic values
- overloads where they improve readability
- default parameters where appropriate
- ranges and subtypes where they add useful constraints
- controlled types for deterministic resource management
- generics for compile-time type families
- contracts for meaningful preconditions, postconditions, and invariants
- Ada exceptions for exceptional failures
- clear package boundaries instead of large monolithic APIs

Avoid exposing:

- C++ naming conventions
- raw pointers
- C-style status values
- implementation handles
- C++ template syntax
- STL concepts
- unnecessary `Interfaces.C` types

A user working only with the thick Ada layer should not need to understand the C++ shim.

## Tagged Types and Object-Oriented Design

Use Ada tagged types and primitive operations when the underlying OpenCV abstraction has genuine object identity, ownership, or object-oriented behavior.

`Mat` is the tagged type supplied by `OpenCV.Core`; imgproc APIs must reuse it rather than defining another Mat type.

For example:

```ada
Row_Count := Rows (Image);
Row_Count := Image.Rows;

Copy := Clone (Image);
Copy := Image.Clone;
```

`OpenCV.Core` owns Mat's private implementation, deterministic lifetime management, and OpenCV-compatible shallow-copy semantics. Imgproc operations must borrow Mats through the module-interoperability bridge and must not alter those ownership rules.

Do not manufacture tagged-type inheritance hierarchies merely to imitate C++ classes.

In particular, do not create separate subclasses such as:

- `UInt8_Mat`
- `Float_Mat`
- `RGB_Mat`

solely to represent runtime OpenCV matrix type metadata.

Use tagged types where they improve the Ada abstraction, not simply because the corresponding OpenCV type is a C++ class.

Common OpenCV value types and matrix metadata abstractions must be reused from `OpenCV.Core` where they already exist. This includes `Mat`, `Point`, `Size`, `Rect`, `Scalar`, `Depth_Type`, `Mat_Type`, channel information, and their associated operations.

`OpenCV.Image_Processing` may define a public type only when it is specifically required by the imgproc module and is not already supplied by `OpenCV.Core`.

## Public Naming Conventions

Reuse recognizable OpenCV domain types from `OpenCV.Core` rather than redeclaring them in `OpenCV.Image_Processing`.

Examples include:

- `Mat`
- `Point`
- `Size`
- `Scalar`
- `Range`

Reuse `OpenCV.Core` matrix operations such as `Rows`, `Columns`, `Channels`, `Depth`, `Element_Type`, and `Clone` rather than redeclaring them in this crate. Use Ada-style names for imgproc-specific public operations.

Prefer descriptive Ada names over terse C++ spellings such as:

- `cols`
- `elemSize`
- `ptr`

When an imgproc-specific operation is naturally associated with a tagged type defined by this crate, define it as a primitive operation so prefixed notation is available. Do not redeclare `OpenCV.Core` primitives merely to provide prefixed notation.

For example:

```ada
Row_Count     := Image.Rows;
Column_Count  := Image.Columns;
Channel_Count := Image.Channels;
Pixel_Depth   := Image.Depth;
Size_In_Bytes := Image.Element_Size;
Empty         := Image.Is_Empty;
Copy          := Image.Clone;
```

Do not expose OpenCV preprocessor macros such as `CV_8UC3` as the primary public type system. Reuse the strong matrix depth, channel, and type abstractions supplied by `OpenCV.Core` rather than redefining them in this crate.

Compatibility constants may be provided later if they are genuinely useful, but the thick Ada API should not depend on C macro naming conventions.

## Generic Value Types

Use Ada generics to model OpenCV value-type templates when the template parameter represents a genuine compile-time type or dimension.

Good candidates include:

- `Point_<T>`
- `Size_<T>`
- `Rect_<T>`
- `Vec<T, N>`
- `Matx<T, M, N>`

Provide a generic foundation, but also provide convenient predefined instances for the common OpenCV variants so ordinary users do not need to instantiate generics for routine use.

For example, predefined public types may include common integer, floating-point, and double-precision point variants corresponding to OpenCV's standard aliases.

Value-like types should normally be ordinary Ada records rather than tagged types.

Prefer stack-friendly, deterministic value semantics for these types.

Do not introduce heap allocation, opaque handles, or controlled types for simple value objects unless required by the underlying OpenCV semantics.

Use strong Ada numeric types and generic parameters rather than encoding type information into names or integer constants where practical.

## Numeric Representation

Keep C-compatible numeric types confined to the thin interoperability layer.

The thin Ada binding may use types such as:

- `Interfaces.C.int`
- `Interfaces.C.unsigned`
- `Interfaces.C.C_float`
- `Interfaces.C.double`
- other exact C-compatible representations required by the shim ABI

The thick public Ada API should instead expose natural Ada numeric types and strong domain-specific types.

Do not leak `Interfaces.C` types into the public API merely because OpenCV is implemented in C++.

Perform explicit conversions at the boundary between the thick Ada layer and the thin C-compatible layer.

For imgproc-specific public value types not already supplied by `OpenCV.Core`, prefer Ada numeric types or clearly defined Ada numeric subtypes whose ranges and precision match the intended OpenCV semantics.

When exact ABI width matters, document and enforce it in the internal layer rather than making the public API C-centric.

Avoid unchecked or implicit narrowing conversions.

Use range checks, preconditions, or explicit conversion helpers where conversion could lose information.

## Matrix Depth and Channel Types

`OpenCV.Core` owns `Depth_Type`, `Mat_Type`, channel information, and the runtime matrix metadata API. Imgproc APIs must reuse `Image.Rows`, `Image.Columns`, `Image.Channels`, `Image.Depth`, `Image.Element_Type`, and related `OpenCV.Core` operations.

Do not expose OpenCV packed integer type encodings such as `CV_8U`, `CV_32F`, or `CV_8UC3` as the primary public type system, and do not create imgproc-specific replacements for Core matrix metadata abstractions.

`OpenCV.Core.Mat` remains runtime-typed. Do not encode matrix depth or channel count into a tagged-type inheritance hierarchy in this crate.

## Ada vs C++ Responsibility

Keep the C++ shim as small as practical.

Use the C++ shim when OpenCV itself must perform the operation or when access to C++ object lifecycle, methods, overload resolution, templates, or OpenCV-owned storage is required.

Typical shim responsibilities include:

- constructing and destroying OpenCV C++ objects
- invoking OpenCV member functions
- calling OpenCV algorithms
- performing operations that require C++ templates or overload resolution
- accessing OpenCV-managed data buffers
- translating C++ exceptions into the C-compatible error model

Prefer implementing purely Ada-specific behavior in Ada.

Typical Ada responsibilities include:

- imgproc-specific type construction
- imgproc-specific semantic validation using `OpenCV.Core` metadata
- Ada range checks
- convenience overloads
- imgproc-specific convenience wrappers
- Ada exception translation
- simple imgproc-specific value-type helpers
- representation conversions that do not require OpenCV itself

Do not turn the shim into a second high-level wrapper library.

Do not reimplement meaningful OpenCV algorithms in Ada merely to avoid crossing the ABI boundary.

If OpenCV already provides an operation, the binding should normally call OpenCV so behavior, compatibility, and performance remain aligned with the underlying library.
