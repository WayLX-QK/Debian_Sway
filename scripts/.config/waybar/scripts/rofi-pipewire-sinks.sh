#!/usr/bin/env bash

# Function to parse wpctl status for sinks
parse_wpctl_sinks() {
    local output
    local section_found=false
    local items=()
    local id_name_map=()
    local default_id=""

    # Get wpctl status output and clean it
    output=$(wpctl status | tr -d '├─│└')

    # Read line by line and process
    while IFS= read -r line; do
        # Check if we found the sinks section
        if [[ "$line" == *"Sinks:"* ]]; then
            section_found=true
            continue
        fi

        # If we're in the section, process items
        if [[ "$section_found" == true ]]; then
            # Stop if we hit an empty line (end of section)
            if [[ -z "${line// }" ]]; then
                break
            fi

            # Clean the line
            clean_line=$(echo "$line" | sed 's/\[vol:.*$//' | xargs)

            # Skip if line doesn't contain a numbered item
            if [[ ! "$clean_line" =~ ^[*[:space:]]*[0-9]+\. ]]; then
                continue
            fi

            # Extract ID and name
            if [[ "$clean_line" =~ ^([*[:space:]]*)([0-9]+)\.[[:space:]]*(.+)$ ]]; then
                local prefix="${BASH_REMATCH[1]}"
                local sink_id="${BASH_REMATCH[2]}"
                local sink_name="${BASH_REMATCH[3]}"

                # Store ID->name mapping
                id_name_map+=("$sink_name:$sink_id")

                # Check if it's the default (starts with *)
                if [[ "$prefix" == *"*"* ]]; then
                    items+=("-> $sink_name")
                    default_id="$sink_id"
                else
                    items+=("$sink_name")
                fi
            fi
        fi
    done <<< "$output"

    # Return results via global arrays
    parsed_items=("${items[@]}")
    parsed_id_map=("${id_name_map[@]}")
    parsed_default_id="$default_id"
}

# Function to show rofi menu
show_rofi_menu() {
    local prompt="$1"
    shift
    local items=("$@")

    printf '%s\n' "${items[@]}" | rofi -dmenu \
        -location 3 \
        -theme-str "window {width: 24%; height: 30%; x-offset: -10px; y-offset: 10px; border-radius: 15px;}" \
        -hover-select \
        -me-select-entry "" \
        -me-accept-entry "MousePrimary" \
        -p "$prompt"
}

# Function to get ID from name using the mapping
get_id_from_name() {
    local name="$1"
    local clean_name="${name#-> }"  # Remove "-> " prefix if present

    for mapping in "${parsed_id_map[@]}"; do
        if [[ "$mapping" == "$clean_name:"* ]]; then
            echo "${mapping#*:}"
            return 0
        fi
    done
    return 1
}

# Main function to manage sinks
main() {
    while true; do
        parse_wpctl_sinks

        if [[ ${#parsed_items[@]} -eq 0 ]]; then
            echo "No sinks available."
            exit 1
        fi

        local menu_items=("${parsed_items[@]}" "Exit")
        selected_sink=$(show_rofi_menu "Select Sink:" "${menu_items[@]}")

        case "$selected_sink" in
            "Exit"|"")
                exit 0
                ;;
            *)
                if [[ -n "$selected_sink" ]]; then
                    sink_id=$(get_id_from_name "$selected_sink")

                    if [[ -z "$sink_id" ]]; then
                        echo "Error: Could not find ID for selected sink."
                        exit 1
                    fi

                    # Check if already default
                    if [[ "$sink_id" == "$parsed_default_id" ]]; then
                        echo "$selected_sink is already the default sink."
                        exit 0
                    fi

                    wpctl set-default "$sink_id"
                    echo "Set $selected_sink as default sink."
                    exit 0
                fi
                ;;
        esac
    done
}

# Global arrays for parsed data
declare -a parsed_items
declare -a parsed_id_map
declare parsed_default_id

# Check if required commands exist
if ! command -v wpctl &> /dev/null; then
    echo "Error: wpctl command not found. Please install wireplumber."
    exit 1
fi

if ! command -v rofi &> /dev/null; then
    echo "Error: rofi command not found. Please install rofi."
    exit 1
fi

# Run main function
main
