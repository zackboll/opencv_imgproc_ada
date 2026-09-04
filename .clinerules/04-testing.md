# Testing Rules

## Test Crate Ownership

All automated tests for `opencvcore_ada` belong in the separate `tests`
Alire crate.

Do not add AUnit or development-only verification tools as dependencies of
the top-level `opencvcore_ada` library crate.

The `tests` crate owns test and verification dependencies, including:

- `aunit`
- `gnatprove`
- `gnatcov`
- the local `opencvcore_ada` crate pinned to `..`

Test-only helpers and dependencies should remain under the `tests` crate
unless they are genuinely part of the reusable public library.

This repository-specific test-crate structure takes precedence over generic
tool guidance that assumes tests are part of the main crate.


## Testing Through the Public API

Every new public binding operation should normally have focused automated
test coverage.

Tests should verify:

- expected successful behavior
- important boundary conditions
- meaningful failure behavior

When adding a new public API operation, add or update its tests in the same
task rather than postponing test coverage.

Prefer assertions against the thick public Ada API.

Do not test internal C shim functions directly from ordinary AUnit tests
unless the purpose of the test is specifically to validate the
interoperability layer.

Where practical, verify observable OpenCV semantics rather than internal
implementation details.


## AUnit Organization

Organize hand-written AUnit tests by public feature or type.

Prefer focused test packages such as:

- `Mat_Tests`
- `Point_Tests`
- `Size_Tests`
- `Scalar_Tests`
- `Type_Conversion_Tests`

Each test should have one clear behavioral purpose.

Use descriptive test names that state what behavior is being verified.

Do not create one large test package containing unrelated functionality.


## Error and Boundary Tests

Test error translation deliberately.

When a public Ada operation can fail because of invalid Ada input, an ABI
error, or an OpenCV failure, verify the intended Ada-level behavior.

Important cases may include:

- invalid dimensions
- out-of-range indices
- incompatible matrix types
- invalid channel counts
- null or empty object states where meaningful
- OpenCV exceptions translated through the shim
- invalid arguments rejected by Ada validation before reaching the shim

Do not merely assert that some exception occurred when a specific Ada
exception is part of the public contract.

Do not depend on exact OpenCV exception-message wording unless that wording
has intentionally been made part of the Ada API.

A public operation with meaningful failure behavior should normally have at
least one negative-path test.


## Ownership and Lifetime Tests

Resource ownership must be tested explicitly for controlled wrappers such as
`Mat`.

For `Mat`, relevant tests include:

- default construction and destruction
- construction of a non-empty matrix
- Ada assignment
- shallow-copy behavior after assignment
- shared OpenCV storage behavior
- explicit `Clone` deep-copy behavior
- reassignment over an existing value
- finalization of one shallow copy while another remains valid
- self-assignment where relevant
- failure paths after native resources have been allocated

Tests should be capable of exposing problems such as:

- double destruction
- use-after-free
- leaked owned handles
- incorrect shallow-copy behavior
- accidental deep copies
- invalid handles retained after failure

Where ownership behavior can be observed through the public API, test it
through the public API rather than inspecting internal handles.

Use appropriate external memory-analysis tools when native lifetime problems
cannot be adequately detected through AUnit assertions alone.


## GNATtest Policy

The existing hand-written `tests` Alire crate is the authoritative testing
structure for this repository.

GNATtest is optional tooling. It does not define the repository's test
architecture.

Do not:

- replace the existing hand-written AUnit organization with GNATtest output
- add AUnit to the top-level `opencvcore_ada` crate for GNATtest
- blindly use a generic GNATtest `--tests-root` value that writes generated
  files into the existing test crate
- overwrite or reorganize hand-written tests merely to match GNATtest
  defaults

Before using GNATtest:

1. inspect the existing `tests` crate layout
2. determine exactly which files GNATtest will generate
3. choose locations that cannot overwrite or disrupt hand-written tests
4. preserve the existing test-crate ownership model
5. use GNATtest primarily as optional scaffolding unless explicitly requested
   otherwise

Repository-specific rules in this section take precedence over generic
GNATtest skill examples.


## Coverage

GNATcov is a development dependency of the `tests` crate.

Run coverage analysis through the test environment rather than adding GNATcov
to the public library crate.

Coverage should primarily help determine whether tests exercise:

- public Ada operations
- Ada validation paths
- error translation
- ownership and finalization
- representation conversions
- important branches and boundary conditions

Do not treat a high coverage percentage by itself as evidence of correctness.

Prefer meaningful behavioral coverage over tests written solely to increase a
coverage percentage.

Ada coverage and C++ shim coverage are distinct.

Do not assume GNATcov coverage of Ada code proves that all C++ shim paths are
covered. Use appropriate C or C++ coverage tooling separately if native shim
coverage becomes a project requirement.