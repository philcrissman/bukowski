# Lazy Stream IO for Bukowski

## Design Philosophy

Bukowski is a lazy lambda calculus language evaluated via SKI combinators.
Side effects don't belong in the language itself — the language is pure.
Instead, IO happens at the boundary: the Ruby runtime drives lazy streams
that the bukowski program produces and consumes.

This is the same model Miranda and early Haskell (pre-monadic IO) used.
A program is a pure function from inputs to outputs. The runtime is the
only thing that touches the outside world.

## Core Model

A bukowski program with IO is a function:

```
program : [Request] -> [Response]
```

Or more concretely for interactive use:

```
program : [String] -> [String]
```

The runtime:
1. Begins reducing the output list (lazily)
2. When it encounters an output string, prints it
3. When the program demands an element from the input list, the runtime
   reads a line from stdin and feeds it in
4. Repeats until the output list is exhausted (nil)

Because evaluation is lazy, the program only computes as much of the
output as the runtime asks for, and only demands as much input as it
needs to produce the next output.

## Example: Echo Program

```
# Echo: read a line, print it back, repeat forever
define echo \input.
  cons (head input) (echo (tail input))

echo
```

The runtime would:
1. Start reducing `echo input` — it's `cons (head input) (echo (tail input))`
2. To print the head, it needs `head input` — so it reads a line from stdin
3. Prints that line to stdout
4. Moves to the tail: `echo (tail input)` — another cons, another read, etc.

## Example: Greeting Program

```
define greet \input.
  cons "What is your name?"
    (cons (+ "Hello, " (head input))
      {})

greet
```

The runtime:
1. Reduces — first element is `"What is your name?"`, prints it immediately (no input needed)
2. Second element is `+ "Hello, " (head input)` — needs input, reads a line
3. Prints `"Hello, Alice"` (or whatever was typed)
4. Tail is `{}` (nil) — program ends

## Implementation Plan

### Phase 1: Basic Stream IO Runner

**Goal:** Run a bukowski program that takes `[String] -> [String]` and
drive it interactively from the Ruby runtime.

**Changes:**

- Add a `StreamRunner` class (Ruby side) that:
  - Represents stdin as a lazy SKCons list (each element read on demand)
  - Reduces the program applied to this input list
  - Walks the output list, printing each element as it's produced
  - Stops when it hits SKNil

- Lazy input list: the key trick. The input stream is an SKCons whose
  head is an `SKLazy` thunk — a new SK node type that, when forced
  (reduced), calls back into Ruby to read from stdin. Each read produces
  the next cons cell with another lazy head.

- Add a `--run` or `--io` flag to `bin/bukowski` that uses the
  StreamRunner instead of the REPL or batch evaluator.

**New SK node:**
```ruby
SKLazy = Struct.new(:thunk) do
  # thunk is a Ruby proc that returns an SK expression when called
end
```

The reducer, when it encounters an SKLazy in a position where it needs
a value, forces it (calls the thunk) and continues reducing.

**Files to modify:**
- `lib/bukowski/sk_ast.rb` — add SKLazy
- `lib/bukowski/sk_reducer.rb` — handle SKLazy (force on demand)
- `lib/bukowski/stream_runner.rb` — new file, drives IO
- `bin/bukowski` — add --io mode

### Phase 2: Request/Response Protocol

**Goal:** Support more than just string IO. Programs emit tagged requests
and the runtime interprets them.

**Model:**
```
# A Request is a tagged pair: {tag, payload}
# The runtime pattern-matches on the tag

define program \input.
  cons {Print "What is your name?"}
    (cons {Read}
      (cons {Print (+ "Hello, " (head input))}
        (cons {Exit 0}
          {})))
```

**Supported request tags:**
- `Print msg` — write msg to stdout
- `Read` — read a line from stdin (consumes next input element)
- `ReadFile path` — read file contents (next input element is file contents)
- `WriteFile path contents` — write to file
- `Exit code` — terminate with exit code

The runtime walks the output list, dispatches each request, and feeds
responses back through the input stream.

**Advantage:** The program is still a pure function — it just speaks a
richer protocol. The runtime is the interpreter of that protocol.

### Phase 3: Prelude IO Functions

**Goal:** Provide ergonomic wrappers in the prelude so users don't need
to manually construct request/response cons cells.

```
# In prelude.bk:
define print \msg.\cont.\input.
  cons {Print msg} (cont input)

define readline \cont.\input.
  cont (head input) (tail input)

# User code:
define main \input.
  print "What is your name?" (\input.
    readline (\name.\input.
      print (+ "Hello, " name) (\input.
        {}))) input
```

This is continuation-passing style at the user level — each IO action
takes a "what to do next" callback. Not as ergonomic as monadic or
effect-based IO, but honest and simple. The user sees exactly what's
happening.

### Phase 4: File Execution with IO

**Goal:** `bukowski program.ski` runs the program with IO enabled by
default when the top-level expression is a function (takes an argument).

**Heuristic:** If the program's result is a closure/lambda awaiting an
argument, assume it's an IO program and pass it the input stream. If
it's a value, just print it (current behavior).

## What This Gives Us

- **Interactive programs** — REPLs, command-line tools, text adventures
- **File IO** — read/write files through the request protocol
- **Composability** — IO programs are just functions, compose normally
- **Testability** — pass a mock input list, check the output list
- **Purity** — the bukowski program never touches the outside world
- **Laziness preserved** — lazy streams are the natural IO idiom for a lazy language
- **SKI preserved** — no new evaluation model needed, just one new lazy node type

## What This Doesn't Give Us

- **Interleaved effects** — can't mix state, IO, and exceptions elegantly
- **Concurrency** — no coroutines or async
- **Nondeterminism** — no backtracking search
- **Error recovery** — errors are Ruby-level raises, not catchable in bukowski

These are acceptable tradeoffs for a language whose purpose is exploring
lambda calculus and SKI combinators, not building production systems.

## References

- Turner, D.A. "Miranda: A Non-Strict Functional Language with Polymorphic Types" (1985)
- Peyton Jones, S. "The Implementation of Functional Programming Languages" (1987), Ch. 7: stream-based IO
- Hudak, P. & Sundaresh, R. "On the Expressiveness of Purely Functional I/O Systems" (1989)
