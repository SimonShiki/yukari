> If you're a human, read <./CONTRIBUTING.md> 🥰
Yukari is a cross-platform decentrailized networking tool that based on EasyTier.
# Architecture
## Models
Models are the data structure that the app uses. which stored in `models/` folder. Think whether to add before implement a new feature.
## Signals
Signals are the way, and in most cases the only way, that the UI and the actual logic communicate. Before writing, check Flutter skills (or remote if local not exists: https://github.com/rodydavis/signals.dart/tree/main/skills/signals-flutter). Any changes that trigger the UI change should be done through them.
`signals/` stores global app state. for local, put in controllers.
## Pages & Controller
Pages are UI, controllers handle the logic.
## Widgets
If a widget is too complex or it likely to be reuse, then put it in `widgets/` folder.
# Designing
For designing stuffs, use Material Design 3 Expressive. read [https://m3.material.io/](https://m3.material.io/) or local skills to confirm the most-suitable design in my given scenario. Prefer using `m3e_core` components.
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

## Reuse before you write

The largest cleanup this project ever needed was caused by writing new code beside existing
code instead of extending it: a 700-line duplicate of the container config form, three
copies of the init system screen, one bottom bar pasted seven times. Grep before you write.