> If you're a human, read [CONTRIBUTING.md](./CONTRIBUTING.md).

Yukari is a cross-platform decentralized networking tool built on EasyTier.

# Concepts

## Models

A model is one of the data structures the app passes around. Add a model when
you need to show a new data structure.

## Signals

Signals are the only binding between the UI and the data. Before you write one,
check the Flutter signals skill locally, or read it at
<https://github.com/rodydavis/signals.dart/tree/main/skills/signals-flutter>.

# Common UI patterns

Follow these rules when you touch the UI.

## Architecture

A page is the top-level UI component for one screen. It subscribes to the
global signals it needs and runs its own business logic, but it stays UI-only:
it triggers work through its controller.

The controller holds:

- Every signal the page subscribes to. Keep them small and primitive, and use
  `computed` for anything derived from a complex global signal.
- The effects that belong to the page's signals.
- The actions the page calls.

The page holds:

- The UI components that belong to it.
- Those components, built from the controller's signals. Wrap only the
  components that must update in a `SignalBuilder`. Wrapping the whole page
  rebuilds everything on every change; subscribe to primitive signals instead
  and the rebuilds stay minimal.
- The calls to controller actions, made when the user interacts with a
  component.

# Designing

Use Material Design 3 Expressive. Read [https://m3.material.io/](https://m3.material.io/)
or the local skills to settle on the right design for the case in front of you.
Prefer `m3e_core` components.

# Tests

Every new feature and every bug fix gets a test. A test locks the behaviour you
expect.

For UI, cover the behaviour of the components and of the signals they subscribe
to, and lock what refreshes when a signal changes.

# Common rules when you contribute

Work down this list before you write anything, and stop at the first answer that
holds.

1. Does this need to exist? A flag nobody asked for, a knob for a value that
   never changes, an interface with one implementation: skip it, and say so in
   one line.
2. Does it already exist here? Grep first.
3. Can it be one line? Then it is one line.
4. Only then write the smallest thing that works.
5. Does the code belong in this file? Most files stay under 200 lines, and one
   file does one job. Keep it modular.
6. Is this the best way to do it? Read the official documentation where it
   exists, especially the best-practice pages and the official examples.

Two answers work? Take the higher one and move on.

The list shortens the solution, never the reading. Trace the flow the change
touches before you pick a rung. A small diff in the wrong place is a second bug,
not a lazy fix. The same goes for bug reports: a report names a symptom, so grep
every caller before you edit. One guard in the shared function is smaller than a
guard in each caller, and it fixes the siblings the report did not mention.

Never simplify away input validation at a trust boundary, a fail-closed check,
error handling that loses state, or anything the requester asked for by name.

Never touch Git during the work. Leave the review and the check to the human.
