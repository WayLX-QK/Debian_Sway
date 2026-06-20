#!/usr/bin/env python 
import subprocess
import sys

def parse_wpctl_status(section):
    output = str(subprocess.check_output("wpctl status", shell=True, encoding='utf-8'))
    lines = output.replace("├", "").replace("─", "").replace("│", "").replace("└", "").splitlines()

    section_index = None
    for index, line in enumerate(lines):
        if section in line:
            section_index = index
            break

    items = []
    for line in lines[section_index + 1:]:
        if not line.strip():
            break
        items.append(line.strip())

    processed_items = []
    id_name_map = {}  # Dictionary to map IDs to names
    default_id = None  # Variable to store the default ID
    for item in items:
        clean_item = item.split("[vol:")[0].strip()  # Remove volume info
        # Extract ID and name
        parts = clean_item.split(". ", 1)
        if len(parts) == 2:
            sink_id = parts[0].strip()  # The ID part
            sink_name = parts[1].strip()  # The name part
            id_name_map[sink_name] = sink_id  # Map name to ID
            # Check if it's the default item
            if clean_item.startswith("*"):
                processed_items.append(f"-> {sink_name}")  # Mark as default
                default_id = sink_id  # Store the default ID
            else:
                processed_items.append(sink_name)  # Just add the item

    return processed_items, id_name_map, default_id

def show_rofi_menu(items, prompt="Select:"):
    rofi_command = ["rofi", "-dmenu", "-location", "3", "-theme-str", "window {width: 24%; height: 30%; x-offset: -10px; y-offset: 10px; border-radius: 15px;}", "-hover-select", "-me-select-entry", "", "-me-accept-entry", "MousePrimary", "-p", prompt]
    process = subprocess.Popen(rofi_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, _ = process.communicate("\n".join(items).encode())
    return output.decode().strip()

def manage_sinks():
    while True:
        sinks, id_name_map, default_id = parse_wpctl_status("Sinks:")
        if sinks:
            sinks.append("Back to Main Menu")
            sinks.append("Exit")  # Add exit option
            selected_sink = show_rofi_menu(sinks, prompt="Select Sink:")
            if selected_sink == "Back to Main Menu":
                return  # Go back to main menu
            if selected_sink == "Exit" or selected_sink == "":
                sys.exit(0)  # Exit the program
            if selected_sink:
                # Use the ID from the mapping
                sink_id = id_name_map[selected_sink.replace("-> ", "").strip()]
                # Check if the selected sink is already the default
                if sink_id == default_id:
                    print(f"{selected_sink} is already the default sink.")
                    sys.exit(0)  # Exit without changing anything
                subprocess.run(f"wpctl set-default {sink_id}", shell=True)
                sys.exit(0)  # Exit after setting the default sink
        else:
            print("No sinks available.")
            sys.exit(1)

def manage_sources():
    while True:
        sources, id_name_map, default_id = parse_wpctl_status("Sources:")
        if sources:
            sources.append("Back to Main Menu")
            sources.append("Exit")  # Add exit option
            selected_source = show_rofi_menu(sources, prompt="Select Source:")
            if selected_source == "Back to Main Menu":
                return  # Go back to main menu
            if selected_source == "Exit" or selected_source == "":
                sys.exit(0)  # Exit the program
            if selected_source:
                # Use the ID from the mapping
                source_id = id_name_map[selected_source.replace("-> ", "").strip()]
                # Check if the selected source is already the default
                if source_id == default_id:
                    print(f"{selected_source} is already the default source.")
                    sys.exit(0)  # Exit without changing anything
                subprocess.run(f"wpctl set-default {source_id}", shell=True)
                sys.exit(0)  # Exit after setting the default source
        else:
            print("No sources available.")
            sys.exit(1)

def main():
    while True:
        main_menu_items = ["Manage Sinks", "Manage Sources", "Exit"]
        selected_option = show_rofi_menu(main_menu_items, prompt="Select Option:")
        
        if selected_option == "Manage Sinks":
            manage_sinks()
        elif selected_option == "Manage Sources":
            manage_sources()
        elif selected_option == "Exit" or selected_option == "":
            sys.exit(0)  # Exit the program

if __name__ == "__main__":
    main()
