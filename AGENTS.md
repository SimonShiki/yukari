> If you're a human, read <./CONTRIBUTING.md> 🥰
Yukari is a cross-platform decentrailized networking tool that based on EasyTier.

# Concepts

## Models

Models are the data structure that the app uses.
Define a new if we need to illustrate a new data structure.

## Signals

Signals are **only** way that the UI and the data bind together.
Before writing, check Flutter skills (or remote if local not exists: <https://github.com/rodydavis/signals.dart/tree/main/skills/signals-flutter>).

# Common UI patterns

Follow these rules if you're contributing to the UI.

## Architecture

Pages are the top-level UI components that represent a screen in the app. they subscribed to global signals and do their own business logics.
Page itself should be UI-only and trigger the action through its controller.
Controller contains:

- All signals that the page needs to subscribe to. They should be small and primitive. Use `computed` signals if it's derived from complex global signals.
- The effects related to page's signals.
- The actions that the page needs.
Page contains:
- The UI components that are related to the page.
- Construct the UI components with the signals from controller. using `SignalBuilder` to bind the signals to the UI components that really need to update when the signals change. AVOID using `SignalBuilder` to wrap the whole page to avoid unnecessary rebuilds. only subcribes the primitive signals for minimal rebuilds.
- Call the actions from controller when user interacts with the UI components.

# Designing

For designing stuffs, use Material Design 3 Expressive. read [https://m3.material.io/](https://m3.material.io/) or local skills to confirm the most-suitable design in my given scenario. Prefer using `m3e_core` components.

# Tests

Every new feature and bug fix should have a test.
Test should locks the expected behavior.
For UI, check the expected behavior of the UI components and the signals that they subscribed to. lock the refreshing behavior of the UI components when the signals change.

# Common rules when you contributing

Before you write it at all, Work down this list and stop at the first answer that holds.

1. Does this need to exist? A flag nobody asked for, a knob for a value that never changes, an interface with one implementation: skip it and say so in one line.
2. Does it already exist here? See "Reuse before you write" below. Grep first.
3. Can it be one line? Then it is one line.
4. Only then write the smallest thing that works.
5. Should the code put in same file? In most cases, a code file should be limited within 200 lines. One file do one job. Keep modularized.
6. Is it the best way to do it? Read official documentations if have, especially their "best-practices" or official examples.

Two answers work? Take the higher one and move on.

The list shortens the solution, never the reading. Trace the flow the change touches before
you pick a rung. A small diff in the wrong place is a second bug, not a lazy fix. Same for
bug reports: a report names a symptom, so grep every caller before you edit. One guard in
the shared function is smaller than a guard in each caller, and it fixes the siblings the
report did not mention.

Never simplify away input validation at a trust boundary, a fail-closed check, error
handling that loses state, or anything the requester asked for by name.

During the work, NEVER touch the Git, let the human to review and check.
