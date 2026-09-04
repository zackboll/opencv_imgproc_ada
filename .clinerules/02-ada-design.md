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

`Mat` should be a tagged type with primitive operations so that both ordinary and prefixed notation are available.

For example:

```ada
Row_Count := Rows (Image);
Row_Count := Image.Rows;

Copy := Clone (Image);
Copy := Image.Clone;
```

The public view of `Mat` should hide its implementation details.

Its full private implementation may derive from `Ada.Finalization.Controlled` to provide deterministic lifetime management and OpenCV-compatible shallow-copy semantics.

Do not manufacture tagged-type inheritance hierarchies merely to imitate C++ classes.

In particular, do not create separate subclasses such as:

- `UInt8_Mat`
- `Float_Mat`
- `RGB_Mat`

solely to represent runtime OpenCV matrix type metadata.

Use tagged types where they improve the Ada abstraction, not simply because the corresponding OpenCV type is a C++ class.

Value-like OpenCV abstractions such as points, sizes, rectangles, vectors, and scalars should generally remain value types or generic records unless there is a strong Ada-specific reason to make them tagged.

## Public Naming Conventions

Preserve recognizable OpenCV domain type names where they are already concise and widely understood.

Examples include:

- `Mat`
- `Point`
- `Size`
- `Scalar`
- `Range`

Use Ada-style operation names for the public API.

Prefer descriptive names such as:

- `Rows`
- `Columns`
- `Channels`
- `Depth`
- `Element_Size`
- `Is_Empty`
- `Clone`

Prefer descriptive Ada names over terse C++ spellings such as:

- `cols`
- `elemSize`
- `ptr`

When an operation is naturally associated with a tagged type, define it as a primitive operation so prefixed notation is available.

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

Do not expose OpenCV preprocessor macros such as `CV_8UC3` as the primary public type system.

Represent matrix depth and channel information using strong Ada types and constructors or helper functions.

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

For public value types such as points, sizes, rectangles, vectors, and scalars, prefer Ada numeric types or clearly defined Ada numeric subtypes whose ranges and precision match the intended OpenCV semantics.

When exact ABI width matters, document and enforce it in the internal layer rather than making the public API C-centric.

Avoid unchecked or implicit narrowing conversions.

Use range checks, preconditions, or explicit conversion helpers where conversion could lose information.

## Matrix Depth and Channel Types

Represent OpenCV matrix depth and channel information with strong Ada types in the thick public API.

Do not expose OpenCV packed integer type encodings such as `CV_8U`, `CV_32F`, or `CV_8UC3` as the primary public type system.

Use an Ada enumeration for matrix depth, conceptually including values such as:

- `UInt8`
- `Int8`
- `UInt16`
- `Int16`
- `Int32`
- `Float32`
- `Float64`
- `Float16`

Represent the number of channels with a constrained Ada subtype.

Represent the runtime matrix element format as a small Ada value type containing:

- element depth
- channel count

For example, the public API should conceptually allow:

```ada
RGB_Type : constant Mat_Type :=
  (Depth    => UInt8,
   Channels => 3);
```

The internal interoperability layer is responsible for translating between the Ada representation and OpenCV's packed integer type encoding.

`Mat` remains runtime-typed. Do not encode matrix depth or channel count into a tagged-type inheritance hierarchy.

Provide operations such as:

```ada
Pixel_Depth   := Image.Depth;
Channel_Count := Image.Channels;
Pixel_Type    := Image.Element_Type;
```

where appropriate.

Compatibility constants corresponding to familiar OpenCV names may be added later if useful, but they must be layered on top of the strong Ada type system rather than defining it.

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

- strong type construction
- depth and channel validation
- Ada range checks
- convenience overloads
- generic typed-access wrappers
- Ada exception translation
- simple value-type helpers
- representation conversions that do not require OpenCV itself

Do not turn the shim into a second high-level wrapper library.

Do not reimplement meaningful OpenCV algorithms in Ada merely to avoid crossing the ABI boundary.

If OpenCV already provides an operation, the binding should normally call OpenCV so behavior, compatibility, and performance remain aligned with the underlying library.
