#!/bin/bash

# lists all Devices and there IOMMU Groups in the same colour so can be easy read

# Array of color codes
colors=(
  "\033[0;31m" # Red
  "\033[0;32m" # Green
  "\033[0;33m" # Yellow
  "\033[0;34m" # Blue
  "\033[0;35m" # Magenta
  "\033[0;36m" # Cyan
  "\033[0;37m" # White
)

# Reset color
reset_color="\033[0m"

# Associative array to map groups to colors
declare -A group_colors

# Color index
color_index=0

for d in /sys/kernel/iommu_groups/*/devices/*; do
  # Extract group number
  n=${d#*/iommu_groups/*}
  n=${n%%/*}

  # Check if the group has been assigned a color
  if [ -z "${group_colors[$n]}" ]; then
    # Assign the current color to the group
    group_colors[$n]=${colors[color_index]}
    # Increment color index
    ((color_index = (color_index + 1) % ${#colors[@]}))
  fi

  # Select color for the current group
  color=${group_colors[$n]}

  # Print group number in color
  printf "${color}IOMMU Group %s ${reset_color}\n" "$n"

  # Print device information
  lspci -nns "${d##*/}"
done
