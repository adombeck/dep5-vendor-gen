# dep5-vendor-gen

Generate a [DEP-5](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/)
`debian/copyright` file from vendored dependencies.

This tool scans one or more vendor directories (e.g. `vendor/`, `vendor_rust/`),
extracts license and copyright information for each vendored package, and
writes (or updates) a machine-readable `debian/copyright` file.

The tool is deterministic, running it multiple times against the same vendor
tree produces identical output, so it's safe to regenerate `debian/copyright` in
CI without introducing spurious diffs.

## How it works

1. Runs [`licensecheck`](https://manpages.debian.org/testing/licensecheck/licensecheck.1.en.html)
   on all files in the vendor directories.
2. Looks for `SPDX-License-Identifier` tags in source files, which take
   precedence over the `licensecheck` result.
3. Builds a directory tree and merges nodes that share identical license and
   copyright information, to keep the generated file as compact as possible.
4. Generates or updates `debian/copyright` with `Files:` stanzas for each
   vendored package, while preserving the existing header and `License:`
   stanzas.

## Requirements

- Python 3
- [`python3-anytree`](https://pypi.org/project/anytree/)
- [`licensecheck`](https://manpages.ubuntu.com/manpages/lts/man1/licensecheck.1p.html)

```
sudo apt install python3-anytree licensecheck
```

## Usage

```
dep5-vendor-gen [-h] [--debian-copyright <copyright-file>] [--debug] [<vendor-dir> ...]
```

- `<vendor-dir>`: vendor directories to scan (default: auto-detect `./vendor*`)
- `--debian-copyright <copyright-file>`: path to the `debian/copyright` file
  to generate or update (default: `debian/copyright`)
- `--debug`: enable debug logging

### Examples

```sh
# Auto-detect vendor directories (./vendor*)
dep5-vendor-gen

# Scan specific vendor directories
dep5-vendor-gen vendor vendor_rust

# Output to a different location
dep5-vendor-gen --debian-copyright /path/to/copyright
```

After running, validate the generated file with
[`lrc`](https://manpages.debian.org/testing/licenserecon/lrc.1.en.html) (from
the `licenserecon` package).

## License

This project is licensed under the terms of the GNU General Public License,
version 3 or later (`GPL-3.0-or-later`). See [COPYING](COPYING).
