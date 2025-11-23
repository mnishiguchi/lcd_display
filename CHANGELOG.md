# Changelog

All notable changes to this project will be documented in this file.

## v0.3.0

- Add `LcdDisplay.CharacterLcd` as the main high-level API and move existing HD44780 character LCD code under it.
- Deprecate `LcdDisplay.start_link/1` and `LcdDisplay.execute/2`.
- Support `GenServer` options and supervisor child specs via `LcdDisplay.CharacterLcd.child_spec/1`.
- Update dependencies, CI, examples and README for the new API and newer Elixir/OTP.
