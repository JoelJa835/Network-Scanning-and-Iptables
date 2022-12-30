#!/bin/bash
# You are NOT allowed to change the files' names!
domainNames="domainNames.txt"
domainNames2="domainNames2.txt"
IPAddressesSame="IPAddressesSame.txt"
IPAddressesDifferent="IPAddressesDifferent.txt"
adblockRules="adblockRules"

function adBlock() {

    if [ -f "$IPAddressesSame" ]; then
        echo "Removing $IPAddressesSame..."
        rm "$IPAddressesSame"
    fi
    if [ -f "$IPAddressesDifferent" ]; then
        echo "Removing $IPAddressesDifferent..."
        rm "$IPAddressesDifferent"
    fi
    
    if [ "$EUID" -ne 0 ];then
        printf "Please run as root.\n"
        exit 1
    fi
    if [ "$1" = "-domains"  ]; then
        # Find different and same domains in ‘domainNames.txt’ and ‘domainsNames2.txt’ files 
	    # and write them in “IPAddressesDifferent.txt and IPAddressesSame.txt" respectively

        echo 'Process of writing in the specified files has started successfully. Please wait patiently the process will be done shortly!!'
        # Create the output files
        same_domains=$(mktemp)
        different_domains=$(mktemp)

        # Sort the input files
        sort -o domainNames.txt  domainNames.txt
        sort -o domainNames2.txt  domainNames2.txt

        # Find the domains that are the same in both input files
        comm -12 domainNames.txt domainNames2.txt > "$same_domains"

        # Find the domains that are different in both input files
        comm -23 domainNames.txt domainNames2.txt > "$different_domains"
        comm -13 domainNames.txt domainNames2.txt >> "$different_domains"



        # Get the IP addresses for the same domains and write them to a file
        cat "$same_domains" | parallel "nslookup {}" | awk '/^Address: / {print $2}' | grep -v ':' | while read -r ip; do
        echo "$ip" >> IPAddressesSame.txt
        done

        # Get the IP addresses for the different domains and write them to a file
        cat "$different_domains" | parallel "nslookup {}" | awk '/^Address: / {print $2}' | grep -v ':' | while read -r ip; do
        echo "$ip" >> IPAddressesDifferent.txt
        done

        # Remove the temporary files
        rm "$same_domains" "$different_domains"

    elif [ "$1" = "-ipssame"  ]; then
        # Configure the DROP adblock rule based on the IP addresses of $IPAddressesSame file.

        # Add DROP rule to iptables for each IP address
        while read -r ip; do
            iptables -A INPUT -s $ip -j DROP
            iptables -A FORWARD -s $ip -j DROP
            iptables -A OUTPUT -d $ip -j DROP
        done < "$IPAddressesSame"


    elif [ "$1" = "-ipsdiff"  ]; then
        # Configure the REJECT adblock rule based on the IP addresses of $IPAddressesDifferent file.
        while read -r ip; do
            iptables -A INPUT -s $ip -j REJECT
            iptables -A FORWARD -s $ip -j REJECT
            iptables -A OUTPUT -d $ip -j REJECT
        done < "$IPAddressesDifferent"

    elif [ "$1" = "-save"  ]; then
        # Save rules to $adblockRules file.
        sudo iptables-save > adblockRules
        
    elif [ "$1" = "-load"  ]; then
        # Load rules from $adblockRules file.
        sudo iptables-restore < adblockRules

        
    elif [ "$1" = "-reset"  ]; then
        # Reset rules to default settings (i.e. accept all).
        echo "This will reset the iptables rules to the default settings (i.e. accept all)."
        echo "Are you sure you want to continue? [y/N]"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT

        iptables -F
        iptables -X
    else
        echo "Aborting."
    fi
        
    elif [ "$1" = "-list"  ]; then
        # List current rules.
        sudo iptables -L -n -v
        
    elif [ "$1" = "-help"  ]; then
        printf "This script is responsible for creating a simple adblock mechanism. It rejects connections from specific domain names or IP addresses using iptables.\n\n"
        printf "Usage: $0  [OPTION]\n\n"
        printf "Options:\n\n"
        printf "  -domains\t  Configure adblock rules based on the domain names of '$domainNames' file.\n"
        printf "  -ipssame\t\t  Configure the DROP adblock rule based on the IP addresses of $IPAddressesSame file.\n"
	printf "  -ipsdiff\t\t  Configure the DROP adblock rule based on the IP addresses of $IPAddressesDifferent file.\n"
        printf "  -save\t\t  Save rules to '$adblockRules' file.\n"
        printf "  -load\t\t  Load rules from '$adblockRules' file.\n"
        printf "  -list\t\t  List current rules.\n"
        printf "  -reset\t  Reset rules to default settings (i.e. accept all).\n"
        printf "  -help\t\t  Display this help and exit.\n"
        exit 0
    else
        printf "Wrong argument. Exiting...\n"
        exit 1
    fi
}

adBlock $1
exit 0
