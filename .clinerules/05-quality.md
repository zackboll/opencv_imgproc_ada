# Quality and Tooling Rules

## Build Cleanliness

Keep the repository buildable throughout development.

Do not continue stacking implementation changes on top of a known broken
build unless the current task is specifically to investigate that failure.

Before considering a coding task complete, verify the affected crate with the
project's configured Alire/GNAT toolchain.

New code should not introduce compiler warnings.

Treat warnings from the normal development build as issues to fix unless
there is a specific documented reason to suppress one.

Prefer fixing the underlying problem over broadly disabling warning classes.

Do not consider a task complete while knowingly leaving:

- compilation errors
- unresolved linker errors
- broken Alire dependencies
- new compiler warnings
- tests broken by the change


## Development Tool Environment

The public `opencvcore_ada` crate must not acquire testing, proof, coverage,
or other development-only dependencies merely to make development tools
available.

GNATprove and GNATcov are dependencies of the `tests` Alire crate.

When these tools are used to analyze library code, invoke them through the
Alire environment provided by the `tests` crate and explicitly target the
appropriate project when necessary.

Do not bypass the project's Alire environment with an unrelated system GNAT
toolchain unless there is a specific reason to do so.

This repository-specific tool-environment policy takes precedence over generic
skill guidance about selecting an Alire environment.


## SPARK and GNATprove

Use SPARK where it provides meaningful assurance in the Ada portion of the
binding.

Good candidates include:

- range and bounds validation
- matrix dimension validation
- matrix type and channel validation
- index calculations
- conversion helpers
- value-type operations
- pure Ada utility code
- contracts on public Ada operations

Do not force the C or C++ interoperability layer into SPARK when the foreign
boundary prevents meaningful proof.

Treat calls across the C/C++ boundary as trusted external operations unless a
stronger formal model has deliberately been provided.

Use preconditions, postconditions, invariants, assertions, and strong types
when they express meaningful requirements.

Do not add contracts solely to improve proof statistics.

When SPARK-compatible code is materially changed, run an appropriately scoped
GNATprove analysis when practical.

Clearly distinguish among:

- properties proven by GNATprove
- properties enforced by Ada runtime checks
- properties assumed across the C/C++ boundary
- behavior established only through testing

Detailed GNATprove invocation, proof-campaign strategy, and output
interpretation belong to the GNATprove skill rather than this file.


## Source Formatting

Use GNATformat for Ada source formatting.

Format newly created or substantially modified Ada source before considering
a task complete.

Do not perform repository-wide formatting as an unrelated side effect.

Do not reformat unrelated source merely because the formatter would change
it.

Keep formatting-only changes separate from functional changes when practical.

If the formatter and an explicit repository coding convention disagree,
follow the repository convention and adjust formatter configuration where
appropriate rather than repeatedly hand-correcting generated formatting.

Detailed tool-location and invocation discovery should be handled through the
appropriate Alire/tool skill rather than hard-coded here unless the repository
requires a specific invocation.


## Verification

Perform verification appropriate to the change.

Typical checks include:

1. format modified Ada source
2. build the affected crate
3. run focused AUnit tests
4. run GNATprove for affected SPARK-compatible code when appropriate
5. run GNATcov when the size or risk of the change justifies coverage analysis
6. inspect the final diff for unrelated changes
7. complete the validation-boundary review when `cpp/opencv_core_shim.cpp` changed

## Validation-Boundary Review

Before finishing any feature that modifies `cpp/opencv_core_shim.cpp`, inspect every new or changed C++ guard involving:

- empty
- rows
- cols
- dims
- depth
- channels
- type
- shape
- semantic ranges
- public mode or enum combinations

Classify each guard as:

- ABI / memory safety, which belongs in C++
- public semantic policy, which belongs in thick Ada
- a semantic-looking condition retained only because bypassing it is unsafe

Do not leave a duplicated public semantic check in C++ without an

    // ABI safety: <specific justification>

comment.

The final feature summary must state either:

    No public semantic validation is duplicated in the C++ shim.

or identify every retained duplicate condition and its ABI-safety reason.

Do not add a brittle static-analysis or grep-based checker for this distinction. Prefer these architectural rules and this explicit review checklist.

Not every task requires every possible verification tool.

Choose checks according to what changed and what risks need to be validated.

A successful verification remains evidence for the repository state on which
it was run. Do not repeat an expensive verification solely because the task
has reached a later checklist step when no relevant files have changed.

After relevant code, configuration, or test changes, previous verification for
the affected area becomes stale and should be rerun as necessary.

If an important check cannot be performed, state:

- which check was not performed
- why
- what remains unverified

Do not claim verification that was not actually performed.