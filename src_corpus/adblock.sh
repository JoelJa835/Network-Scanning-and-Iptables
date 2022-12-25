#!/bin/bash
# You are NOT allowed to change the files' names!
domainNames="domainNames.txt"
domainNames2="domainNames2.txt"
IPAddressesSame="IPAddressesSame.txt"
IPAddressesDifferent="IPAddressesDifferent.txt"
adblockRules="adblockRules"

function adBlock() {
    if [ "$EUID" -ne 0 ];then
        printf "Please run as root.\n"
        exit 1
    fi
    if [ "$1" = "-domains"  ]; then
        # Find different and same domains in ‘domainNames.txt’ and ‘domainsNames2.txt’ files 
	# and write them in “IPAddressesDifferent.txt and IPAddressesSame.txt" respectively
        # Write your code here...
        sort domainNames.txt domainNames2.txt | uniq -d > IPAddressesSame.txt
        sort domainNames.txt domainNames2.txt | uniq -u > IPAddressesDifferent.txt
            
    elif [ "$1" = "-ipssame"  ]; then
        # Configure the DROP adblock rule based on the IP addresses of $IPAddressesSame file.
        while read domain; do
        # Skip line if it does not contain a domain name
        if [[ "$domain" != *"."* ]]; then
            continue
        fi
        # Perform DNS lookup on domain and extract the IP addresses
        #ips=$(dig +short $domain) #There was some problem with dig, nslookup worked fine.
        ips=$(nslookup $domain | awk '/^Address: / {print $2}')
        # Skip domain if it does not have an IP address
        if [ -z "$ips" ]; then
            continue
        fi
        # Split the IP addresses into an array
        IFS=' ' read -ra ip_array <<< "$ips"
        # Add DROP rule to iptables for each IP address
        for ip in "${ip_array[@]}"; do
            iptables -A INPUT -s $ip -j DROP
        done
        done < IPAddressesSame.txt

    elif [ "$1" = "-ipsdiff"  ]; then
        # Configure the REJECT adblock rule based on the IP addresses of $IPAddressesDifferent file.
        while read domain; do
        # Skip line if it does not contain a domain name
        if [[ "$domain" != *"."* ]]; then
            continue
        fi
        # Perform DNS lookup on domain and extract the IP addresses
        #ips=$(dig +short $domain)
        ips=$(nslookup $domain | awk '/^Address: / {print $2}')
        # Skip domain if it does not have an IP address
        if [ -z "$ips" ]; then
            continue
        fi
        # Split the IP addresses into an array
        IFS=' ' read -ra ip_array <<< "$ips"
        # Add REJECT rule to iptables for each IP address
        for ip in "${ip_array[@]}"; do
            iptables -A INPUT -s $ip -j REJECT
        done
        done < IPAddressesDifferent.txt

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
