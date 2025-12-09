#!/usr/bin/env bash
set -euo pipefail

# ---------- Config ----------
OUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config/main}/wallbash"
wallbash_cDot="${XDG_CACHE_HOME:-$HOME/.cache}/wallbash"
scrDir="$(dirname "$(realpath "$0")")"


if [[ -f ${OUT_DIR} ]]; then
  :
else
  mkdir -p "$OUT_DIR"
fi

wallbashImg="${1:-}"
if [ -z "$wallbashImg" ] || [ ! -f "$wallbashImg" ]; then
  printf 'Error: wallpaper missing or not found\n' >&2
  exit 2
fi

if [[ -f ${wallbash_cDot} ]]; then
  :
else
  mkdir -p "$wallbash_cDot"
fi

wallhash=$(md5sum "$wallbashImg" | awk '{print $1}')
wbconfcache="$wallbash_cDot/wallbash-${wallhash}.dcol"

if [[ -f $wbconfcache ]]; then
  echo "Cache found: restoring wallpaper colors"
  cp "$wbconfcache" "${OUT_DIR}/raw-wallbash.dcol"
  {
    $scrDir/modules/wbconfgen-update.sh
    $scrDir/modules/wbconfgen-rgbupdate.sh
    
      parallel_scripts=(
        "$scrDir/modules/wbconfgen-kitty.sh"
        "$scrDir/modules/wbconfgen-hypr.sh"
        "$scrDir/modules/wbconfgen-gtk.sh"
        "$scrDir/modules/wbconfgen-pyfox.sh"
        "$scrDir/modules/wbconfgen-discordtheme.sh"
        "$scrDir/modules/wbconfgen-cava.sh"
        "$scrDir/modules/wbconfgen-waybar.sh"
      )
    for scr in "${parallel_scripts[@]}"; do
      bash "$scr" &
    done
    wait
  }
  exit 0
fi

# default profile & curve
colorProfile="default"
wallbashCurve="32 50
42 46
49 40
56 39
64 38
76 37
90 33
94 29
100 20"
sortMode="auto"
colSort=""

# tuneables
wallbashColors=4        # number of primary bases (pry1..pry4)
wallbashFuzz=70        # fuzz for kmeans color quantization
pryDarkBri=116
pryDarkSat=110
pryDarkHue=88
pryLightBri=100
pryLightSat=100
pryLightHue=114
txtDarkBri=188
txtLightBri=16

# ---------- helper functions ----------
rgba_convert_hex() {
  # input: HEX without #
  local inCol=$1
  local r=${inCol:0:2}
  local g=${inCol:2:2}
  local b=${inCol:4:2}
  local r16=$((16#$r))
  local g16=$((16#$g))
  local b16=$((16#$b))
  printf 'rgba(%d,%d,%d,1)\n' "$r16" "$g16" "$b16"
}

rgb_negative_hex() {
  # input: HEX without #
  local inCol=$1
  local r=${inCol:0:2}
  local g=${inCol:2:2}
  local b=${inCol:4:2}
  local r16=$((16#$r))
  local g16=$((16#$g))
  local b16=$((16#$b))
  r=$(printf "%02X" $((255 - r16)))
  g=$(printf "%02X" $((255 - g16)))
  b=$(printf "%02X" $((255 - b16)))
  printf "%s%s%s" "$r" "$g" "$b"
}

fx_brightness_img() {
  # returns 0 if dark (mean < 0.5), 1 otherwise
  local imgref="$1"
  local fxb
  fxb=$(magick "$imgref" -colorspace gray -format "%[fx:mean]" info: 2>/dev/null || echo 0.0)
  awk -v fxb="$fxb" 'BEGIN { exit !(fxb < 0.5) }'
}

# ---------- quantize and pick primary bases ----------
wallbashRaw="$(mktemp --tmpdir="${TMPDIR:-/tmp}" wallbash.XXXXXX.mpc)"
trap 'rm -f "$wallbashRaw"' EXIT

magick -quiet -regard-warnings "${wallbashImg}"[0] -alpha off +repage "$wallbashRaw"

# produce histogram and top N colors (format: "count,HEX")
readarray -t dcolRaw < <(
  magick "$wallbashRaw" -depth 8 -fuzz ${wallbashFuzz}% +dither -kmeans ${wallbashColors} -depth 8 -format "%c" histogram:info: \
  | sed -n 's/^[[:space:]]*\([0-9]\+\):.*#\([0-9A-Fa-f]\+\).*$/\1,\2/p' \
  | sort -r -n -k 1 -t ","
)

# if not enough colors found, try larger kmeans
if [ "${#dcolRaw[@]}" -lt "$wallbashColors" ]; then
  readarray -t dcolRaw < <(
    magick "$wallbashRaw" -depth 8 -fuzz ${wallbashFuzz}% +dither -kmeans $((wallbashColors + 4)) -depth 8 -format "%c" histogram:info: \
    | sed -n 's/^[[:space:]]*\([0-9]\+\):.*#\([0-9A-Fa-f]\+\).*$/\1,\2/p' \
    | sort -r -n -k 1 -t ","
  )
fi

# determine auto brightness sort mode (dark/light)
if [ "$sortMode" = "auto" ]; then
  if fx_brightness_img "$wallbashRaw"; then
    sortMode="dark"; colSort=""
  else
    sortMode="light"; colSort="-r"
  fi
fi

# get hex list (top wallbashColors)
mapfile -t dcolHex < <(printf '%s\n' "${dcolRaw[@]:0:$wallbashColors}" | awk -F',' '{print $2}' | sort $colSort)

# fallback: if still missing, duplicate nearest
while [ "${#dcolHex[@]}" -lt "$wallbashColors" ]; do
  local_last_index=$(( ${#dcolHex[@]} - 1 ))
  dcolHex+=("${dcolHex[$local_last_index]}")
done

# if image is very gray, choose mono curve
greyCheck=$(magick "$wallbashRaw" -colorspace HSL -channel g -separate +channel -format "%[fx:mean]" info:)
if awk -v g="$greyCheck" 'BEGIN{exit !(g < 0.12)}'; then
  wallbashCurve="10 0
17 0
24 0
39 0
51 0
58 0
72 0
84 0
99 0"
fi

# ---------- write temporary dcol outputs ----------
tmp_sh="$(mktemp --tmpdir="${TMPDIR:-/tmp}" wbconfgen-colors.XXXXXX.sh)"
: > "$tmp_sh"

cat > "$tmp_sh" <<'EOF'
#!/usr/bin/env bash
# auto-generated color slots — source this file
# provides variables: dcol_rrggbb_1 ... dcol_rrggbb_44
EOF

# helper to write a slot
slot_write() {
  local idx="$1" hex="$2"
  # strip leading # and uppercase
  hex="${hex#\#}"
  hex="${hex^^}"
  local var="dcol_rrggbb_${idx}"
  local rgba
  rgba=$(rgba_convert_hex "$hex")
  printf '%s=%s\n' "$var" "#$hex" >>"$tmp_sh"
  printf '%s_rgba=%s\n' "${var}" "$rgba" >>"$tmp_sh"
}

# loop modules (0..wallbashColors-1)
for ((i=0;i<wallbashColors;i++)); do
  base_hex="${dcolHex[i]#\#}"
  base_hex="${base_hex^^}"
  base_slot=$((1 + i*11))    
  txt_slot=$((base_slot + 1))

  # ensure base_hex set (fallback)
  if [ -z "${base_hex}" ]; then
    base_hex="000000"
  fi

  # write base
  slot_write "$base_slot" "$base_hex"

  # generate text color: negative + modulate (deterministic)
  nTxt="$(rgb_negative_hex "$base_hex")"
  if fx_brightness_img "xc:#${base_hex}" ; then
    modBri=$txtDarkBri
  else
    modBri=$txtLightBri
  fi
  tcol=$(magick xc:"#${nTxt}" -depth 8 -normalize -modulate ${modBri},10,100 -depth 8 -format "%c" histogram:info: \
         | sed -n 's/^[[:space:]]*[0-9]\+:[^#]*#\([0-9A-Fa-f]\+\).*$/\1/p' | head -n1)
  tcol="${tcol:-$nTxt}"
  slot_write "$txt_slot" "$tcol"

  # compute hue of base (0-360). If magick cannot parse, fallback to 0.
  xHue=$(magick xc:"#${base_hex}" -colorspace HSB -format "%c" histogram:info: 2>/dev/null | awk -F '[hsb(,]' '{print $2}' | head -n1 || echo 0)
  xHue="${xHue:-0}"

  # write 9 accents according to curve
  acnt=1
  if [ -n "$colSort" ]; then
    mapfile -t curve_lines < <(printf '%s\n' "$wallbashCurve" | tac)
  else
    mapfile -t curve_lines < <(printf '%s\n' "$wallbashCurve")
  fi

  for cl in "${curve_lines[@]}"; do
    [ -z "$cl" ] && continue
    xBri=$(awk '{print $1}' <<<"$cl")
    xSat=$(awk '{print $2}' <<<"$cl")
    acol=$(magick xc:"hsb(${xHue},${xSat}%,${xBri}%)" -depth 8 -format "%c" histogram:info: \
         | sed -n 's/^[[:space:]]*[0-9]\+:[^#]*#\([0-9A-Fa-f]\+\).*$/\1/p' | head -n1)
    acol="${acol:-000000}"
    acc_slot=$((base_slot + 1 + acnt))  # base+2..base+10
    slot_write "$acc_slot" "$acol"
    acnt=$((acnt+1))
    [ "$acnt" -gt 9 ] && break
  done
done

# ensure all 44 slots set: fill missing deterministically (repeat base for module)
for idx in $(seq 1 44); do
  if ! grep -q "^dcol_rrggbb_${idx}=" "$tmp_sh"; then
    if [ "$idx" -le 11 ]; then fallback=1
    elif [ "$idx" -le 22 ]; then fallback=12
    elif [ "$idx" -le 33 ]; then fallback=23
    else fallback=34
    fi
    baseval=$(grep "^dcol_rrggbb_${fallback}=" "$tmp_sh" | head -n1 | sed -E 's/^dcol_rrggbb_[0-9]+="([^"]+)".*$/\1/')
    if [ -z "$baseval" ]; then baseval="#000000"; fi
    printf 'dcol_rrggbb_%d=%s\n' "$idx" "$baseval" >>"$tmp_sh"
    printf 'dcol_rrggbb_%d_rgba=%s\n' "$idx" "$(rgba_convert_hex "${baseval##"#"}")" >>"$tmp_sh"
  fi
done

mv "$tmp_sh" "$wbconfcache"
cp "$wbconfcache" "${OUT_DIR}/raw-wallbash.dcol"
# ---------- write merged wallbash.dcol mapping (sourceable) ----------
if [[ -f ${OUT_DIR}/theme-wallbash.dcol ]]; then
  :
else
  $scrDir/walgen-temp.sh
fi


printf 'WROTE:\n  %s\n  %s\n' "${OUT_DIR}/raw-wallbash.dcol" 
printf '\nTo use in your environment: This will provide variables: dcol_pry1, dcol_txt1, dcol_1xa1 ... dcol_4xa9\n' "$OUT_DIR"
  {
    $scrDir/modules/wbconfgen-update.sh
    $scrDir/modules/wbconfgen-rgbupdate.sh
    
      parallel_scripts=(
        "$scrDir/modules/wbconfgen-kitty.sh"
        "$scrDir/modules/wbconfgen-hypr.sh"
        "$scrDir/modules/wbconfgen-gtk.sh"
        "$scrDir/modules/wbconfgen-pyfox.sh"
        "$scrDir/modules/wbconfgen-discordtheme.sh"
        "$scrDir/modules/wbconfgen-cava.sh"
        "$scrDir/modules/wbconfgen-waybar.sh"
      )
    for scr in "${parallel_scripts[@]}"; do
      bash "$scr" &
    done
    wait
  }
exit 0



 
