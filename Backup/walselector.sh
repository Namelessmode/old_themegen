#!/bin/bash
set -e

# ────────────────────────────────────────────────
# Configuration
WALL_DIR="$HOME/Pictures/wallpapers"
CACHE_DIR="$HOME/.cache/rofi-wallpapers"
mkdir -p "$CACHE_DIR"
BLURRED_DIR="$CACHE_DIR/blurred"
mkdir -p "$BLURRED_DIR"
ROFI_THEME="$HOME/.config/rofi/config-wallpaper.rasi"

# Blur & effect config
BLUR_FILE="$HOME/.config/walsec/blur.sh"
BLUR_DEFAULT="50x30"
[ -f "$BLUR_FILE" ] && BLUR=$(cat "$BLUR_FILE") || BLUR="$BLUR_DEFAULT"

# ────────────────────────────────────────────────
# Logging helper
log() { echo "[walsec] $1"; }

# ────────────────────────────────────────────────
# Apply wallpaper + blur + cache + color sync
apply_wallpaper() {
    local img="$1"
    if [ -z "$img" ] || [ ! -f "$img" ]; then
        notify-send "Invalid wallpaper" "File not found: $img"
        exit 1
    fi

    local base="$(basename "$img")"
    local cached_img="$CACHE_DIR/$base"

    case "$img" in
        *.gif)
            # Keep GIF, copy to cache for swww
            if [ ! -f "$cached_img" ]; then
                cp "$img" "$cached_img"
            fi
            img="$cached_img"
            ;;
        *)
            # Non-GIF, copy to cache if missing
            [ ! -f "$cached_img" ] && cp "$img" "$cached_img"
            img="$cached_img"
            ;;
    esac

    local blurred="$BLURRED_DIR/blurred-${base%.*}.png"
    local rasifile="$CACHE_DIR/current_wallpaper.rasi"

    # Apply wallpaper with transition (swww supports GIFs)
    log "Applying wallpaper: $img"
    swww img "$img" -t any --transition-bezier .43,1.19,1,.4 --transition-duration 1 --transition-fps 120
    sleep 0.8

    # Color sync
    wal -i "$img"
    matugen image "$img"
    sleep 0.1

    # Refresh apps that may cache colors
    (
    pkill -SIGUSR2 nautilus || true
    pkill -SIGUSR2 file-roller || true
    pkill -SIGUSR2 gnome-system-monitor || true
    pkill -SIGUSR2 gnome-disks || true
    nautilus --quit
    nautilus & disown
    ) & disown

    hyprctl reload

    pkill swaync 1>/dev/null || true
    swaync & disown
    pywalfox update

    # Generate blurred wallpaper (first frame if GIF)
    if [ ! -f "$blurred" ]; then
        log "Creating blurred wallpaper..."
        if [[ "$img" == *.gif ]]; then
            magick "$img[0]" -resize 75% "$blurred"
        else
            magick "$img" -resize 75% "$blurred"
        fi
        [ "$BLUR" != "0x0" ] && magick "$blurred" -blur "$BLUR" "$blurred"
    fi

    # Generate Rofi .rasi file for background blur
    echo "* { current-image: url(\"$blurred\", height); }" > "$rasifile"
   
    # Symlink Wallpaper to wlogout and Rofi
    ln -sf "$blurred" "$HOME/.config/wlogout/wallpaper_blurred.png"
    ln -sf "$img" "$HOME/.config/rofi/shared/current-wallpaper.png"

    pkill rofi 2>/dev/null || true

    notify-send "Wallpaper Theme applied" -i "$img"
    hyprctl reload
    ~/.config/hypr/scripts/cava-pywal.sh
}

# ────────────────────────────────────────────────
# Interactive wallpaper picker
choose_wallpaper() {
    mapfile -d '' files < <(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) -print0)

    menu() {
        for f in "${files[@]}"; do
            name=$(basename "$f")
            thumb="$CACHE_DIR/thumb-${name%.*}.png"

            if [ ! -f "$thumb" ]; then
                case "$f" in
                    *.gif) magick "$f[0]" -resize 400x225 "$thumb" ;;  # first frame
                    *)     magick "$f" -resize 400x225 "$thumb" ;;
                esac
            fi

            printf "%s\x00icon\x1f%s\n" "$name" "$thumb"
        done
    }

    choice=$(menu | rofi -dmenu -i -p "Wallpaper" -config "$ROFI_THEME" -theme-str 'element-icon{size:33%;}')
    [ -z "$choice" ] && exit 0
    apply_wallpaper "$WALL_DIR/$choice"
}

# ────────────────────────────────────────────────
# Main
if [ -n "$1" ]; then
    apply_wallpaper "$1"
else
    choose_wallpaper
fi

