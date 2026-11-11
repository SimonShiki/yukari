# Contributing

If you plan to work on something larger, open an issue first and say what you have in mind, so nobody builds the same thing twice or in a different direction.

If you are an AI agent rather than a person, read [AGENTS.md](./AGENTS.md) instead. It covers the architecture and the rules for changing the UI.

## Setting up

```bash
flutter pub get
flutter gen-l10n
```

`lib/l10n/generated/` is not checked in, so run `flutter gen-l10n` again whenever the `.arb` files change. Building without it fails on the missing localization class.

On Linux, both the build and the tests need the headers the EasyTier native library links:

```bash
sudo apt-get install libgtk-3-dev libxi-dev libx11-dev libnotify-dev
```

You do not need Rust or xmake to build. A package hook downloads the EasyTier library that matches the current sources from the `natives` release, and only compiles EasyTier itself when no published build matches. If you do change the native sources, see `tool/pack_service_module.sh` and the native build jobs in `.github/workflows/ci.yml`.

## Running the app

```bash
flutter run -d linux        # or windows
flutter run -d android
```

To try service mode from a local build, pass the tag of a release that carries the signed module. Canary tags look like `canary-<run id>-<attempt>`:

```bash
flutter run -d android --dart-define=SERVICE_MODULE_RELEASE_TAG=canary-42737793232-1
```

Without that define the app refuses to install a module, because a local build has no release to fetch one from.

## LLM

Feel free to use any LLM you like. Just be responsible for **your** contribution.

## Before you open a pull request

```bash
flutter analyze
flutter test
```

CI runs both on Linux and Windows for every push and every pull request, and a red check blocks the merge. Run them locally first; a failing test in review costs a round trip.

## What a change should look like

Every new feature and every bug fix needs a test. A test is what locks the behaviour you expect, and it is the part a reviewer reads to see what you meant.

For a UI change, cover the components and the signals they subscribe to, and lock what refreshes when a signal changes. A page that rebuilds the whole tree on every change will pass a test that only checks the widgets, so check the rebuilds too.

Read [AGENTS.md](./AGENTS.md) before you touch the interface. The short version:

- A page subscribes to signals and stays UI-only. It triggers work through its controller.
- Signals are the only binding between the UI and the data.
- Use Material 3 Expressive and prefer the `m3e_core` components.
- Most files stay under 200 lines, and one file does one job.

Write the smallest change that works. If a shorter version does the same thing, take it. Do not add a flag, a setting or an interface that nothing asked for.

## Commit messages

Yukari uses [gitmoji](https://gitmoji.dev/) and [Conventional Commits](https://www.conventionalcommits.org/). The subject names the change in the imperative, in plain words:

```
:bug: fix: service mode become unavailable permanently while upgrading
:wrench: chore: lock service module with apk
```

Sign off every commit with `git commit -s`. The sign-off states that you wrote the change, or otherwise have the right to submit it.

Keep one change per commit where you can. A commit that fixes a bug and reformats a file in the same diff makes the fix hard to find later.

## Reporting a bug

Open an issue and include:

- What you did, in steps.
- What you expected.
- What happened instead.
- The app version, the EasyTier version, and your platform.

About shows the app version. While service mode runs, Home shows the EasyTier and service versions beside the service state. If you can, copy the network log as JSON and attach it; it is the quickest way to see what the daemon did.

## Licence

Yukari is released under the AGPL-3.0-only licence, see [LICENSE](./LICENSE). By opening a pull request you agree that your contribution is released under the same terms. Keep the copyright notice and the acknowledgement of co-authorship in place in anything you redistribute.
