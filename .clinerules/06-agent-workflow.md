# Agent Development Workflow

## Incremental Development

Work in small, reviewable steps.

Before modifying code:

- inspect the relevant existing source files
- inspect applicable Alire manifests and GPR project files
- understand the existing package hierarchy
- identify the smallest coherent change required by the task

Do not make large speculative rewrites.

Do not create packages, abstractions, compatibility layers, or infrastructure
in advance unless they are required by the current feature.

Prefer implementing and validating one coherent piece of functionality at a
time.

Do not continue stacking implementation changes on top of a known broken
build unless investigation of that failure is the current task.


## Tool Results and Failure Handling

Consume the result of each tool call before choosing the next action.

A failed command is diagnostic information.

When a command fails:

1. interpret the actual error
2. identify a plausible cause
3. choose a diagnostic or corrective action based on that evidence
4. retry only when doing so has a meaningful reason

Do not blindly repeat commands or make cosmetic command variations merely to
continue working.

Successful build, test, proof, formatting, coverage, and diagnostic results
remain useful evidence until repository state relevant to those results
changes.

The project `PreToolUse` hook may reject an immediately repeated identical
command.

Treat such a rejection as duplicate-command protection, not as a new command
failure. Use the previous command result and continue with a different
productive action.


## Terminal Commands

Use normal shell syntax when useful.

Do not HTML-encode shell operators or other shell characters.

Prefer commands that are clear, reproducible, and appropriate to the current
project environment.

Prefer Alire-aware execution for Ada development tools when the project or
tool requires the Alire environment.

Repository-specific rules about which Alire crate owns a development tool take
precedence over generic tool defaults.


## Command Simplicity

Prefer simple, single-purpose terminal commands.

Avoid multiline shell commands and heredocs when the same task can be
performed with a native Cline tool or a simple command.

Do not use:

- Python heredocs
- shell heredocs
- nested shells
- temporary scripts

merely to inspect, search, fetch, or transform information.

Multiline heredoc commands are especially discouraged because terminal shell
integration may fail to detect their completion reliably.

Use native Cline tools for structured operations whenever available.

Use terminal commands primarily for tools that genuinely need to run in the
project environment, such as:

- Alire
- GNAT
- GPRbuild
- GNATformat
- GNATprove
- GNATcov
- AUnit test executables
- Git
- pkg-config
- compiler and toolchain inspection

If a terminal command is required, prefer the simplest command that produces
the necessary evidence.

Do not combine unrelated operations into one large shell command merely to
reduce the number of tool calls.

Prefer commands whose completion and output can be reliably observed by the
terminal integration.


## File Modification

Modify repository source files using Cline's native file editing tools.

Use the native Read/Edit/Replace/Write tools for source and project-file
changes whenever those tools can perform the required modification.

Do not use shell commands or scripting languages merely to edit repository
files.

In particular, do not use these as source-file editing mechanisms:

- inline Python scripts
- Python heredocs
- shell heredocs
- `sed`
- `awk`
- `perl`
- `echo`-based rewriting
- `cat`-based rewriting
- shell redirection used to create or replace source files
- temporary scripts whose only purpose is to rewrite repository files

Do not call `python3`, Python, or another scripting language merely to perform
an edit, fetch public source, search text, or inspect information that can be
handled by Cline's native tools.

Avoid read-modify-write scripts that:

1. load an entire source file
2. locate marker strings
3. construct replacement text
4. rewrite the entire file

Use a targeted native edit instead.

Shell commands are appropriate for:

- inspecting repository state
- searching local source with ordinary command-line tools when appropriate
- querying installed tools or libraries
- builds
- tests
- formatting
- static analysis
- coverage
- version-control inspection
- other commands whose primary purpose is not rewriting repository source

If a native edit fails because the expected context no longer matches:

1. read the relevant portion of the file again
2. inspect its current contents
3. make a new targeted edit based on the current text

Do not fall back to a Python, shell, or text-processing rewrite merely because
a native edit failed once.

If a source modification is unusually large and cannot reasonably be made
with the available native editing tools, explain why before using a scripted
rewrite.


## Inspect Before Creating Bindings

Before adding or changing an OpenCV binding operation, inspect the
authoritative OpenCV declaration being wrapped.

When the declaration alone does not establish required behavior, inspect the
relevant authoritative OpenCV implementation or documentation.

Do not invent from memory:

- function signatures
- overload behavior
- ownership rules
- lifetime behavior
- default arguments
- template semantics
- continuity or storage assumptions
- exception semantics

Before designing the Ada API:

- understand the relevant OpenCV overload or template family
- inspect related existing shim functions
- inspect the existing public Ada abstraction
- check whether related functionality already exists
- determine which semantics must be preserved

Do not mechanically expose every C++ overload.

Design the Ada abstraction first, then expose only the C ABI necessary to
support it.

When OpenCV behavior is uncertain and materially affects the public API or
safety of the binding, inspect the authoritative source rather than guessing.


## Authoritative External Source Inspection

When inspecting authoritative upstream source or documentation, prefer native
Cline Web Fetch, MCP, repository browsing, or other available retrieval tools.

Do not launch Python or another scripting language merely to:

- download a web page
- fetch a raw GitHub file
- search downloaded source text
- extract a few relevant lines from remote source
- query public documentation

For OpenCV research, prefer this order when practical:

1. inspect the OpenCV headers and source installed in the current development
   environment when the exact installed behavior matters
2. use native repository, Web Fetch, or MCP tools to inspect authoritative
   OpenCV source for the exact version or tag being targeted
3. use ordinary terminal commands only when the required information is not
   reasonably accessible through native tools

When inspecting upstream OpenCV online, use an exact version or tag when the
feature depends on version-specific behavior.

Do not use a Python `urllib`, `requests`, or similar script merely as a
substitute for native Web Fetch or repository inspection.

Do not download an entire upstream source file into a Python process merely to
search for a declaration or implementation that native search/retrieval tools
can inspect directly.

If a native retrieval tool fails:

1. inspect the failure
2. determine whether another native retrieval/search tool is appropriate
3. retry only when there is a meaningful reason
4. use a scripted network request only when native retrieval genuinely cannot
   accomplish the task

Do not treat a native retrieval failure as automatic permission to fall back
to a heredoc or temporary script.


## Vertical Feature Development

Implement bindings vertically, one coherent feature at a time.

Prefer this sequence:

1. inspect authoritative OpenCV semantics
2. design the public Ada abstraction
3. add only the C++ shim surface required by that abstraction
4. add or update the thin Ada interoperability binding
5. implement the thick Ada API
6. add focused AUnit tests
7. format and build affected code
8. run the affected tests
9. run GNATprove or coverage when appropriate
10. if `cpp/opencv_core_shim.cpp` changed, complete the validation-boundary review from `.clinerules/05-quality.md`

When that review applies, the feature summary must state either that no public semantic validation is duplicated in the C++ shim, or list every retained duplicate and its ABI-safety reason.

Do not batch large numbers of unrelated C++ wrapper functions before the Ada
API that requires them exists.

Do not generate broad wrapper coverage speculatively.

A feature is not complete merely because the C++ shim compiles.

Prefer one integrated, tested binding over many partially implemented
declarations.

Keep each feature small enough that its:

- public API
- ABI behavior
- ownership
- validation
- exception handling
- tests

can be reviewed together.


## Use Project Skills

Use the repository's Cline skills when their subject is relevant.

Available Ada development skills include:

- Alire
- GNATprove
- GNATdoc
- GNATtest
- GNATfuzz

Use skills for detailed tool behavior rather than duplicating their generic
instructions in project rules.

Project-specific architecture, dependency ownership, test layout, and ABI
rules in `.clinerules` take precedence over generic examples in a skill.


## Architectural Decisions

Do not silently make significant public API or architecture decisions when
multiple reasonable designs exist.

Ask for direction before choosing among materially different designs that
would affect:

- public package hierarchy
- public type names
- ownership semantics
- shallow-copy versus deep-copy behavior
- tagged-type inheritance
- generic package structure
- exception model
- ABI compatibility
- Ada versus C++ responsibility
- dependency placement
- compatibility aliases that may become public API

When asking for such a decision:

- identify the exact decision
- present the main reasonable options
- recommend one
- explain the important tradeoff

Do not block on ordinary implementation details that already follow clearly
from established repository rules.