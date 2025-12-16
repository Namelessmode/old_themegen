#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# Configuration
# -----------------------
wbDir="${XDG_CONFIG_HOME:-$HOME/.config}/wallbash"
dcolDir="${1:-$wbDir/dcol}"
targetDir="${2:-${XDG_CACHE_HOME:-$HOME/.cache}/wal/wal-dir/}"
mkdir -p "$targetDir"

scrDir="$(dirname "$(realpath "$0")")"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}"
homDir="${XDG_HOME:-$HOME}"

# -----------------------
# Load palette files
# -----------------------
load_wallbash_file() {
    local file="$1"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" == *=* ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            [[ "$key" == *_hex || "$value" == \#* ]] && value="${value#\#}"
            export "$key=$value"
        fi
    done < "$file"
}

[[ -f "$wbDir/theme.wallbash" ]] && load_wallbash_file "$wbDir/theme.wallbash"
[[ -f "$wbDir/theme-rgba.wallbash" ]] && load_wallbash_file "$wbDir/theme-rgba.wallbash"

# -----------------------
# Template processing function
# -----------------------
process_template() {
    local template_file="$1"

    # Read first line and trim spaces
    read -r raw_first_line < "$template_file"
    local first_line
    first_line="$(printf "%s" "$raw_first_line" | sed 's/[[:space:]]*$//')"

    # Remove first line from template content
    local template_content
    template_content=$(<"$template_file")
    template_content="${template_content#*$'\n'}"

    # Determine target and optional script
    local target script=""
    if [[ "$first_line" == *"|"* ]]; then
        target="${first_line%%|*}"
        script="${first_line##*|}"
    elif [[ -n "$first_line" ]]; then
        target="$first_line"
    else
        rel="$(realpath --relative-to="$dcolDir" "$template_file")"
        target="$targetDir/${rel%.dcol}"
    fi

    # Expand special variables
    target="${target//\$(scrDir)/$scrDir}"
    target="${target//\$(confDir)/$confDir}"
    target="${target//\$(cacheDir)/$cacheDir}"
    target="${target//\$(homDir)/$homDir}"
    [[ -n "$script" ]] && script="${script//\$(scrDir)/$scrDir}"
    [[ -n "$script" ]] && script="${script//\$(confDir)/$confDir}"
    [[ -n "$script" ]] && script="${script//\$(cacheDir)/$cacheDir}"
    [[ -n "$script" ]] && script="${script//\$(homDir)/$homDir}"

    # Replace placeholders
    for var in $(compgen -v | grep '^wallbash_'); do
    value="${!var}"       # original value
    placeholder="<${var}>"

    # 1) Replace simple <wallbash_XXXX>
    template_content="${template_content//${placeholder}/${value}}"

    # 2) Replace <wallbash_XXXX_rgba>
    if [[ "$var" == *_rgba ]]; then
        placeholder_rgba="<${var}>"
        template_content="${template_content//${placeholder_rgba}/${value}}"

        # 3) Replace <wallbash_XXXX_rgba(X)>
        # Use regex to find all occurrences with optional alpha
        while [[ "$template_content" =~ \<${var}\(([0-9.]+)\)\> ]]; do
            alpha="${BASH_REMATCH[1]}"
            if [[ "$value" =~ rgba\(([0-9]+),([0-9]+),([0-9]+),([0-9.]+)\) ]]; then
                r="${BASH_REMATCH[1]}"
                g="${BASH_REMATCH[2]}"
                b="${BASH_REMATCH[3]}"
                template_content="${template_content//<${var}(${alpha})>/rgba($r,$g,$b,$alpha)}"
            else
                # Fallback: remove placeholder if badly formatted
                template_content="${template_content//<${var}(${alpha})>/$value}"
            fi
        done
    fi
done


    # -----------------------
    # Write template output
    # -----------------------
    mkdir -p "$(dirname "$target")"
    if [[ ! -f "$target" || "$(cat "$target")" != "$template_content" ]]; then
        printf "%s" "$template_content" > "$target" 
        echo "Generated: $target"
    else
        echo "Skipped (unchanged): $target"
    fi

    # -----------------------
    # Execute optional script safely
    # -----------------------
    if [[ -n "$script" ]]; then
        # Inline commands prefixed with $RUN:
        if [[ "$script" == \$RUN:* ]]; then
            bash -c "${script#\$RUN:}"
        # Executable file
        elif [[ -x "$script" ]]; then
            "$script"
        else
            echo "Skipped non-executable script: $script"
        fi
    fi
}

export -f process_template
export scrDir confDir cacheDir targetDir homDir dcolDir
for var in $(compgen -v | grep '^wallbash_'); do export "$var"; done

# -----------------------
# Run templates in parallel
# -----------------------
find "$dcolDir" -type f -name '*.dcol' -print0 \
    | xargs -0 -n 1 -P "$(nproc)" bash -c 'process_template "$@"' _
