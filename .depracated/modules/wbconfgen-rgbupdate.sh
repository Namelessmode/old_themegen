#!/usr/bin/env bash

# Paths
wallbash_pp="$HOME/.config/wallbash/main/raw-wallbash.dcol"
wallbash_target="$HOME/.config/wallbash/theme-rgba.wallbash"

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
    echo "wallbash_pry1_rgba=${wallbash[dcol_rrggbb_1_rgba]}"
    echo "wallbash_txt1_rgba=${wallbash[dcol_rrggbb_2_rgba]}"
    echo "wallbash_1xa1_rgba=${wallbash[dcol_rrggbb_3_rgba]}"
    echo "wallbash_1xa2_rgba=${wallbash[dcol_rrggbb_4_rgba]}"
    echo "wallbash_1xa3_rgba=${wallbash[dcol_rrggbb_5_rgba]}"
    echo "wallbash_1xa4_rgba=${wallbash[dcol_rrggbb_6_rgba]}"
    echo "wallbash_1xa5_rgba=${wallbash[dcol_rrggbb_7_rgba]}"
    echo "wallbash_1xa6_rgba=${wallbash[dcol_rrggbb_8_rgba]}"
    echo "wallbash_1xa7_rgba=${wallbash[dcol_rrggbb_9_rgba]}"
    echo "wallbash_1xa8_rgba=${wallbash[dcol_rrggbb_10_rgba]}"
    echo "wallbash_1xa9_rgba=${wallbash[dcol_rrggbb_11_rgba]}"
   
    echo
    echo "wallbash_pry2_rgba=${wallbash[dcol_rrggbb_12_rgba]}"
    echo "wallbash_txt2_rgba=${wallbash[dcol_rrggbb_13_rgba]}"
    echo "wallbash_2xa1_rgba=${wallbash[dcol_rrggbb_14_rgba]}"
    echo "wallbash_2xa2_rgba=${wallbash[dcol_rrggbb_15_rgba]}"
    echo "wallbash_2xa3_rgba=${wallbash[dcol_rrggbb_16_rgba]}"
    echo "wallbash_2xa4_rgba=${wallbash[dcol_rrggbb_17_rgba]}"
    echo "wallbash_2xa5_rgba=${wallbash[dcol_rrggbb_18_rgba]}"
    echo "wallbash_2xa6_rgba=${wallbash[dcol_rrggbb_19_rgba]}"
    echo "wallbash_2xa7_rgba=${wallbash[dcol_rrggbb_20_rgba]}"
    echo "wallbash_2xa8_rgba=${wallbash[dcol_rrggbb_21_rgba]}"
    echo "wallbash_2xa9_rgba=${wallbash[dcol_rrggbb_22_rgba]}"
   
    echo
    echo "wallbash_pry3_rgba=${wallbash[dcol_rrggbb_23_rgba]}"
    echo "wallbash_txt3_rgba=${wallbash[dcol_rrggbb_24_rgba]}"
    echo "wallbash_3xa1_rgba=${wallbash[dcol_rrggbb_25_rgba]}"
    echo "wallbash_3xa2_rgba=${wallbash[dcol_rrggbb_26_rgba]}"
    echo "wallbash_3xa3_rgba=${wallbash[dcol_rrggbb_27_rgba]}"
    echo "wallbash_3xa4_rgba=${wallbash[dcol_rrggbb_28_rgba]}"
    echo "wallbash_3xa5_rgba=${wallbash[dcol_rrggbb_29_rgba]}"
    echo "wallbash_3xa6_rgba=${wallbash[dcol_rrggbb_30_rgba]}"
    echo "wallbash_3xa7_rgba=${wallbash[dcol_rrggbb_31_rgba]}"
    echo "wallbash_3xa8_rgba=${wallbash[dcol_rrggbb_32_rgba]}"
    echo "wallbash_3xa9_rgba=${wallbash[dcol_rrggbb_33_rgba]}"

    echo
    echo "wallbash_pry4_rgba=${wallbash[dcol_rrggbb_34_rgba]}"
    echo "wallbash_txt4_rgba=${wallbash[dcol_rrggbb_35_rgba]}"
    echo "wallbash_4xa1_rgba=${wallbash[dcol_rrggbb_36_rgba]}"
    echo "wallbash_4xa2_rgba=${wallbash[dcol_rrggbb_37_rgba]}"
    echo "wallbash_4xa3_rgba=${wallbash[dcol_rrggbb_38_rgba]}"
    echo "wallbash_4xa4_rgba=${wallbash[dcol_rrggbb_39_rgba]}"
    echo "wallbash_4xa5_rgba=${wallbash[dcol_rrggbb_40_rgba]}"
    echo "wallbash_4xa6_rgba=${wallbash[dcol_rrggbb_41_rgba]}"
    echo "wallbash_4xa7_rgba=${wallbash[dcol_rrggbb_42_rgba]}"
    echo "wallbash_4xa8_rgba=${wallbash[dcol_rrggbb_43_rgba]}"
    echo "wallbash_4xa9_rgba=${wallbash[dcol_rrggbb_44_rgba]}"
    

} >> "$tmpfile"

# Replace original config safely
mv "$tmpfile" "$wallbash_target"

echo "Converted: dcol_* → wallbash_*"






