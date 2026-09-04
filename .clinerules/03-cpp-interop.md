# C++ Shim and ABI Rules

## Stable C ABI Boundary

All communication between Ada and OpenCV C++ code must cross a C-compatible ABI boundary.

Export shim functions with `extern "C"`.

Where the shim header may also be consumed by C code, use the normal C++ guard pattern:

```c
#ifdef __cplusplus
extern "C" {
#endif

/* C ABI declarations */

#ifdef __cplusplus
}
#endif
```

Never expose C++ classes or C++ ABI-dependent types directly to Ada.

Do not expose across the ABI boundary:

- C++ references
- C++ exceptions
- STL containers
- C++ templates
- overloaded C++ functions
- C++ name-mangled symbols
- `std::string`
- `cv::Mat` or other OpenCV classes by value

Represent C++ objects using opaque handles.

For example:

```c
typedef struct opencv_core_mat_handle opencv_core_mat_handle;
```

The actual structure definition remains private to the C++ implementation.

Keep the ABI simple, explicit, and mechanically bindable from Ada.

## ABI-Safe Types

Use simple, explicitly representable C-compatible types across the Ada/C++ boundary.

Prefer:

- fixed-width integer types from `<stdint.h>`
- opaque pointers for C++ object handles
- plain C structs only when their layout is intentionally part of the ABI
- explicit pointer + length pairs for buffers and arrays
- fixed-width integer status values and flags

Avoid exposing ABI-sensitive or compiler-dependent types directly.

Do not expose:

- C++ `bool`
- C++ enum types
- references
- STL types
- compiler-specific class layouts
- bitfields
- overloaded function signatures

Use explicit representations such as:

```c
uint8_t
int8_t
uint16_t
int16_t
int32_t
uint32_t
int64_t
uint64_t
float
double
```

For boolean values, prefer an explicitly defined integer representation such as `uint8_t`, with documented values `0` and `1`.

Use `size_t` only when the value genuinely represents a native memory size, buffer size, or byte offset and the Ada binding deliberately maps it to the corresponding C-compatible type.

Do not assume Ada `Integer`, `Natural`, or other native Ada scalar types have the same ABI representation as their C or C++ counterparts.

All representation conversions belong in the thin Ada interoperability layer.

## Opaque Handle Ownership

Every opaque C++ object handle must have explicit ownership semantics.

For owned objects:

- the shim allocates or constructs the underlying C++ object
- Ada stores only the opaque handle
- Ada finalization calls the matching shim destroy function
- destroy functions should safely accept a null handle
- ownership transfer must be explicit and documented

Do not expose raw `cv::Mat *` or other OpenCV class pointers directly as the public ABI type.

Prefer dedicated opaque handle types for each object family.

For `Mat`, normal Ada assignment should use a shim copy operation that invokes OpenCV's normal shallow-copy semantics.

For example, the shim copy operation should create a distinct C++ `cv::Mat` object whose underlying matrix storage is shared according to OpenCV reference-counting semantics.

A separate shim operation should implement deep copying through `cv::Mat::clone()`.

The agent must never create two independently owned Ada handles referring to the exact same raw C++ wrapper object.

Shared OpenCV-managed data is permitted when the corresponding OpenCV object semantics explicitly support reference-counted sharing.

After destroying an owned object, the Ada side should clear its stored handle so repeated finalization cannot double-free the object.

## C ABI Naming

Use a consistent module-specific prefix for every exported C shim symbol.

For the OpenCV Core crate, use:

`opencv_core_`

Follow the prefix with the object or functional area and then the operation.

Examples:

```c
opencv_core_mat_create
opencv_core_mat_destroy
opencv_core_mat_copy
opencv_core_mat_clone
opencv_core_mat_rows
opencv_core_mat_columns
```

Future OpenCV module crates should use their own prefixes, for example:

- `opencv_imgproc_`
- `opencv_imgcodecs_`
- `opencv_videoio_`

Use lowercase `snake_case` for C ABI symbols.

Do not export short or generic names such as:

- `mat_create`
- `clone`
- `destroy`

Do not encode C++ overloads into ambiguous symbol names.

Each exported function must have one unambiguous C ABI signature.

## Strings and Diagnostic Messages

Do not transfer ownership of C++ strings directly across the ABI boundary.

Never expose `std::string` to Ada.

For diagnostic and exception messages, prefer thread-local storage owned by the C++ shim.

The shim may expose a function conceptually similar to:

```c
const char *opencv_core_last_error_message(void);
```

The returned pointer is borrowed.

Document that:

- Ada must not free the returned pointer
- the pointer is valid only until a subsequent shim operation changes the error state on the same thread
- callers that need to retain the message must copy it immediately
- error state must be maintained independently per thread

The thin Ada layer should copy borrowed C strings into Ada-owned strings before exposing the diagnostic to higher layers.

For general API strings passed from Ada to OpenCV, use explicitly documented UTF-8 encoded C strings unless the underlying OpenCV API requires another representation.

For returned strings that are ordinary API data rather than diagnostics, define explicit ownership and lifetime rules instead of using the last-error mechanism.

Never require Ada code to invoke C++ allocation or deallocation routines directly.

## Status and Return Conventions

Use a consistent explicit status representation for shim operations that can fail.

Prefer a fixed-width integer status type with named constants so the ABI representation is explicit.

For example:

```c
typedef int32_t opencv_core_status;

#define OPENCV_CORE_OK                     ((opencv_core_status)0)
#define OPENCV_CORE_ERROR_OPENCV           ((opencv_core_status)1)
#define OPENCV_CORE_ERROR_STD              ((opencv_core_status)2)
#define OPENCV_CORE_ERROR_UNKNOWN          ((opencv_core_status)3)
#define OPENCV_CORE_ERROR_INVALID_ARGUMENT ((opencv_core_status)4)
```

Functions that can fail should return the status code and place successful results in output parameters.

For example:

```c
opencv_core_status
opencv_core_mat_create(
    opencv_core_mat_handle **out_mat);
```

On success:

- return `OPENCV_CORE_OK`
- initialize all required output parameters

On failure:

- return a nonzero status
- put output handles into a known safe state, normally null
- preserve useful diagnostic information through the shim error-message mechanism

Output parameters should be initialized to safe values before performing operations that may throw.

Do not return an object handle as the sole indication of success or failure when meaningful error information may be available.

Functions that cannot reasonably fail, such as null-safe destruction, may return `void`.

Status values become part of the published C ABI and must remain stable once released.

## C++ Exception Handling

Every exported shim function that invokes potentially throwing C++ or OpenCV code must prevent exceptions from escaping across `extern "C"`.

Use a consistent exception translation policy.

Conceptually:

```cpp
try {
    /* OpenCV operation */
}
catch (const cv::Exception& e) {
    /* preserve diagnostic and return OPENCV_CORE_ERROR_OPENCV */
}
catch (const std::exception& e) {
    /* preserve diagnostic and return OPENCV_CORE_ERROR_STD */
}
catch (...) {
    /* preserve diagnostic and return OPENCV_CORE_ERROR_UNKNOWN */
}
```

Catch more specific exceptions before more general exceptions.

Do not allow destructors or cleanup paths exposed through the C ABI to throw.

The Ada layer must never depend on the C++ runtime unwinder crossing the ABI boundary.

## Argument Validation

Use Ada's type system and contracts as the primary validation mechanism in the thick public API.

Prefer:

- constrained subtypes
- strong domain-specific types
- preconditions
- range checks
- explicit null-state checks

to passing invalid values into the shim and waiting for OpenCV to reject them.

The thick Ada API is the single source of truth for public semantic policy. The C++ shim must not reimplement that policy merely for defense in depth, identical diagnostics, or friendlier messages.

The C++ shim must nevertheless perform sufficient defensive validation to protect the ABI boundary.

The shim must not blindly dereference:

- null object handles
- null output pointers
- invalid buffer pointers
- obviously invalid lengths or dimensions

when doing so could cause undefined behavior.

A typical result-producing shim function should:

1. clear the thread-local error state
2. initialize every output parameter to a safe value
3. reject null output pointers and null input handles
4. reject any other condition required to prevent undefined behavior
5. call OpenCV
6. publish owned outputs only after success
7. translate C++ exceptions into the C status model

The shim should not contain a second copy of the public Ada preconditions.

Distinguish between:

1. Ada-level programmer errors
2. invalid ABI arguments
3. valid inputs rejected by OpenCV

Ada-level programmer errors should normally be caught before crossing the ABI boundary.

Invalid ABI arguments should return an explicit shim error status rather than causing undefined behavior.

Valid operations rejected by OpenCV should preserve the resulting OpenCV diagnostic and be translated through the normal exception/error mechanism.

Do not duplicate semantic validation in both Ada and C++ unless it is required for safety.

If a semantic-looking C++ check must remain because bypassing it would be unsafe, document it with:

    // ABI safety: <specific reason this cannot safely be Ada-only>

Acceptable reasons include:

- OpenCV does not validate this condition before performing raw pointer access
- violating this condition can cause out-of-bounds access
- OpenCV accepts this representation but leaves part of the result uninitialized
- the shim itself performs pointer arithmetic that requires this invariant
- OpenCV performs signed integer arithmetic on dimensions or counts before it
  validates the result, so overflow must be rejected at the ABI boundary

"OpenCV might reject this" is not sufficient justification.

A raw C ABI caller is not entitled to the complete friendly public Ada contract. OpenCV should normally be allowed to reject invalid semantic input that reaches the shim when doing so is safe.

Do not add postcondition checks that merely restate documented OpenCV behavior unless they protect ownership, memory, or ABI safety.
