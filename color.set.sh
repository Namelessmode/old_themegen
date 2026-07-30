#!/usr/bin/env bash
[[ $HYDE_SHELL_INIT -ne 1 ]] && eval "$(hyde-shell init)"
[[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] && {
    hyprctl keyword misc:disable_autoreload 1 -q
    trap "hyprctl reload config-only -q" EXIT
}

rgba_to_rgb() {
    local rgba_str=$1
    local r g b

    if [[ $rgba_str =~ rgba\(([0-9]+),([0-9]+),([0-9]+), ]]; then
        r=${BASH_REMATCH[1]}
        g=${BASH_REMATCH[2]}
        b=${BASH_REMATCH[3]}

        printf '%s,%s,%s' "$r" "$g" "$b"
    fi
}

load_dconf_kdeglobals() {
    source "$LIB_DIR/hyde/color/hypr.sh"
    source "$LIB_DIR/hyde/color/dconf.sh"
    toml_write "$XDG_CONFIG_HOME/kdeglobals" "Colors:View" "BackgroundNormal" "#${dcol_pry1:-000000}FF"
    toml_write "$XDG_CONFIG_HOME/Kvantum/wallbash/wallbash.kvconfig" '%General' 'reduce_menu_opacity' 0
    [[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] && shaders.sh reload
}

export_wallbash_variables() {
    local use_inverted=$1
    local sed_script

    wallbash_mode=$($use_inverted && echo "${dcol_invt:-light}" || echo "${dcol_mode:-dark}")

    for i in {1..4}; do
        local src_i=$i

        if $use_inverted; then
            src_i=$((5 - i))
        fi

        local pry_var="dcol_pry$src_i"
        local txt_var="dcol_txt$src_i"
        local pry_rgba_var="dcol_pry${src_i}_rgba"
        local txt_rgba_var="dcol_txt${src_i}_rgba"
        local pry_rgb_var="dcol_pry${src_i}_rgb"
        local txt_rgb_var="dcol_txt${src_i}_rgb"

        if [[ -n ${!pry_rgba_var:-} && -z ${!pry_rgb_var:-} ]]; then
            declare -g "$pry_rgb_var=$(rgba_to_rgb "${!pry_rgba_var}")"
        fi

        if [[ -n ${!txt_rgba_var:-} && -z ${!txt_rgb_var:-} ]]; then
            declare -g "$txt_rgb_var=$(rgba_to_rgb "${!txt_rgba_var}")"
        fi

        export "wallbash_pry$i=${!pry_var:-}"
        export "wallbash_txt$i=${!txt_var:-}"
        export "wallbash_pry${i}_rgba=${!pry_rgba_var:-}"
        export "wallbash_txt${i}_rgba=${!txt_rgba_var:-}"
        export "wallbash_pry${i}_rgb=${!pry_rgb_var:-}"
        export "wallbash_txt${i}_rgb=${!txt_rgb_var:-}"

        for j in {1..9}; do
            local xa_var="dcol_${src_i}xa$j"
            local xa_rgba_var="dcol_${src_i}xa${j}_rgba"
            local xa_rgb_var="dcol_${src_i}xa${j}_rgb"

            if [[ -n ${!xa_rgba_var:-} && -z ${!xa_rgb_var:-} ]]; then
                declare -g "$xa_rgb_var=$(rgba_to_rgb "${!xa_rgba_var}")"
            fi

            export "wallbash_${i}xa$j=${!xa_var:-}"
            export "wallbash_${i}xa${j}_rgba=${!xa_rgba_var:-}"
            export "wallbash_${i}xa${j}_rgb=${!xa_rgb_var:-}"
        done
    done
    export HOME
}

scrDir="$(dirname "$(realpath "$0")")"
export scrDir
source "$scrDir/globalcontrol.sh"
confDir="${XDG_CONFIG_HOME:-$(xdg-user-dir CONFIG)}"
wallbash_image="$1"
dcol_colors=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --dcol)
        dcol_colors="$2"
        if [ -f "$dcol_colors" ]; then
            printf "[Source] %s\n" "$dcol_colors"
            source "$dcol_colors"
            shift 2
        else
            dcol_colors="$(find -H "$dcolDir" -type f -name "*.dcol" | shuf -n 1)"
            printf "[Dcol Colors] %s\n" "$dcol_colors"
            shift
        fi
        ;;
    --wall)
        wallbash_image="$2"
        shift 2
        ;;
    --single)
        [ -f "$wallbash_image" ] || wallbash_image="$cacheDir/wall.set"
        single_template="$2"
        printf "[wallbash] Single template: %s\n" "$single_template"
        printf "[wallbash] Wallpaper: %s\n" "$wallbash_image"
        shift 2
        ;;
    -*)
        printf "Usage: %s [--dcol <mode>] [--wall <image>] [--single] [--mode <mode>] [--help]\n" "$0"
        exit 0
        ;;
    *) break ;;
    esac
done

if [ -z "$wallbash_image" ] || [ ! -f "$wallbash_image" ]; then
    printf "Error: Input wallpaper not found!\n"
    exit 1
fi

dcol_file="$dcolDir/$(set_hash "$wallbash_image").dcol"

if [ ! -f "$dcol_file" ]; then
    source "$scrDir/wallpaper/cache.sh" commence -w "$wallbash_image" &>/dev/null
fi

set -a

source "$dcol_file"
if [ -f "$HYDE_THEME_DIR/theme.dcol" ] && [ "$enableWallDcol" -eq 0 ]; then
    source "$HYDE_THEME_DIR/theme.dcol"
    print_log -sec "wallbash" -stat "override" "dominant colors from $HYDE_THEME theme"
    print_log -sec "wallbash" -stat " NOTE" "Remove \"$HYDE_THEME_DIR/theme.dcol\" to use wallpaper dominant colors"
fi

[ "$dcol_mode" == "dark" ] && dcol_invt="light" || dcol_invt="dark"

set +a

revert_colors=0
[ "$enableWallDcol" -eq 0 ] && {
    grep -q "$dcol_mode" <<<"$(get_hyprConf "COLOR_SCHEME")" || revert_colors=1
}
export revert_colors

use_inverted=false
if [[ ${revert_colors:-0} -eq 1 ]] || [[ ${enableWallDcol:-0} -eq 2 && ${dcol_mode:-} == "light" ]] || [[ ${enableWallDcol:-0} -eq 3 && ${dcol_mode:-} == "dark" ]]; then
    use_inverted=true
fi

export_wallbash_variables "$use_inverted"
print_log -sec "wallbash" -stat "exported" "color substitutions to environment"

load_dconf_kdeglobals

# Export configurations globally

WALLBASH_DIRS=""
for dir in "${wallbashDirs[@]}"; do
    [ -d "$dir" ] || wallbashDirs=("${wallbashDirs[@]//$dir/}")
    [ -d "$dir" ] && WALLBASH_DIRS+="$dir:"
done
WALLBASH_DIRS="${WALLBASH_DIRS%:}"

for dir in "${wallbashDirs[@]}"; do
    if [[ -d "$dir/scripts" ]]; then
        export WALLBASH_SCRIPTS="$dir/scripts"
        break
    elif [[ $dir == */wallbash* && -d "${dir%%/wallbash/*}/wallbash/scripts" ]]; then
        export WALLBASH_SCRIPTS="${dir%%/wallbash/*}/wallbash/scripts"
        break
    fi
done

export wallbashScripts="${WALLBASH_SCRIPTS:-}"

# Safely expand PATH to ensure utilities like `spicetify` and `cava` are discovered by hook workers
for custom_path in "$HOME/.local/bin" "$HOME/.spicetify" "$HOME/.local/share/spicetify-cli" "$HOME/.cargo/bin"; do
    if [[ -d "$custom_path" && ":$PATH:" != *":$custom_path:"* ]]; then
        PATH="$custom_path:$PATH"
    fi
done

export confDir hydeConfDir cacheDir thmbDir dcolDir iconsDir themesDir fontsDir wallbashDirs enableWallDcol HYDE_THEME_DIR HYDE_THEME GTK_ICON GTK_THEME CURSOR_THEME COLOR_SCHEME
export WALLBASH_DIRS PATH
export -f pkg_installed print_log rgba_to_rgb

if [ -n "$dcol_colors" ]; then
    set -a
    source "$dcol_colors"
    print_log -sec "wallbash" -stat "single instance" "Wallbash Colors: $dcol_colors"
    set +a

    # Re-evaluating exports after sourcing dcol injects
    export_wallbash_variables "$use_inverted"
fi

tmq_procs=$(nproc 2>/dev/null || echo 1)

# Handle Execution & Templates
if [ -n "$single_template" ]; then
    skip_single=0
    for skip in "${WALLBASH_SKIP_TEMPLATE[@]:-}"; do
        if [[ -n "$skip" && "$single_template" =~ $skip ]]; then
            skip_single=1
            print_log -sec "wallbash" -warn "skip '$skip' template " "Template: $single_template"
            break
        fi
    done

    if [[ $single_template == */wallbash/* ]]; then
        export WALLBASH_SCRIPTS="${single_template%%/wallbash/*}/wallbash/scripts"
        export wallbashScripts="$WALLBASH_SCRIPTS"
    fi

    if [[ $skip_single -eq 0 ]]; then
        "$scrDir/tmq.write.sh" \
            --proc "$tmq_procs" \
            --file "$single_template" \
            --no-atomic \
            --ignore-unbound
    fi
    exit 0
fi

[ -t 1 ] && "$scrDir/wallbash.print.colors.sh"
print_log -sec "wallbash" -stat "wallbash directories" " $WALLBASH_DIRS"

declare -a tmq_files=()

if [ "$enableWallDcol" -eq 0 ] && [[ $reload_flag -eq 1 ]]; then
    print_log -sec "wallbash" -stat "apply $dcol_mode colors" "$HYDE_THEME theme"
    mapfile -d '' -t deployList < <(find -H "$HYDE_THEME_DIR" -type f -name "*.theme" -print0)
    while read -r pKey; do
        fKey="$(find -H "$HYDE_THEME_DIR" -type f -name "$(basename "${pKey%.dcol}.theme")")"
        [ -z "$fKey" ] && deployList+=("$pKey")
    done < <(find -H "${wallbashDirs[@]}" -type f -path "*/theme*" -name "*.dcol" 2>/dev/null | awk '!seen[substr($0, match($0, /[^/]+$/))]++')

    tmq_files+=("${deployList[@]}")
elif [ "$enableWallDcol" -gt 0 ]; then
    print_log -sec "wallbash" -stat "apply $dcol_mode colors" "Wallbash theme"
    mapfile -t deployList < <(find -H "${wallbashDirs[@]}" -type f -path "*/theme*" -name "*.dcol" 2>/dev/null | awk '!seen[substr($0, match($0, /[^/]+$/))]++')

    tmq_files+=("${deployList[@]}")
fi

mapfile -t alwaysList < <(find -H "${wallbashDirs[@]}" -type f -path "*/always*" -name "*.dcol" 2>/dev/null | awk '!seen[substr($0, match($0, /[^/]+$/))]++')
tmq_files+=("${alwaysList[@]}")

# Filter the aggregated template list rigorously
declare -a final_tmq_files=()
for t in "${tmq_files[@]}"; do
    skip_this=0
    for skip in "${WALLBASH_SKIP_TEMPLATE[@]:-}"; do
        if [[ -n "$skip" && "$t" =~ $skip ]]; then
            skip_this=1
            print_log -sec "wallbash" -warn "skip '$skip' template " "Template: $t"
            break
        fi
    done
    [[ $skip_this -eq 0 ]] && final_tmq_files+=("$t")
done

if [[ ${#final_tmq_files[@]} -gt 0 ]]; then
    # Spin up tmq.write.sh, bypassing the deprecated parallel fn_wallbash invocation
    # NOTE: --ignore-unbound has been removed to prevent fatal process crashes on fallback tags
    "$scrDir/tmq.write.sh" \
        --proc "$tmq_procs" \
        --file "${final_tmq_files[@]}" \
        --no-atomic \
        --ignore-unbound || true
fi
