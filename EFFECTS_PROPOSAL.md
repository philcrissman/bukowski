# Algebraic Effects and Handlers for Bukowski

## Executive Summary

This proposal outlines a design for adding algebraic effects and handlers to bukowski, a lambda calculus-based language with SK combinator evaluation. The design draws from Eff, Koka, and OCaml 5, adapted for bukowski's minimalist, untyped lambda calculus foundation.

**Key Design Decisions:**
- **Syntax**: ML-style `handle...with` blocks, similar to Eff/OCaml
- **Semantics**: Multi-shot delimited continuations (more expressive than one-shot)
- **Implementation**: Continuation-based, using explicit stack reification
- **Type System**: None (untyped like base lambda calculus), runtime effect dispatch
- **Evaluation**: Effects bypass SK translation, handled directly in evaluator

---

## 1. Background: What Are Algebraic Effects?

### Conceptual Foundation

Algebraic effects separate **effect operations** (what you want to do) from **effect handlers** (how to do it). Think of them as:
- **Operations** = "throw an exception" or "read from stdin"
- **Handlers** = "catch exceptions and recover" or "simulate stdin from a string"

This is a generalization of exception handling:
- Exceptions: one operation (`raise`), handler can't resume
- Effects: many operations, handlers can resume, ignore, or call continuation multiple times

### Key Concepts

1. **Effects**: Abstract operations like `Get`, `Put`, `Read`, `Write`
2. **Perform**: Triggers an effect operation (like `throw` for exceptions)
3. **Handlers**: Pattern match on effects and decide what to do
4. **Continuations**: Represent "the rest of the computation" after an effect
5. **Resume**: Continue execution with a value (handler decides whether/how many times)

### Relationship to Lambda Calculus

Algebraic effects extend lambda calculus with:
- A `perform` primitive for invoking operations
- A `handle...with` construct for installing handlers
- Delimited continuations (like `shift`/`reset`) for capturing the evaluation context

---

## 2. Survey of Existing Languages

### Eff (Research Language)

**Syntax:**
```eff
operation Get : unit -> int
operation Put : int -> unit

let counter () =
  let x = perform Get in
  perform (Put (x + 1));
  x

let result =
  handle counter () with
  | val x -> x
  | #Get () k -> k 0 0
  | #Put n k -> k () n
```

**Characteristics:**
- Multi-shot continuations (can call `k` multiple times)
- Dynamic handler lookup (searches stack at runtime)
- Effect types tracked statically
- Pattern matching on operations in handlers
- `val` clause handles normal return

### Koka (Microsoft Research)

**Syntax:**
```koka
effect state<a> {
  fun get() : a
  fun set(x: a) : ()
}

fun counter() : <state<int>> int {
  val x = get()
  set(x + 1)
  x
}

fun runState(init, action) {
  var st := init
  handle(action) {
    get() -> resume(st, st)
    set(x) -> { st := x; resume((), st) }
  }
}
```

**Characteristics:**
- **Evidence passing**: Handlers passed as implicit parameters (O(1) dispatch)
- Row-polymorphic effect types (`<state<int>>`)
- Compiles to C, no GC needed
- Single-shot continuations (implied by compilation strategy)
- Most performant implementation

### OCaml 5 (Production Language)

**Syntax:**
```ocaml
effect Get : int
effect Put : int -> unit

let counter () =
  let x = perform Get in
  perform (Put (x + 1));
  x

let result =
  try counter () with
  | effect Get k -> continue k 0
  | effect (Put n) k -> continue k ()
```

**Characteristics:**
- One-shot continuations (runtime error if resumed twice)
- No effect types (untyped effects, checked at runtime)
- Dynamic lookup (exception-like stack search)
- Fibers (heap-allocated stack chunks) for efficiency
- Retrofitted onto existing language

### Comparison Table

| Feature | Eff | Koka | OCaml 5 | **Bukowski Proposal** |
|---------|-----|------|---------|----------------------|
| Effect Types | Yes | Yes (row-polymorphic) | No | **No (untyped)** |
| Continuations | Multi-shot | Single-shot | One-shot | **Multi-shot** |
| Lookup | Dynamic | Static (evidence) | Dynamic | **Dynamic** |
| Syntax | `handle...with` | `handle{...}` | `try...with effect` | **`handle...with`** |
| Resume Keyword | `k` (implicit) | `resume` | `continue` | **`resume`** |
| Performance | Moderate | High (C compilation) | High (fibers) | **Moderate (pure Ruby)** |

---

## 3. Proposed Syntax for Bukowski

### 3.1 Core Constructs

**Effect Declaration (Optional, Documentation Only):**
```scheme
# Effects are just symbols, no declaration needed
# But we can document them:

# effect State =
#   Get : unit -> int
#   Put : int -> unit
```

**Performing Effects:**
```scheme
perform Get           # Perform effect with no argument
perform (Put 42)      # Perform effect with argument
```

**Handler Definition:**
```scheme
handle EXPR with {
  | Get resume -> resume 0
  | Put n resume -> resume ()
  | return x -> x
}
```

### 3.2 Detailed Syntax

```
EXPR ::= ...existing lambda calculus...
       | perform EFFECT              # Perform effect
       | handle EXPR with HANDLER    # Install handler

HANDLER ::= { CLAUSE* }

CLAUSE ::= | return VAR -> EXPR          # Normal return
         | | EFFECT VAR* resume -> EXPR  # Effect clause

EFFECT ::= VAR                           # Effect name (e.g., Get)
         | ( VAR EXPR* )                 # Effect with args (e.g., Put 42)
```

**Syntax Notes:**
- `return` clause handles normal (non-effectful) completion
- Each effect clause binds the effect name, its arguments, and `resume` (the continuation)
- `resume` is a function that takes the result value and continues execution
- If an effect isn't handled, it propagates to the next outer handler

### 3.3 Example: State Effect

```scheme
# Define a counter using state effects
let counter = λ_.
  let x = perform Get in
  perform (Put (+ x 1))
in

# Run with a state handler
handle counter () with {
  | return x -> x
  | Get resume ->
      let state = 0 in
      resume state
  | Put n resume ->
      resume ()
}
```

### 3.4 Example: Nondeterminism (Choice)

```scheme
# Choose between multiple values
let choose_both =
  let x = perform (Choose 10 20) in
  let y = perform (Choose 1 2) in
  + x y
in

# Handler that explores all branches
handle choose_both with {
  | return x -> [x]                    # Wrap result in list
  | Choose a b resume ->
      let left = resume a in
      let right = resume b in
      concat left right                # Combine both branches
}
# Result: [11, 12, 21, 22]
```

### 3.5 Example: Exceptions

```scheme
let safe_divide = λx.λy.
  if (= y 0)
    (perform (Raise "division by zero"))
    (/ x y)
in

handle (safe_divide 10 0) with {
  | return x -> x
  | Raise msg resume ->
      "Error"                          # Don't call resume - abort!
}
```

### 3.6 Example: IO Effects

```scheme
let program =
  perform (Print "What's your name?")
  let name = perform Read in
  perform (Print (concat "Hello, " name))
in

# Pure handler (simulate IO)
handle program with {
  | return x -> x
  | Print msg resume -> resume ()
  | Read resume -> resume "Alice"
}

# Real handler (actual IO) - provided by runtime
handle program with {
  | return x -> x
  | Print msg resume ->
      __builtin_print msg   # Runtime primitive
      resume ()
  | Read resume ->
      let input = __builtin_read in
      resume input
}
```

---

## 4. Semantics and Implementation

### 4.1 Operational Semantics

Algebraic effects are essentially **delimited continuations** with structured labels. We can define them in terms of `shift`/`reset` or `prompt`/`control`.

**Desugaring to Delimited Continuations:**

```scheme
# This effect expression:
handle EXPR with {
  | return x -> RETURN_EXPR
  | Effect arg resume -> HANDLER_EXPR
}

# Desugars roughly to:
reset (
  let return = λx.RETURN_EXPR in
  let result = EXPR in
  return result
)

# Where 'perform Effect' becomes:
shift k. (HANDLER_EXPR with resume=k)
```

**Formal Evaluation Rule (Simplified):**

```
E = evaluation context (the "hole" in the expression)

E[perform op(v)] with handler h
  → h.op(v, λx. E[x])

If h handles op:
  apply h's handler clause with continuation λx. E[x]

If h doesn't handle op:
  propagate to next outer handler
```

### 4.2 Implementation Strategy

**Option A: Explicit Continuation Passing**

Transform effectful code to CPS during evaluation:
- Every expression takes an extra continuation argument
- `perform` captures the current continuation and invokes handler
- Handlers receive the continuation and decide whether to call it

**Pros:**
- Direct implementation, conceptually clear
- Full control over continuation behavior
- Easy to implement multi-shot continuations

**Cons:**
- Performance overhead (everything becomes CPS)
- Complicates normal evaluation path

**Option B: Stack Reification (Recommended)**

Maintain an explicit handler stack during evaluation:
- Evaluator tracks installed handlers
- `perform` searches handler stack for matching effect
- Capture continuation by reifying current evaluation context
- Resume by restoring context with new value

**Pros:**
- Normal code runs at normal speed (no CPS overhead)
- Only effectful code pays the continuation cost
- Easier integration with existing evaluator

**Cons:**
- Requires careful stack management
- More complex implementation

**Option C: Defunctionalization + Trampoline**

Defunctionalize the continuation type:
- Represent continuations as data structures
- Use trampolining to avoid Ruby stack overflow
- Handlers manipulate continuation data structures

**Pros:**
- No Ruby stack limits
- Can serialize/inspect continuations
- Clean separation of concerns

**Cons:**
- More implementation complexity
- Requires full evaluator rewrite

### 4.3 Recommended Implementation: Stack Reification

```ruby
class Evaluator
  def initialize
    @handler_stack = []  # Stack of installed handlers
  end

  def evaluate(expr, env = {})
    case expr
    when Handle
      # Install handler and evaluate body
      handler = Handler.new(expr.clauses)
      @handler_stack.push(handler)
      begin
        result = evaluate(expr.body, env)
        # Normal return - apply 'return' clause
        apply_return_clause(handler, result)
      ensure
        @handler_stack.pop
      end

    when Perform
      # Search handler stack for matching effect
      effect_name = expr.effect_name
      effect_args = expr.args.map { |a| evaluate(a, env) }

      handler_idx = @handler_stack.rindex { |h| h.handles?(effect_name) }
      raise "Unhandled effect: #{effect_name}" unless handler_idx

      handler = @handler_stack[handler_idx]

      # Capture continuation
      continuation = Continuation.new(
        handler_stack: @handler_stack[handler_idx+1..-1],
        env: env
      )

      # Apply handler clause
      handler.apply_effect_clause(effect_name, effect_args, continuation)

    when ...existing cases...
    end
  end
end

class Continuation
  def call(value)
    # Resume computation with value
    # Restore handler stack and environment
    # Return value to the point where perform was called
  end
end
```

### 4.4 AST Extensions

```ruby
# New AST nodes
Handle = Struct.new(:body, :clauses) do
  def to_s
    "handle #{body} with { #{clauses.join('; ')} }"
  end
end

HandlerClause = Struct.new(:pattern, :body) do
  # pattern can be:
  # - ReturnPattern(var)
  # - EffectPattern(effect_name, args, resume_var)
end

Perform = Struct.new(:effect_name, :args) do
  def to_s
    if args.empty?
      "perform #{effect_name}"
    else
      "perform (#{effect_name} #{args.join(' ')})"
    end
  end
end
```

---

## 5. Translation to SK Combinators

### 5.1 The Challenge

Algebraic effects fundamentally require:
- Stack introspection (to find handlers)
- Context capture (to create continuations)
- Non-local control flow (to resume at arbitrary points)

SK combinators provide:
- Pure term rewriting
- No notion of "stack" or "context"
- Strictly local reduction rules

**Conclusion:** Direct translation of effects to SK is **impractical**.

### 5.2 Proposed Approach: Dual Evaluation Paths

```
┌─────────────────┐
│   Source Code   │
└────────┬────────┘
         │
    ┌────▼────────────────┐
    │  Tokenizer/Parser   │
    └────┬────────────────┘
         │
    ┌────▼──────┐
    │ Lambda AST │
    └────┬───────┘
         │
         │  Has Effects?
         ├─── No ───► SK Translator ───► SK Reducer (fast)
         │
         └─── Yes ──► Effect Evaluator (direct LC evaluation)
                      (with handler stack & continuations)
```

**Rationale:**
- Pure lambda calculus code → SK translation (fast, current path)
- Code with effects → Direct LC evaluation (necessary for effects)
- This is pragmatic: effects are for I/O and control flow where performance is less critical

### 5.3 Alternative: CPS Translation to SK

We *could* CPS-transform effectful code and translate that to SK:

```scheme
# Original:
let x = perform Get in + x 1

# CPS transform:
λk. perform_cps Get (λx. k (+ x 1))

# SK translation:
... complex SK combinators ...
```

**Problems:**
- Enormous code explosion (CPS + SK = very large terms)
- Handler lookup still needs runtime support
- Multi-shot continuations need sophisticated memory management
- Not worth the complexity for bukowski's goals

### 5.4 Hybrid Approach: Effect Primitives in SK

Add effect operations as **primitives** in SK (like `+`, `-`):

```ruby
SKPerform = Struct.new(:effect_name, :args)  # Primitive operation
SKHandle = Struct.new(:body, :handler)       # Special form

# SK reducer handles these specially:
when SKPerform
  # Search handler stack, capture continuation as SK term
  # This is still complex but avoids full CPS
```

This is feasible but significantly complicates SK reducer. Recommended only if SK performance is critical for effectful code (unlikely).

---

## 6. Detailed Implementation Plan

### Phase 1: Core Effect Infrastructure (Week 1)

**Goals:**
- Add AST nodes: `Handle`, `Perform`, `HandlerClause`
- Implement basic handler stack in evaluator
- Support simple return clause

**Deliverables:**
```ruby
# Can parse and handle:
handle 42 with { | return x -> + x 1 }
# Result: 43
```

**Tasks:**
1. Extend tokenizer for `handle`, `with`, `perform`, `resume`, `return`
2. Add parser methods: `parse_handle`, `parse_handler_clauses`
3. Add AST nodes to `parser.rb`
4. Extend `Evaluator` with `@handler_stack` field
5. Implement `Handle` evaluation with return clause only
6. Write tests for basic handling

### Phase 2: Simple Effects (Week 2)

**Goals:**
- Implement `perform`
- Support effect clauses with one-shot continuations
- Handler lookup and dispatch

**Deliverables:**
```ruby
# Can handle simple effects:
handle (perform Get) with {
  | Get resume -> resume 42
  | return x -> x
}
# Result: 42
```

**Tasks:**
1. Implement `Perform` evaluation in evaluator
2. Implement handler lookup (search stack)
3. Implement continuation capture (initially simple: closure over env)
4. Implement continuation resume (call with value)
5. Support effect clauses with arguments
6. Write tests: Get/Put, exceptions, simple state

### Phase 3: Multi-Shot Continuations (Week 3)

**Goals:**
- Allow handlers to call `resume` multiple times
- Enable choice/nondeterminism patterns

**Deliverables:**
```ruby
# Can explore multiple branches:
handle (perform (Choose 1 2)) with {
  | Choose a b resume ->
      let left = resume a in
      let right = resume b in
      pair left right
  | return x -> x
}
# Result: (1, 2)
```

**Tasks:**
1. Refine continuation representation (must be reusable)
2. Implement multi-shot continuation semantics
3. Handle interactions between nested effects
4. Write tests: choice, backtracking, probabilistic programs

### Phase 4: Effect Composition (Week 4)

**Goals:**
- Multiple handlers in scope
- Handler nesting and effect propagation
- Unhandled effect errors

**Deliverables:**
```ruby
# Nested handlers:
handle (
  handle (perform Inner) with {
    | Inner resume -> perform Outer
  }
) with {
  | Outer resume -> resume 42
  | return x -> x
}
# Result: 42
```

**Tasks:**
1. Implement handler stack search correctly
2. Support effect propagation through handlers
3. Add proper error messages for unhandled effects
4. Write tests: nested handlers, multiple effects

### Phase 5: Standard Library (Week 5-6)

**Goals:**
- Implement common effect handlers
- Real I/O effects
- Documentation and examples

**Deliverables:**
- `stdlib/state.ski` - State effect handlers
- `stdlib/io.ski` - I/O effect handlers (backed by Ruby)
- `stdlib/async.ski` - Cooperative multitasking
- `stdlib/exn.ski` - Exception helpers
- Example programs demonstrating each

**Tasks:**
1. Design standard effect signatures
2. Implement handlers in .ski files
3. Add runtime primitives for real I/O (`__builtin_print`, etc.)
4. Write example programs
5. Add REPL commands for loading stdlib

---

## 7. Examples and Use Cases

### 7.1 State

```scheme
# Counter with state
let counter = λinit.
  let loop = λn.
    if (> n 0) (
      let curr = perform Get in
      perform (Put (+ curr 1))
      loop (- n 1)
    ) ()
  in
  loop init
in

handle (counter 10) with {
  | return x -> perform Get  # Return final state
  | Get resume ->
      (λstate. resume state state)  # Pass state explicitly
  | Put newState resume ->
      (λstate. resume () newState)
}
# Applied to initial state: 0
# Result: 10
```

### 7.2 Async/Await

```scheme
effect Async =
  Await : promise -> value
  Yield : unit -> unit

# Cooperative scheduler
let scheduler = λtasks.
  let queue = make_queue tasks in
  let rec run = λ_.
    if (queue_empty queue)
      "done"
      (let task = queue_pop queue in
       handle task with {
         | return x -> run ()
         | Yield resume ->
             queue_push queue resume
             run ()
         | Await promise resume ->
             # Simplified: assume promise ready
             resume (promise_value promise)
       })
  in run ()
```

### 7.3 Transactions (Rollback)

```scheme
effect Transaction =
  Abort : string -> empty
  Checkpoint : unit -> unit

handle (
  let x = perform Get in
  if (> x 100)
    (perform (Abort "value too large"))
    (perform (Put (* x 2)))
) with {
  | return x -> x
  | Abort msg resume ->
      # Don't resume - rollback instead
      "Transaction aborted"
  | Get resume ->
      (λstate. λbackup.
         resume state state backup)
  | Put newState resume ->
      (λstate. λbackup.
         resume () newState backup)
  | Checkpoint resume ->
      (λstate. λbackup.
         resume () state state)  # Save checkpoint
}
```

### 7.4 Logging (Telemetry)

```scheme
effect Log =
  Debug : string -> unit
  Info : string -> unit

handle (
  perform (Info "Starting computation")
  let x = + 1 2 in
  perform (Debug (concat "x = " (show x)))
  * x 10
) with {
  | return x -> x
  | Debug msg resume ->
      # In production: ignore debug logs
      resume ()
  | Info msg resume ->
      perform (Print msg)  # Delegate to outer IO handler
      resume ()
}
```

---

## 8. Design Rationale

### 8.1 Why Multi-Shot Continuations?

**Decision:** Support multi-shot (reusable) continuations

**Rationale:**
- More expressive (choice, backtracking, probabilistic programming)
- Matches Eff's design philosophy
- Can emulate one-shot by not calling resume multiple times
- Educational value: demonstrates full power of delimited continuations

**Trade-off:**
- Slightly more complex implementation
- Must ensure continuation environment is properly copied/isolated
- But: worth it for expressiveness

### 8.2 Why No Effect Types?

**Decision:** No static effect types (untyped like base lambda calculus)

**Rationale:**
- Bukowski is untyped - adding effect types would require adding types generally
- Simpler implementation (no type inference, row polymorphism, etc.)
- Consistent with "minimal lambda calculus" philosophy
- Runtime errors for unhandled effects are acceptable for this language

**Trade-off:**
- Less safety (errors caught at runtime not compile-time)
- But: matches existing bukowski design philosophy

### 8.3 Why Direct Evaluation for Effects?

**Decision:** Effects bypass SK translation, use direct LC evaluator

**Rationale:**
- SK translation of effects is impractical (see Section 5)
- Effect-heavy code (I/O, async) is not performance-critical
- Pure code still gets SK optimization
- Pragmatic compromise for a research language

**Trade-off:**
- Two evaluation paths (complexity)
- But: necessary for effects, and orthogonal paths are clean

### 8.4 Syntax Design

**Decision:** ML-style `handle...with` similar to Eff/OCaml

**Rationale:**
- Familiar to FP programmers
- Clear separation of body and handler clauses
- Pattern matching syntax is natural
- `resume` is more readable than `k` or `continue`

**Alternative considered:**
- Scheme-style `(handle EXPR (CLAUSES...))` - too verbose
- Keyword `effect` before each clause - redundant

---

## 9. Open Questions and Future Work

### 9.1 Effect Polymorphism

**Question:** How to write handlers that are polymorphic over effects?

**Example:**
```scheme
# Handler that logs all effects:
handle EXPR with {
  | ANY_EFFECT args resume ->
      perform (Log effect_name)
      resume (default_value)
}
```

**Options:**
- Wildcard pattern `| _ resume -> ...` catches all unhandled effects
- Special pattern `| effect name args resume -> ...` binds effect name dynamically

**Recommendation:** Add wildcard pattern in Phase 4

### 9.2 Effect Scoping

**Question:** Should handlers scope lexically or dynamically?

**Example:**
```scheme
let foo = λ_.
  perform Get  # Which handler handles this?
in

let bar = λ_.
  handle (foo ()) with {
    | Get resume -> resume 1
  }
in

handle (foo ()) with {  # Does this handle Get from foo?
  | Get resume -> resume 2
}
```

**Current proposal:** Dynamic scoping (search stack at runtime)

**Rationale:**
- Matches Eff, OCaml, most effect systems
- More flexible (can change handlers without rewriting code)
- Simpler implementation

**Alternative:** Lexical scoping (pass handlers as implicit parameters)
- Matches Koka's evidence passing
- Better performance (static dispatch)
- But: much more complex implementation

### 9.3 Optimizations

**Future work:**
- Effect analysis: detect pure code and use SK path automatically
- Handler inlining: inline simple handlers to avoid continuation overhead
- Continuation pooling: reuse continuation objects to reduce allocation

### 9.4 Debugging Support

**Future work:**
- Effect trace: log all performed effects and handler applications
- Continuation inspection: print captured continuations
- Step-through debugger for effect handling

---

## 10. Conclusion

This proposal outlines a **practical, expressive effect system** for bukowski that:

✅ **Fits the language**: Minimal syntax, consistent with lambda calculus foundation
✅ **Draws from best practices**: Eff semantics, OCaml pragmatism, Koka insights
✅ **Is implementable**: Phased plan with clear milestones
✅ **Enables powerful patterns**: State, async, exceptions, transactions, logging, choice, etc.
✅ **Maintains performance**: Pure code still uses fast SK path

**Recommended next steps:**
1. Review and refine this proposal
2. Build Phase 1 prototype (core infrastructure)
3. Validate with simple examples
4. Iterate on design based on experience
5. Complete remaining phases

**Timeline estimate:** 6 weeks for full implementation + standard library

---

## Appendix A: Complete Grammar Extension

```
# Existing Lambda Calculus Grammar
EXPR ::= VAR                          # Variable
       | NUM                          # Number
       | STR                          # String
       | λ VAR . EXPR                 # Abstraction
       | EXPR EXPR                    # Application
       | let VAR = EXPR in EXPR      # Let binding
       | ( EXPR )                     # Grouping

# Effect Extension
EXPR ::= ...
       | perform EFFECT               # Perform effect
       | handle EXPR with { CLAUSE* } # Handle effects

EFFECT ::= VAR                        # Simple effect (e.g., Get)
         | ( VAR EXPR* )              # Effect with args (e.g., Put 42)

CLAUSE ::= | return VAR -> EXPR       # Normal return clause
         | | EFFECT_PAT resume -> EXPR # Effect handling clause

EFFECT_PAT ::= VAR                    # Simple effect pattern
             | VAR VAR*               # Effect with argument patterns
```

## Appendix B: Implementation Checklist

### Tokenizer
- [ ] Add tokens: `HANDLE`, `WITH`, `PERFORM`, `RESUME`, `RETURN`, `PIPE`
- [ ] Handle `|` as separator in handler clauses
- [ ] Add `{` and `}` for handler blocks (or reuse existing braces)

### Parser
- [ ] Add AST nodes: `Handle`, `Perform`, `HandlerClause`
- [ ] Implement `parse_handle` method
- [ ] Implement `parse_handler_clauses` method
- [ ] Implement `parse_effect_pattern` method
- [ ] Update `parse_expr` to handle `perform` and `handle`

### Evaluator
- [ ] Add `@handler_stack` instance variable
- [ ] Implement `Handle` evaluation (push handler, evaluate, pop handler)
- [ ] Implement `Perform` evaluation (search stack, capture continuation)
- [ ] Implement `Continuation` class
- [ ] Implement handler clause application
- [ ] Implement return clause handling
- [ ] Add error handling for unhandled effects

### Tests
- [ ] Basic handler with return clause only
- [ ] Simple effect (Get/Put)
- [ ] Effect with arguments
- [ ] Nested handlers
- [ ] Effect propagation
- [ ] Multi-shot continuations
- [ ] Unhandled effect errors
- [ ] Complex examples (state, choice, exceptions)

### Documentation
- [ ] Tutorial on using effects
- [ ] Standard library documentation
- [ ] Performance considerations
- [ ] Migration guide for existing code

## Appendix C: References

1. **Plotkin & Pretnar (2009)**: "Handlers of Algebraic Effects"
2. **Bauer & Pretnar (2015)**: "Programming with Algebraic Effects and Handlers"
3. **Leijen (2017)**: "Type Directed Compilation of Row-Typed Algebraic Effects"
4. **Sivaramakrishnan et al. (2021)**: "Retrofitting Effect Handlers onto OCaml"
5. **Hillerström & Lindley (2016)**: "Liberating Effects with Rows and Handlers"
6. **Kammar et al. (2013)**: "Handlers in Action"
7. **Kiselyov et al. (2013)**: "Extensible Effects: An Alternative to Monad Transformers"

**Online Resources:**
- Eff language: https://www.eff-lang.org
- Koka language: https://koka-lang.github.io
- OCaml effects tutorial: https://github.com/ocaml-multicore/ocaml-effects-tutorial
- Algebraic Effects for the Rest of Us: https://overreacted.io/algebraic-effects-for-the-rest-of-us/
