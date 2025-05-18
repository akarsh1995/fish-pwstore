# Function to list all passwords in the password store
function pwstore_list
    # Define paths for password store
    set -l store_path $XDG_CONFIG_HOME/fish/secure/passwords
    set -l registry_path $store_path/registry.json.gpg
    
    # Parse arguments
    set -l show_details false
    set -l debug false
    
    for arg in $argv
        switch $arg
            case --details
                set show_details true
            case --debug
                set debug true
        end
    end
    
    # Check if registry exists
    if test ! -f $registry_path
        echo "No password registry found."
        return 1
    end
    
    # Decrypt the registry directly to memory
    set -l decrypted_content (gpg --quiet --decrypt $registry_path 2>/dev/null)
    if test $status -ne 0
        echo "Failed to decrypt password registry"
        return 1
    end
    
    # Debug output
    if $debug
        echo "Debug: Decrypted content sample"
        echo $decrypted_content | jq 'to_entries | .[0:2]'
        echo "Debug: Total entries: "(echo $decrypted_content | jq 'keys | length')
    end
    
    # Display the passwords in a table format with a nice banner
    set_color cyan
    echo "╔═════════════════════════════════════════════════════════════════╗"
    echo "║                       Password Store                            ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    set_color normal
    echo ""
    
    # Define helpers for table formatting
    function __print_divider
        set -l width $argv[1]
        printf "+%s+\n" (string repeat -n $width "-")
    end
    
    function __print_header
        set -l header $argv[1]
        set -l width $argv[2]
        printf "| %s%s |\n" $header (string repeat -n (math $width - (string length $header) - 2) " ")
    end
    
    function __print_table_row
        set -l name $argv[1]
        set -l username $argv[2]
        set -l url $argv[3]
        set -l description $argv[4]
        set -l updated $argv[5]
        set -l show_details $argv[6]
        set -l show_url $argv[7]
        
        # Determine max column widths
        set -l name_width 25
        set -l username_width 25
        set -l url_width 30
        set -l desc_width 40
        
        # Truncate fields if necessary and add ellipsis
        if test (string length "$name") -gt $name_width
            set name (string sub -l (math $name_width - 3) "$name")"..."
        end
        
        if test (string length "$username") -gt $username_width
            set username (string sub -l (math $username_width - 3) "$username")"..."
        end
        
        # Replace empty URL with a dash for better readability
        if test -z "$url"
            set url "-"
        else if test (string length "$url") -gt $url_width
            set url (string sub -l (math $url_width - 3) "$url")"..."
        end
        
        if test (string length "$description") -gt $desc_width
            set description (string sub -l (math $desc_width - 3) "$description")"..."
        end
        
        # Print row with fixed width columns and color
        set_color --bold cyan
        printf "| %-"$name_width"s |" "$name"
        
        # Color username differently if present
        if test -z "$username" -o "$username" = "-"
            set_color normal
            printf " %-"$username_width"s |" "$username"
        else
            set_color green
            printf " %-"$username_width"s |" "$username"
        end
        
        # URL in blue if present
        if $show_url
            if test "$url" = "-"
                set_color normal
            else
                set_color blue
            end
            printf " %-"$url_width"s |" "$url"
        end
        
        # Description in normal color
        set_color normal
        printf " %-"$desc_width"s |" "$description"
        
        # Updated date in a subtle color
        if $show_details
            set_color yellow
            printf " %s |" "$updated"
        end
        
        set_color normal
        printf "\n"
    end
    
    # Check if any entries have URLs
    set -l has_urls (echo $decrypted_content | jq -r 'to_entries[] | select(.value.url != null and .value.url != "") | .key' | count)
    set -l show_url false
    if begin $show_details; or test $has_urls -gt 0; end
        set show_url true
    end
    
    # Calculate table width based on whether we show details or not
    set -l table_width 100
    if $show_details
        set table_width 147  # Wider for details
    end
    if $show_url; and not $show_details
        set table_width 130  # Medium width for URLs but no details
    end
    
    # Print table header
    __print_divider $table_width
    
    # Print header row with colors
    set_color --bold
    printf "| %-25s | %-25s |" "NAME" "USERNAME/EMAIL"
    
    if $show_url
        printf " %-30s |" "URL"
    end
    
    printf " %-40s |" "DESCRIPTION"
    
    if $show_details
        printf " %-19s |" "UPDATED"
    end
    
    printf "\n"
    set_color normal
    
    __print_divider $table_width
    
    # Process each entry and accumulate in a temporary file for sorting
    set -l temp_file (mktemp)
    echo $decrypted_content | jq -r 'to_entries | .[] | [
        .key,
        .value.username // "",
        .value.url // "",
        .value.description // "",
        .value.updated // "unknown"
    ] | @tsv' > $temp_file
    
    # Sort and print table rows
    # Custom sorting that keeps related paths together (directory structure)
    sort -t / -k1,1 $temp_file | while read -l line
        set -l parts (string split \t $line)
        __print_table_row $parts[1] $parts[2] $parts[3] $parts[4] $parts[5] $show_details $show_url
    end
    
    # Clean up
    rm $temp_file
    
    # Print table footer
    __print_divider $table_width
    
    # Print summary
    set -l count (echo $decrypted_content | jq -r 'keys | length')
    echo "Total entries: $count"
    
    # Clean up helper functions
    functions -e __print_divider
    functions -e __print_header
    functions -e __print_table_row
end
