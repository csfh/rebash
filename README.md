# Rebash

Supercharged bash. Bash is already Bourne Again SHell. This is the next again.

`rb` starts bash with rebash loaded.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/csfh/rebash/main/install.sh | bash
```

That puts `rb` on `~/.local/bin`. From a clone, `./install.sh` does the same.

```bash
./install.sh --prefix /usr/local
./install.sh --uninstall
```

## Plugins

```bash
rb up git
```

That enables the git plugin, a set of bash aliases for git (`gs`, `gco`, `gl`, and the rest). `rb` starts bash with enabled plugins loaded.

## Tests

```bash
./tests/run
```

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Christoffer Hallas.
