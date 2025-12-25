# GTNH Prism Launcher Updater

![Tests](https://github.com/ciefa/gtnh-prism-updater/actions/workflows/test.yml/badge.svg)

A bash script to safely update [GT New Horizons](https://www.gtnewhorizons.com/) client instances in [Prism Launcher](https://prismlauncher.org/), following the [official update instructions](https://gtnh.miraheze.org/wiki/Installing_and_Migrating#Method_.231:_Direct).

## Features

- Clones your existing instance (preserves the original)
- Replaces `config`, `mods`, and `serverutilities` folders automatically
- Handles Java 17+ files (`libraries`, `patches`, `mmc-pack.json`)
- Auto-detects Prism Launcher instances folder
- Dry-run mode to preview changes before applying
- Non-interactive mode for automation
- Supports `.zip`, `.tar.gz`, and `.tar` archives

## Requirements

- Bash 4.0+ (Git Bash on Windows)
- `tar` or `unzip` (depending on archive format)
- `curl` or `wget` (only if downloading from URL)

## Usage

```bash
./update.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `-i, --instance DIR` | Path to your current GTNH instance folder (required) |
| `-n, --name NAME` | Name for the new/updated instance (required) |
| `-u, --url URL` | Download URL for the new client version |
| `-f, --file FILE` | Path to already downloaded client archive |
| `-p, --prism-dir DIR` | Prism instances folder (auto-detected if not set) |
| `-j, --java17` | Using Java 17+ (also replaces libraries, patches, mmc-pack.json) |
| `--dry-run` | Simulate the update without making changes |
| `-y, --yes` | Skip confirmation prompt |
| `-h, --help` | Show help message |

### Examples

Update from a downloaded archive:
```bash
./update.sh -i ~/.local/share/PrismLauncher/instances/GTNH_2.8.1 \
    -n "GTNH 2.8.4" \
    -f ~/Downloads/GT_New_Horizons_2.8.4_Client.zip
```

Update with Java 17+ and skip confirmation:
```bash
./update.sh -i /path/to/GTNH_instance -n "GTNH 2.8.4" -f client.zip --java17 --yes
```

Download and update in one step:
```bash
./update.sh -i /path/to/GTNH_instance -n "GTNH 2.8.4" \
    -u "https://example.com/gtnh-client.zip" --java17
```

Preview what would happen (dry-run):
```bash
./update.sh -i /path/to/instance -n "GTNH New" -f client.zip --dry-run
```

Custom Prism instances folder (e.g., Windows with custom path):
```bash
./update.sh -i "D:/PrismInstances/GTNH_2.8.1" \
    -n "GTNH 2.8.4" \
    -f client.zip \
    -p "D:/PrismInstances"
```

## What It Does

1. **Downloads** the new client version (if URL provided)
2. **Clones** your existing instance to a new folder
3. **Removes** old folders: `config`, `mods`, `serverutilities` (and `scripts`, `resources` if present)
4. **Removes** Java 17+ files if `--java17` flag is set
5. **Extracts** new client files from the archive
6. **Installs** new folders to the cloned instance
7. **Installs** Java 17+ files if `--java17` flag is set
8. **Updates** instance name in configuration

## Prism Launcher Instance Locations

The script auto-detects these standard locations:

| OS | Path |
|----|------|
| Linux | `~/.local/share/PrismLauncher/instances/` |
| Linux (Flatpak) | `~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/` |
| macOS | `~/Library/Application Support/PrismLauncher/instances/` |
| Windows | `%APPDATA%/PrismLauncher/instances/` |
| Windows (Scoop) | `%HOMEPATH%/scoop/persist/prismlauncher/instances/` |

If you have a custom location, use `--prism-dir` to specify it.

## After Updating

1. **Launch Prism Launcher** - The new instance should appear
2. **Review settings** - Check Java arguments if using Java 17+
3. **Test the instance** - Launch and verify everything works

For Java 17+ setup, see: https://github.com/GTNewHorizons/lwjgl3ify

## Running Tests

```bash
bash update_test.sh
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## See Also

- [gtnh-server-updater](https://github.com/ciefa/gtnh-server-updater) - Server-side update script
