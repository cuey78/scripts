#!/bin/bash
#####################################################################################################
##                           My VPN Script for NordVPN cli tool                                    ##
##                                                                                                 ##
#####################################################################################################

# Check if nordvpn is installed
if ! command -v nordvpn &> /dev/null; then
    dialog --msgbox "NordVPN command not found. Please install NordVPN and try again." 10 30
    clear
    exit 1
fi

# Function to connect to NordVPN server
connect_to_vpn() {
    local country="$1"
    if nordvpn c "$country"; then
        dialog --msgbox "Successfully connected to $country." 10 30
    else
        dialog --msgbox "Failed to connect to $country. Please check your VPN configuration and try again." 10 30
    fi
}

# Function to disconnect from NordVPN
disconnect_from_vpn() {
    if nordvpn d; then
        dialog --msgbox "Successfully disconnected from VPN." 10 30
    else
        dialog --msgbox "Failed to disconnect from VPN. Please check your VPN configuration and try again." 10 30
    fi
}

# Function to display the country selection menu
display_country_menu() {
    local letter="$1"
    local -a options=()

    case $letter in
        A) countries=(Albania Argentina Australia Austria) ;;
        B) countries=(Belgium Bosnia_And_Herzegovina Brazil Bulgaria) ;;
        C) countries=(Canada Chile Colombia Costa_Rica Croatia Cyprus Czech_Republic) ;;
        D) countries=(Denmark) ;;
        E) countries=(Estonia) ;;
        F) countries=(Finland France) ;;
        G) countries=(Germany Greece) ;;
        H) countries=(Hong_Kong Hungary) ;;
        I) countries=(Iceland Indonesia Ireland Israel Italy) ;;
        J) countries=(Japan) ;;
        L) countries=(Latvia Lithuania Luxembourg) ;;
        M) countries=(Malaysia Mexico Moldova) ;;
        N) countries=(Netherlands New_Zealand North_Macedonia) ;;
        P) countries=(Poland Portugal) ;;
        R) countries=(Romania) ;;
        S) countries=(Serbia Singapore Slovakia Slovenia South_Africa South_Korea Spain Sweden Switzerland) ;;
        T) countries=(Taiwan Thailand Turkey) ;;
        U) countries=(Ukraine United_Kingdom United_States) ;;
        V) countries=(Vietnam) ;;
        *)
            dialog --msgbox "Invalid letter. Please choose again." 10 30
            return
            ;;
    esac

    for country in "${countries[@]}"; do
        options+=("$country" "")
    done

    country=$(dialog --clear --backtitle "NordVPN Menu" --title "Country Selection" \
        --menu "Choose a country to connect to:" 20 50 30 "${options[@]}" 2>&1 >/dev/tty)

    if [ -n "$country" ]; then
        connect_to_vpn "$country"
    fi
}

# Function to display the main menu
display_menu() {
    local vpn_status
    if vpn_status=$(nordvpn status 2>&1); then
        vpn_status=$(echo "$vpn_status" | sed -e 's/^[ \t]*//')
    else
        vpn_status="Unable to retrieve VPN status. Please ensure NordVPN is running properly."
    fi

    action=$(dialog --clear --backtitle "NordVPN Menu" --title "Main Menu" \
        --menu "VPN Status:\n$vpn_status\n\nChoose an option:" 20 70 30 \
        1 "Connect to VPN" \
        2 "Disconnect from VPN" \
        3 "Exit" 2>&1 >/dev/tty)

    case $action in
        1)
            letter=$(dialog --clear --backtitle "NordVPN Menu" --title "Country Selection by Letter" \
                --menu "Choose the first letter of the country:" 20 50 30 \
                A "Countries starting with A" \
                B "Countries starting with B" \
                C "Countries starting with C" \
                D "Countries starting with D" \
                E "Countries starting with E" \
                F "Countries starting with F" \
                G "Countries starting with G" \
                H "Countries starting with H" \
                I "Countries starting with I" \
                J "Countries starting with J" \
                L "Countries starting with L" \
                M "Countries starting with M" \
                N "Countries starting with N" \
                P "Countries starting with P" \
                R "Countries starting with R" \
                S "Countries starting with S" \
                T "Countries starting with T" \
                U "Countries starting with U" \
                V "Countries starting with V" 2>&1 >/dev/tty)

            if [ -n "$letter" ]; then
                display_country_menu "$letter"
            fi
            ;;
        2)
            disconnect_from_vpn
            ;;
        3)
            dialog --msgbox "Exiting NordVPN. Goodbye!" 10 30
            clear
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid choice. Please enter 1, 2, or 3." 10 30
            ;;
    esac
}

# Main script loop
while true; do
    display_menu
done
