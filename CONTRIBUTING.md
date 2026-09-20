# Contributing

Thanks for helping with Kalends.

- Open an issue before a large change so we can agree on the approach.
- Keep the library free of app concerns: no storage, networking, sync or account types. If a feature needs data, it goes through `KalendsDataSource` and `KalendsActions`.
- Everything public is documented with a `///` comment and covered by a test where it can be.
- The Example app must keep building on macOS and iOS Simulator (`xcodebuild -project Example/KalendsExample.xcodeproj -scheme KalendsExample`). Regenerate it with `xcodegen generate` in `Example/` after editing `project.yml`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `refactor:`, `test:`.
- Add a line to `CHANGELOG.md` under *Unreleased*.
