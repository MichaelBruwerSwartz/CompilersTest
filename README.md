# SIMPL tests

150 hand-written SIMPL programs for RW745 assignment 3, with the output my
checker gives for each one recorded beside it.

## File structure

Clone it beside your `src/`, so the runner can find your grammars:

```bash
git clone https://github.com/MichaelBruwerSwartz/CompilersTest.git test
```

```
your-project/
├── src/              your .g4 grammars and .java classes
│   ├── simplLexer.g4 whatever your "grammar X;" lines name them
│   ├── simplParser.g4
│   └── simpl.java    the driver class
└── test/             <- this repository, cloned or unzipped here
    ├── run.sh        the runner
    ├── Dockerfile    the same runner, for anyone without a JDK to hand
    ├── compose.yaml
    ├── README.md     this file
    ├── valid/        30 programs
    ├── scope/        28 programs
    ├── type/         38 programs
    ├── syntax/       18 programs
    ├── corners/      36 programs
    ├── naidoo/       a folder someone else contributed, named after them
    └── build/        generated and compiled output, made on the first run
```

## Running

You need a JDK and the ANTLR jar, which you have already, and nothing else. Put
the jar wherever you keep it — beside your grammars in `src/`, in here, at the
top of the project, in `~/antlr` or in `~` — and the runner takes the first
`antlr*.jar` it finds in those places. It says which one it used when it builds.

```bash
./test/run.sh                every test, one line each
./test/run.sh type scope     only those groups
./test/run.sh -c             remove test/build/
```

It generates every `.g4` it finds, whether that is a split lexer and parser or
one combined grammar, and compiles every `.java` beside them. `SRC=path` if your
sources are not in `src/`, `ANTLR_JAR=path` if the jar is somewhere else again,
`MAIN=name` if your driver class is not called `simpl`.

The `syntax/` group records ANTLR's own parser messages verbatim, and those get
reworded between releases, so a jar that is not 4.13.2 may differ there. The
wording is printed beneath the failure, to be read.

## In a container, if you would rather not install anything

`Dockerfile` is the same runner with a JDK and the 4.13.2 jar supplied, which
also settles the `syntax/` wording above. Your sources are mounted read-only,
and nothing of yours is written to.

```bash
docker build -t simpl-tests test/
docker run --rm -v "$PWD/src:/work/src:ro" simpl-tests             # every test
docker run --rm -v "$PWD/src:/work/src:ro" simpl-tests type scope  # only those groups
docker compose run --rm tests                                      # from inside test/
```

Say `-e MAIN=name` if your driver class is not called `simpl`.

## Reading the result

Every one of the 150 programs has a `NAME.expected` beside it holding, verbatim,
what my checker writes to the standard error channel; an empty one means the
program must draw no message at all.

What is compared is **which messages come out**, not the order they come out in:

- **`PASS`** — byte for byte the same.
- **`ORDER`** — every message is there, spelled the same and at the same
  position, in another order. Counted as passing and it does not fail the run:
  whether scope and type messages merge into one source order or stay grouped by
  pass is not fixed by the assignment.
- **`FAIL`** — a message is missing, extra, spelled differently or at another
  position. It prints mine and yours, to be read: these files hold my wording and
  my positions, so a `FAIL` may be a difference of convention rather than a
  mistake — see *Reds and fixes* below.

The run exits non-zero only when something is `FAIL`.

## What the recorded output assumes

Three things have to agree before a byte comparison means anything, and none of
them is fixed by the assignment beyond doubt. If you chose differently, the
messages are still the right ones — the diff is telling you about a convention,
not a bug.

**The format is ANTLR's own**, for syntax, scope and type messages alike:

```
line <line>:<column> <message>
```

**Lines and columns both count from 1.** Both documents say "the first
character" throughout, which is prose about a source file rather than an array
index, and a 1-based line beside ANTLR's 0-based column reads as an off-by-one.
ANTLR's column is shifted once, where the message is recorded, so every message
counts alike. If yours counts columns from 0, every position here is one to the
left of yours.

**The text is verbatim from §5.3 of the language specification**, and so is the
position each message is blamed on, construct by construct — a bad operand on
the operator, an argument on the argument, the value assigned on the right-hand
side of the `<-`.

## The order messages come out in, and which one wins

One sorted list, top to bottom:

1. **Syntax errors stop everything.** If the parse reported anything, neither
   checker runs and only the syntax messages print. ANTLR's recovery invents
   tokens and drops subtrees, so checking a recovered tree reports mistakes the
   programmer did not make.
2. **Every other message goes into one list, sorted by line, then by column** —
   whichever pass found it. A type error on line 11 prints before a scope error
   on line 12. Note 6 also reads as each checker in its own source order, so
   grouped output is a defensible answer to the same sentence: where that is the
   only difference the runner says `ORDER` rather than `FAIL`.
3. **On the same position, scope beats type.** The scope pass runs first and the
   sort is stable, so `unknown identifier` and `multiple definition` print ahead
   of any type message on the same token, which is the precedence §5.3.13 asks
   for.
4. **One message per construct.** A check that failed yields *unknown*, and
   every check passes over *unknown* in silence, so `while b + 1 do` reports the
   operand of `+` and not the guard as well; a binary operator checks its left
   operand, then its right, and stops at the first that is wrong. §5.3.15 asks
   for this — "the more specific error from the previous subsections must be
   preferred".
5. **An undeclared name draws scope messages only.** A name the scope pass could
   not resolve is typed *unknown*, so the type pass says nothing about it at all.

## Reds and fixes

Most reds are one of these, and none of them means the checker is wrong:

| The red you see | What it is | The fix |
|---|---|---|
| every position off by one, `line 8:11` against my `line 8:12` | you count columns from 0, as ANTLR hands them; these files count from 1 | shift the column once where the message is recorded, not where it is printed, so sorting and printing agree — or take 0 and read the diff as a constant |
| `ORDER` on a program with both kinds of message | you group by pass, I merge into one source order | nothing to fix, it passes; merge if you would rather match byte for byte |
| `for operator +` against my `for operator '+'` | the specification's template has no quotes around ⟨op⟩, but quotes ⟨id⟩; I quote both | either reading is defensible; pick one and keep it in all three sites |
| two messages where I have one, on one broken construct | your failed check yields a real type instead of *unknown* | yield *unknown* from a check that failed, and let every check pass over *unknown* in silence (§5.3.15 prefers the more specific error) |
| type messages about an undeclared name | your type pass runs on names the scope pass could not resolve | type undeclared names *unknown*, so only the scope pass speaks about them |
| whole of `syntax/` differs in wording | a different ANTLR release, whose parser messages read differently | use 4.13.2, or the container, or read those reds as version noise |
| everything fails, nothing builds | the driver class is not `simpl` | `MAIN=yourname ./test/run.sh` |
| a `valid/` program draws a message | most often a whole array used where §5.2.4 allows one — assigned, allocated, passed, returned | check §5.2.4 and 3.4 before touching the test |

## Adding your own tests

Send them as a pull request, in a folder of your own, so it stays clear whose
reading each recorded result is.

1. Fork this repository and branch.
2. Make a folder at the top named after you — your surname, lower case, or your
   first name if that is taken: `naidoo/`, `botha/`. Everything of yours lives
   in it, and nothing of mine is edited.
3. Put each program in it as `NAME.simpl`, with a `NAME.expected` beside it
   holding exactly what your checker writes to the standard error channel — an
   empty file if the program must draw nothing at all. Name it after the rule or
   the corner it is about, one per program, the way the folders above do.
4. Open the program with a comment saying what it tests, and say so there if it
   turns on a reading the assignment leaves open, so the next person knows which
   part is your answer rather than the specification's.
5. Record your `.expected` with the conventions in *What the recorded output
   assumes* — positions from 1, §5.3 wording — or say in the program's comment
   where yours differ. A folder that is self-consistent is worth having either
   way.
6. Add one line for your folder to the list in *What each folder targets*, with
   your name and what it covers.
7. Run `./test/run.sh yourfolder` before you open the pull request. The runner
   picks up any folder of `.simpl` programs, so yours runs with everyone else's
   as soon as it is in.

## What each folder targets

- **`valid/`** — programs that must be accepted in silence. Globals,
  declarations mixed arbitrarily, nested functions, recursion, shadowing,
  arrays as parameters, every operator at its correct types, every legal form
  of `exit`, precedence, `elsif` chains, nested loops, procedures, `write`
  items, `read` targets, unary minus, string escapes, identifier forms,
  comments between tokens.

- **`scope/`** — one scope rule each: the eight principles, an undeclared name
  in each position it can hold (argument, index, guard, `write` item,
  assignment target, call, allocation, `exit`, `read`), redeclaration in each
  form, and the cases that must stay silent — shadowing, transparency, a
  popped scope, a redeclaration nesting makes legal, a function visible inside
  itself.

- **`type/`** — one type rule each, from chapter 5 of the language
  specification: the operand of every operator, the sameness `=` wants, index
  and element types, array size, allocation target, whole arrays under §5.2.4,
  every way a call can be wrong, every way an `exit` can be, guards, `read`
  targets, `write` items.

- **`syntax/`** — programs the grammar must reject: declarations mixed with
  statements, a missing keyword or separator, `=` written for `<-`, chained
  comparisons, an empty statement list, `chill` joined to a statement, a
  comment or string left open.

- **`corners/`** — one corner each, where the other four take one rule each:
  the lexer's nested comments, identifier limit, escapes and character range,
  CRLF line endings, the line between `<simple>` and `<expr>` in an index, the
  order messages are printed in, every operator against a whole array in one
  file, and the handful of questions the assignment leaves open. Four of them
  record an answer the specification does not fix, and are marked as such in
  the program's own opening comment.
