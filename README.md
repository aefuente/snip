# snip

**snip** is a super minimalist `grep`-style tool written in [Zig](https://ziglang.org/).

## Features

- Search for text patterns in files or from stdin  

## Installation

Clone the repository and build with Zig:

```bash
git clone https://github.com/aefuente/snip.git
cd snip
zig build -Doptimize=ReleaseFast
````

This will produce the `snip` executable.

## Usage

```bash
# Search for "pattern" in a file
snip "pattern" file.txt
```

Supports reading from `stdin`:

```bash
cat file.txt | snip "pattern"
```

## Examples

```bash
# Find all lines containing "hello" in file.txt
snip "hello" file.txt
```

## License

MIT License
