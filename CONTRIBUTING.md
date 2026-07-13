# Contributing to Kamalen Shell

Contributions are welcome when they improve the shell without weakening the live desktop configuration.

## Before opening a change

1. Keep changes focused. Do not mix generated state, personal wallpapers, or unrelated formatting with a feature or fix.
2. Treat `.config/` as live configuration: its Quickshell and MangoWM files are linked into `~/.config/` by the installer.
3. For QML changes, validate with `qmllint`. Never start a second Quickshell instance; restart only with the sequence below.
4. For MangoWM settings, modify `conf.d/*.conf`; `config.conf` should only source modules.

## Validation

Run the relevant checks before proposing a change:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
./install.sh --dry-run
./install.sh verify
git diff --check
```

Use conventional commit prefixes such as `feat:`, `fix:`, `refactor:`, `docs:`, or `chore:`.

```bash
pkill quickshell
sleep 1
nohup quickshell &>/dev/null &
```

## Licensing

By submitting a contribution, you agree to license your original contribution under the MIT License used by this repository. Do not add content that you do not have the right to redistribute. In particular, wallpapers, fonts, artwork, and external media may have licenses that differ from the repository license and must retain their required attribution.

## Security and scope

Do not commit credentials, API keys, runtime state, caches, or local paths. Report security-sensitive issues privately to the repository maintainer instead of publishing exploit details in an issue.
