#!/bin/bash

# GTNH (GT New Horizons) Prism Launcher Client Update Script
# Based on official update instructions (Method #1: Direct)
#
# Designed for testability:
# - All logic extracted into functions
# - External commands are mockable via variables
# - Dry-run mode for simulation
# - Non-interactive mode for automation

set -e  # Exit on any error

#######################################
# MOCKABLE EXTERNAL COMMANDS
#######################################
CP_CMD="${CP_CMD:-cp}"
RM_CMD="${RM_CMD:-rm}"
MKDIR_CMD="${MKDIR_CMD:-mkdir}"
UNZIP_CMD="${UNZIP_CMD:-unzip}"
TAR_CMD="${TAR_CMD:-tar}"
CURL_CMD="${CURL_CMD:-curl}"
WGET_CMD="${WGET_CMD:-wget}"

#######################################
# COLORS AND OUTPUT
#######################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################
# GLOBAL VARIABLES
#######################################
INSTANCE_DIR=""
NEW_CLIENT_ARCHIVE=""
DOWNLOAD_URL=""
NEW_INSTANCE_NAME=""
JAVA17_MODE=false
SKIP_DOWNLOAD=false
DRY_RUN=false
AUTO_YES=false
PRISM_BASE_DIR=""

#######################################
# TEST HELPERS
#######################################
reset_globals() {
    INSTANCE_DIR=""
    NEW_CLIENT_ARCHIVE=""
    DOWNLOAD_URL=""
    NEW_INSTANCE_NAME=""
    JAVA17_MODE=false
    SKIP_DOWNLOAD=false
    DRY_RUN=false
    AUTO_YES=false
    PRISM_BASE_DIR=""
}

#######################################
# LOGGING FUNCTIONS
#######################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_dry_run() {
    echo -e "${YELLOW}[DRY-RUN]${NC} Would execute: $1" >&2
}

#######################################
# COMMAND EXECUTION (respects dry-run)
#######################################
exec_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "$*"
        return 0
    else
        "$@"
    fi
}

do_cp() {
    exec_cmd $CP_CMD "$@"
}

do_rm() {
    exec_cmd $RM_CMD "$@"
}

do_mkdir() {
    exec_cmd $MKDIR_CMD "$@"
}

#######################################
# USAGE/HELP
#######################################
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

GTNH Prism Launcher Client Update Script - Updates your GT New Horizons instance

Options:
  -i, --instance DIR        Path to your current GTNH instance folder (required)
  -n, --name NAME           Name for the new/updated instance (required)
  -u, --url URL             Download URL for the new client version
  -f, --file FILE           Path to already downloaded client archive
  -p, --prism-dir DIR       Prism Launcher base directory (auto-detected if not set)
  -j, --java17              Using Java 17+ (also replaces libraries, patches, mmc-pack.json)
      --dry-run             Simulate the update without making changes
  -y, --yes                 Skip confirmation prompt
  -h, --help                Show this help message

Examples:
  # Update using a downloaded archive
  $0 -i ~/.local/share/PrismLauncher/instances/GTNH_2.8.1 -n "GTNH 2.8.4" -f ~/Downloads/GT_New_Horizons_2.8.4.zip

  # Update with download and Java 17+ mode
  $0 -i /path/to/GTNH_instance -n "GTNH 2.8.4" -u "https://example.com/gtnh.zip" --java17

  # Preview what would happen
  $0 -i /path/to/instance -n "GTNH New" -f client.zip --dry-run

Prism Launcher instance locations (auto-detected):
  Linux:         ~/.local/share/PrismLauncher/instances/
  Linux Flatpak: ~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/
  macOS:         ~/Library/Application Support/PrismLauncher/instances/
  Windows:       %APPDATA%/PrismLauncher/instances/
  Windows Scoop: %HOMEPATH%/scoop/persist/prismlauncher/instances/

If you have a custom instances folder, use --prism-dir to specify it.

EOF
}

#######################################
# ARGUMENT PARSING
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--instance)
                INSTANCE_DIR="$2"
                shift 2
                ;;
            -n|--name)
                NEW_INSTANCE_NAME="$2"
                shift 2
                ;;
            -u|--url)
                DOWNLOAD_URL="$2"
                shift 2
                ;;
            -f|--file)
                NEW_CLIENT_ARCHIVE="$2"
                SKIP_DOWNLOAD=true
                shift 2
                ;;
            -p|--prism-dir)
                PRISM_BASE_DIR="$2"
                shift 2
                ;;
            -j|--java17)
                JAVA17_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

#######################################
# VALIDATION
#######################################
validate_args() {
    local errors=0

    if [[ -z "$INSTANCE_DIR" ]]; then
        log_error "Instance directory is required! Use -i or --instance"
        errors=$((errors + 1))
    elif [[ ! -d "$INSTANCE_DIR" ]]; then
        log_error "Instance directory does not exist: $INSTANCE_DIR"
        errors=$((errors + 1))
    elif [[ ! -d "$INSTANCE_DIR/.minecraft" ]]; then
        log_error "Not a valid Prism instance (no .minecraft folder): $INSTANCE_DIR"
        errors=$((errors + 1))
    fi

    if [[ -z "$NEW_INSTANCE_NAME" ]]; then
        log_error "New instance name is required! Use -n or --name"
        errors=$((errors + 1))
    fi

    if [[ "$SKIP_DOWNLOAD" == false && -z "$DOWNLOAD_URL" ]]; then
        log_error "Either --url or --file must be provided!"
        errors=$((errors + 1))
    fi

    if [[ "$SKIP_DOWNLOAD" == true && ! -f "$NEW_CLIENT_ARCHIVE" ]]; then
        log_error "Archive file does not exist: $NEW_CLIENT_ARCHIVE"
        errors=$((errors + 1))
    fi

    return $(( errors > 0 ? 1 : 0 ))
}

validate_dependencies() {
    local missing=()

    if ! command -v unzip &> /dev/null && ! command -v tar &> /dev/null; then
        missing+=("unzip or tar")
    fi

    if [[ "$SKIP_DOWNLOAD" == false ]]; then
        if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
            missing+=("wget or curl")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

#######################################
# PRISM LAUNCHER DETECTION
#######################################
detect_prism_dir() {
    # If user specified a directory, use it
    if [[ -n "$PRISM_BASE_DIR" ]]; then
        echo "$PRISM_BASE_DIR"
        return 0
    fi

    # Standard Prism Launcher instance locations
    local possible_dirs=(
        # Linux
        "$HOME/.local/share/PrismLauncher/instances"
        # Linux Flatpak
        "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
        # macOS
        "$HOME/Library/Application Support/PrismLauncher/instances"
        # Windows (Git Bash / MSYS2)
        "$APPDATA/PrismLauncher/instances"
        # Windows Scoop
        "$HOMEPATH/scoop/persist/prismlauncher/instances"
    )

    for dir in "${possible_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Auto-detected Prism instances folder: $dir"
            echo "$dir"
            return 0
        fi
    done

    # Fall back to parent of instance dir (user might have custom location)
    if [[ -n "$INSTANCE_DIR" ]]; then
        local parent
        parent=$(dirname "$INSTANCE_DIR")
        log_info "Using parent of source instance: $parent"
        echo "$parent"
        return 0
    fi

    log_error "Could not detect Prism Launcher instances folder"
    log_error "Please specify with --prism-dir or use -i with full instance path"
    return 1
}

#######################################
# ARCHIVE HANDLING
#######################################
detect_archive_type() {
    local file="$1"

    case "$file" in
        *.zip)
            echo "zip"
            ;;
        *.tar.gz|*.tgz)
            echo "tar.gz"
            ;;
        *.tar)
            echo "tar"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

download_archive() {
    local url="$1"
    local output="$2"

    log_info "Downloading from: $url"

    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "download $url to $output"
        touch "$output" 2>/dev/null || true
        return 0
    fi

    if command -v curl &> /dev/null; then
        $CURL_CMD -L -o "$output" "$url"
    elif command -v wget &> /dev/null; then
        $WGET_CMD -O "$output" "$url"
    else
        log_error "Neither curl nor wget is available!"
        return 1
    fi
}

extract_archive() {
    local archive="$1"
    local dest="$2"
    local archive_type

    archive_type=$(detect_archive_type "$archive")

    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "extract $archive ($archive_type) to $dest"
        return 0
    fi

    case "$archive_type" in
        zip)
            $UNZIP_CMD -o -q "$archive" -d "$dest"
            ;;
        tar.gz)
            $TAR_CMD -xzf "$archive" -C "$dest"
            ;;
        tar)
            $TAR_CMD -xf "$archive" -C "$dest"
            ;;
        *)
            log_error "Unsupported archive format: $archive"
            return 1
            ;;
    esac
}

find_minecraft_dir() {
    local extract_dir="$1"

    if [[ "$DRY_RUN" == true ]]; then
        echo "$extract_dir"
        return 0
    fi

    # Look for .minecraft folder in extracted content
    local minecraft_dir
    minecraft_dir=$(find "$extract_dir" -type d -name ".minecraft" 2>/dev/null | head -1)

    if [[ -n "$minecraft_dir" ]]; then
        echo "$minecraft_dir"
        return 0
    fi

    # Check if extract_dir itself contains the expected folders
    if [[ -d "$extract_dir/mods" && -d "$extract_dir/config" ]]; then
        echo "$extract_dir"
        return 0
    fi

    # Check one level deep
    for subdir in "$extract_dir"/*/; do
        if [[ -d "${subdir}mods" && -d "${subdir}config" ]]; then
            echo "${subdir%/}"
            return 0
        fi
        if [[ -d "${subdir}.minecraft" ]]; then
            echo "${subdir}.minecraft"
            return 0
        fi
    done

    log_error "Could not find .minecraft or mod folders in archive"
    return 1
}

find_instance_root() {
    local extract_dir="$1"

    if [[ "$DRY_RUN" == true ]]; then
        echo "$extract_dir"
        return 0
    fi

    # For Java 17+ files, we need the instance root (parent of .minecraft)
    # Look for mmc-pack.json or libraries folder
    local instance_root
    instance_root=$(find "$extract_dir" -type f -name "mmc-pack.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)

    if [[ -n "$instance_root" ]]; then
        echo "$instance_root"
        return 0
    fi

    # Check extract_dir itself
    if [[ -f "$extract_dir/mmc-pack.json" ]]; then
        echo "$extract_dir"
        return 0
    fi

    # Check one level deep
    for subdir in "$extract_dir"/*/; do
        if [[ -f "${subdir}mmc-pack.json" ]]; then
            echo "${subdir%/}"
            return 0
        fi
    done

    echo "$extract_dir"
}

#######################################
# INSTANCE OPERATIONS
#######################################
clone_instance() {
    local source="$1"
    local dest="$2"

    log_info "Cloning instance: $source -> $dest"

    if [[ -d "$dest" ]]; then
        log_error "Destination already exists: $dest"
        return 1
    fi

    do_cp -a "$source" "$dest"
    log_success "Instance cloned!"
}

remove_old_folders() {
    local minecraft_dir="$1"
    local folders=("config" "serverutilities" "mods")

    log_info "Removing old folders from .minecraft..."

    for folder in "${folders[@]}"; do
        if [[ -d "$minecraft_dir/$folder" ]] || [[ "$DRY_RUN" == true ]]; then
            do_rm -rf "$minecraft_dir/$folder"
            log_info "  Removed: $folder/"
        else
            log_warn "  Not found (skipping): $folder/"
        fi
    done

    # Also remove scripts and resources if they exist
    for folder in scripts resources; do
        if [[ -d "$minecraft_dir/$folder" ]]; then
            do_rm -rf "$minecraft_dir/$folder"
            log_info "  Removed: $folder/"
        fi
    done
}

remove_java17_files() {
    local instance_dir="$1"
    local items=("libraries" "patches" "mmc-pack.json")

    log_info "Removing Java 17+ specific files from instance root..."

    for item in "${items[@]}"; do
        if [[ -e "$instance_dir/$item" ]] || [[ "$DRY_RUN" == true ]]; then
            do_rm -rf "$instance_dir/$item"
            log_info "  Removed: $item"
        else
            log_warn "  Not found (skipping): $item"
        fi
    done
}

install_new_folders() {
    local source_minecraft="$1"
    local dest_minecraft="$2"
    local folders=("config" "serverutilities" "mods")

    log_info "Installing new folders to .minecraft..."

    for folder in "${folders[@]}"; do
        if [[ -d "$source_minecraft/$folder" ]]; then
            do_cp -a "$source_minecraft/$folder" "$dest_minecraft/"
            log_info "  Copied: $folder/"
        else
            log_warn "  Not in archive (skipping): $folder/"
        fi
    done

    # Also copy scripts and resources if they exist in new version
    for folder in scripts resources; do
        if [[ -d "$source_minecraft/$folder" ]]; then
            do_cp -a "$source_minecraft/$folder" "$dest_minecraft/"
            log_info "  Copied: $folder/"
        fi
    done
}

install_java17_files() {
    local source_instance="$1"
    local dest_instance="$2"
    local items=("libraries" "patches" "mmc-pack.json")

    log_info "Installing Java 17+ specific files..."

    for item in "${items[@]}"; do
        if [[ -e "$source_instance/$item" ]]; then
            do_cp -a "$source_instance/$item" "$dest_instance/"
            log_info "  Copied: $item"
        else
            log_warn "  Not in archive (skipping): $item"
        fi
    done
}

update_instance_name() {
    local instance_dir="$1"
    local new_name="$2"
    local cfg_file="$instance_dir/instance.cfg"

    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "update instance name to '$new_name' in $cfg_file"
        return 0
    fi

    if [[ -f "$cfg_file" ]]; then
        # Update the name in instance.cfg
        if grep -q "^name=" "$cfg_file"; then
            sed -i "s/^name=.*/name=$new_name/" "$cfg_file"
        else
            echo "name=$new_name" >> "$cfg_file"
        fi
        log_info "Updated instance name in config"
    fi
}

#######################################
# USER INTERACTION
#######################################
confirm_update() {
    if [[ "$AUTO_YES" == true ]]; then
        log_info "Auto-confirmed (--yes flag)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry-run mode - proceeding with simulation"
        return 0
    fi

    read -p "Do you want to proceed with the update? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "   GTNH Prism Client Update Script"
    echo "=========================================="
    echo ""
    log_info "Source instance: $INSTANCE_DIR"
    log_info "New instance name: $NEW_INSTANCE_NAME"
    log_info "New instance path: $NEW_INSTANCE_DIR"
    log_info "Java 17+ mode: $JAVA17_MODE"
    log_info "Dry-run mode: $DRY_RUN"
    echo ""
}

print_completion_message() {
    echo ""
    echo "=========================================="

    if [[ "$DRY_RUN" == true ]]; then
        log_success "GTNH Client Update Dry-Run Complete!"
        echo "=========================================="
        echo ""
        log_info "No changes were made. Run without --dry-run to perform actual update."
    else
        log_success "GTNH Client Update Complete!"
        echo "=========================================="
    fi

    echo ""
    log_info "New instance created at: $NEW_INSTANCE_DIR"
    log_warn "IMPORTANT: Review any custom config changes you may need to re-apply!"
    echo ""

    if [[ "$JAVA17_MODE" == true ]]; then
        log_info "Java 17+ files were updated. You may need to adjust Java arguments in Prism."
    fi
    echo ""
}

#######################################
# MAIN FUNCTION
#######################################
main() {
    parse_args "$@"

    if ! validate_args; then
        echo ""
        print_usage
        exit 1
    fi

    if ! validate_dependencies; then
        exit 1
    fi

    # Convert to absolute path
    INSTANCE_DIR=$(cd "$INSTANCE_DIR" && pwd)

    # Detect Prism base directory
    PRISM_BASE_DIR=$(detect_prism_dir)

    # Set new instance directory
    NEW_INSTANCE_DIR="$PRISM_BASE_DIR/$NEW_INSTANCE_NAME"

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    print_summary

    if ! confirm_update; then
        log_info "Update cancelled."
        exit 0
    fi

    echo ""

    # Step 1: Download or use provided archive
    local working_archive="$NEW_CLIENT_ARCHIVE"
    if [[ "$SKIP_DOWNLOAD" == false ]]; then
        log_info "Step 1: Downloading new client version..."
        working_archive="$TEMP_DIR/gtnh-client-new.zip"
        download_archive "$DOWNLOAD_URL" "$working_archive"
        log_success "Download complete!"
    else
        log_info "Step 1: Using provided archive: $NEW_CLIENT_ARCHIVE"
    fi

    # Step 2: Clone current instance
    log_info "Step 2: Cloning current instance..."
    clone_instance "$INSTANCE_DIR" "$NEW_INSTANCE_DIR"

    # Step 3: Remove old folders from .minecraft
    log_info "Step 3: Removing old folders..."
    remove_old_folders "$NEW_INSTANCE_DIR/.minecraft"

    # Step 4: Remove Java 17+ files if applicable
    if [[ "$JAVA17_MODE" == true ]]; then
        log_info "Step 4: Removing old Java 17+ files..."
        remove_java17_files "$NEW_INSTANCE_DIR"
    else
        log_info "Step 4: Skipping Java 17+ file removal (not in Java 17 mode)"
    fi

    # Step 5: Extract archive
    log_info "Step 5: Extracting new client files..."
    local extract_dir="$TEMP_DIR/extracted"

    if [[ "$DRY_RUN" != true ]]; then
        mkdir -p "$extract_dir"
    fi

    extract_archive "$working_archive" "$extract_dir"

    # Find the .minecraft folder in extracted content
    local source_minecraft
    source_minecraft=$(find_minecraft_dir "$extract_dir")
    log_info "Found source .minecraft at: $source_minecraft"

    # Step 6: Install new folders
    log_info "Step 6: Installing new folders..."
    install_new_folders "$source_minecraft" "$NEW_INSTANCE_DIR/.minecraft"

    # Step 7: Install Java 17+ files if applicable
    if [[ "$JAVA17_MODE" == true ]]; then
        log_info "Step 7: Installing Java 17+ files..."
        local source_instance
        source_instance=$(find_instance_root "$extract_dir")
        install_java17_files "$source_instance" "$NEW_INSTANCE_DIR"
    else
        log_info "Step 7: Skipping Java 17+ file installation (not in Java 17 mode)"
    fi

    # Step 8: Update instance name
    log_info "Step 8: Updating instance configuration..."
    update_instance_name "$NEW_INSTANCE_DIR" "$NEW_INSTANCE_NAME"

    log_success "New instance files installed!"

    print_completion_message
}

# Run main function if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
