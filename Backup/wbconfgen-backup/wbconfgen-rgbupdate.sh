#!/usr/bin/env bash

# Paths
wallbash_pp="$HOME/.config/main/wallbash/raw-wallbash.dcol"
wallbash_target="$HOME/.config/main/wallbash/theme-rgba-wallbash.dcol"

# ----------------- Read Wallbash colors -----------------
declare -A wallbash

while IFS='=' read -r key val; do
    # skip empty lines
    [[ -z "$key" || -z "$val" ]] && continue
    wallbash["$key"]="$val"
done < "$wallbash_pp"

# ----------------- Update Kitty config -----------------
tmpfile=$(mktemp)

# Append theme lines using wallbash variables
{
    echo
    echo "dcol_pry1 = ${wallbash[dcol_rrggbb_1_rgba]}"
    echo "dcol_txt1 = ${wallbash[dcol_rrggbb_2_rgba]}"
    echo "dcol_1xa1 = ${wallbash[dcol_rrggbb_3_rgba]}"
    echo "dcol_1xa2 = ${wallbash[dcol_rrggbb_4_rgba]}"
    echo "dcol_1xa3 = ${wallbash[dcol_rrggbb_5_rgba]}"
    echo "dcol_1xa4 = ${wallbash[dcol_rrggbb_6_rgba]}"
    echo "dcol_1xa5 = ${wallbash[dcol_rrggbb_7_rgba]}"
    echo "dcol_1xa6 = ${wallbash[dcol_rrggbb_8_rgba]}"
    echo "dcol_1xa7 = ${wallbash[dcol_rrggbb_9_rgba]}"
    echo "dcol_1xa8 = ${wallbash[dcol_rrggbb_10_rgba]}"
    echo "dcol_1xa9 = ${wallbash[dcol_rrggbb_11_rgba]}"
   
    echo
    echo "dcol_pry2 = ${wallbash[dcol_rrggbb_12_rgba]}"
    echo "dcol_txt2 = ${wallbash[dcol_rrggbb_13_rgba]}"
    echo "dcol_2xa1 = ${wallbash[dcol_rrggbb_14_rgba]}"
    echo "dcol_2xa2 = ${wallbash[dcol_rrggbb_15_rgba]}"
    echo "dcol_2xa3 = ${wallbash[dcol_rrggbb_16_rgba]}"
    echo "dcol_2xa4 = ${wallbash[dcol_rrggbb_17_rgba]}"
    echo "dcol_2xa5 = ${wallbash[dcol_rrggbb_18_rgba]}"
    echo "dcol_2xa6 = ${wallbash[dcol_rrggbb_19_rgba]}"
    echo "dcol_2xa7 = ${wallbash[dcol_rrggbb_20_rgba]}"
    echo "dcol_2xa8 = ${wallbash[dcol_rrggbb_21_rgba]}"
    echo "dcol_2xa9 = ${wallbash[dcol_rrggbb_22_rgba]}"
   
    echo
    echo "dcol_pry3 = ${wallbash[dcol_rrggbb_23_rgba]}"
    echo "dcol_txt3 = ${wallbash[dcol_rrggbb_24_rgba]}"
    echo "dcol_3xa1 = ${wallbash[dcol_rrggbb_25_rgba]}"
    echo "dcol_3xa2 = ${wallbash[dcol_rrggbb_26_rgba]}"
    echo "dcol_3xa3 = ${wallbash[dcol_rrggbb_27_rgba]}"
    echo "dcol_3xa4 = ${wallbash[dcol_rrggbb_28_rgba]}"
    echo "dcol_3xa5 = ${wallbash[dcol_rrggbb_29_rgba]}"
    echo "dcol_3xa6 = ${wallbash[dcol_rrggbb_30_rgba]}"
    echo "dcol_3xa7 = ${wallbash[dcol_rrggbb_31_rgba]}"
    echo "dcol_3xa8 = ${wallbash[dcol_rrggbb_32_rgba]}"
    echo "dcol_3xa9 = ${wallbash[dcol_rrggbb_33_rgba]}"

    echo
    echo "dcol_pry4 = ${wallbash[dcol_rrggbb_34_rgba]}"
    echo "dcol_txt4 = ${wallbash[dcol_rrggbb_35_rgba]}"
    echo "dcol_4xa1 = ${wallbash[dcol_rrggbb_36_rgba]}"
    echo "dcol_4xa2 = ${wallbash[dcol_rrggbb_37_rgba]}"
    echo "dcol_4xa3 = ${wallbash[dcol_rrggbb_38_rgba]}"
    echo "dcol_4xa4 = ${wallbash[dcol_rrggbb_39_rgba]}"
    echo "dcol_4xa5 = ${wallbash[dcol_rrggbb_40_rgba]}"
    echo "dcol_4xa6 = ${wallbash[dcol_rrggbb_41_rgba]}"
    echo "dcol_4xa7 = ${wallbash[dcol_rrggbb_42_rgba]}"
    echo "dcol_4xa8 = ${wallbash[dcol_rrggbb_43_rgba]}"
    echo "dcol_4xa9 = ${wallbash[dcol_rrggbb_44_rgba]}"
    

} >> "$tmpfile"

# Replace original config safely
mv "$tmpfile" "$wallbash_target"

input="$HOME/.config/main/wallbash/theme-rgba-wallbash.dcol"
output="$HOME/.config/wallbash/theme-rgba.wallbash"

tmp=$(mktemp)

while IFS='=' read -r key val; do
    [[ -z "$key" || -z "$val" ]] && continue

    key="${key//[[:space:]]/}"
    val="${val//[[:space:]]/}"

    if [[ "$key" == dcol_* ]]; then
        new="wallbash_${key#dcol_}_rgb"
        echo "$new=$val" >> "$tmp"
    fi
done < "$input"

mv "$tmp" "$output"

echo "Converted: dcol_* → wallbash_rgba*"

