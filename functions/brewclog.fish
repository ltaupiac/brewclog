function brewclog
    # Function: brewclog
    set -l bcl_version "Version 1.0.4"
    # Define required commands
    set -l bcl_required_cmds jq glow trurl    # Author Laurent Taupiac
    # Purpose: display the last changlog of a brew formula

    set -x verbose 0
    set -l commande ""

    # Using argparse to handle arguments
    # --stop-nonopt stops parsing at the first non-option argument
    # v/verbose, d/debug, h/help define short and long options
    argparse --stop-nonopt v/version t/trace h/help d/debug -- $argv
    or begin
        # If argparse fails (unknown option or other error), show help and exit
        echo "Error parsing arguments."
        echo "Use brewclog --help for more information."
        set -e fish_trace fish_log
        return 1
    end

    if set -q _flag_debug
        set -x fish_trace 1
        set -U fish_log 3
    end

        # If --version / -v is set, display version
    if set -q _flag_version
        echo $bcl_version
        set -e fish_trace fish_log
        return 0
    end

    # If --help / -h is set, display help
    if set -q _flag_help
        echo "Usage: brewclog [options] <formula>"
        echo $bcl_version
        echo "Purpose: display the last changlog of a brew formula"
        echo
        echo "Options:"
        echo "  -t, --trace   : Verbose mode"
        echo "  -d, --debug   : Show debugging information"
        echo "  -h, --help    : Show this help message"
        echo "  -v, --version : Show version"
        return 0
    end

    # Check if trace mode is enabled
    if set -q _flag_trace
        echo "Verbose mode"
        set -x verbose 1
    end 

    # After argparse, $argv contains only non-option arguments
    if test (count $argv) -ne 1
        echo "Error: no package name specified."
        echo "Use brewclog --help for more information."
        set -e fish_trace fish_log
        return 1
    end
    # The first non-option argument is the formula name
    set -l commande $argv[1]

    # Check and install required commands
    check_and_install_cmds $bcl_required_cmds

    # Call the external function to get the repo URL
    set -l repo (get_brew_repo_url $commande $verbose)

    # Check the result of the function
    if test -z "$repo"
        echo "Failed to retrieve repo URL for formula: $commande"
        set -e fish_trace fish_log
        return 1
    end

    set repo (echo $repo | sed 's#\.git$##')

    # Check the host before continuing
    set -l current_host (trurl --get {host} "$repo")
    if test "$current_host" != "github.com"
        trace "Current host: [$current_host]"
        echo "This repository is not yet supported. Only GitHub is supported."
        echo "host: $repo"
        set -e fish_trace fish_log
        return 1
    end

    # Add the /releases/latest suffix
    set repo (echo $repo | sed 's#$#/releases/latest#')

    trace "Repo with /releases/latest suffix: [$repo]"

    # Change the host to api.github.com
    set repo (trurl --set host='api.github.com' $repo)

    # Extract the path and add /repos as a prefix
    set -l extracted_path (trurl --get {path} "$repo")
    set -l path "/repos$extracted_path"

    trace "Recalculated path: [$path]"
    
    # Update the path
    set -l repo (trurl --set path="$path" "$repo")

    trace "Repo for changelog: [$repo]"

    # Retrieve the tag_name and body of the release + display with glow
    curl -s "$repo" | jq -r '.tag_name, .body' | glow -p
    set -e fish_trace fish_log
end

function trace 
    if test "$verbose" = "1"
        echo (set_color green)"Trace: $argv[1]"(set_color normal) >&2
    end
end

function show
      echo $argv[1] >&2
end

function check_and_install_cmds
    # Required commands
    set -l required_cmds $argv    
    # Initialize a variable to hold missing commands
    set -l missing_cmds 

    # Loop through the required commands
    for c in $required_cmds
        if not type -q $c
            # Append missing command to the list
            set missing_cmds $missing_cmds $c
        end
    end

    # Check if there are any missing commands
    if test -n "$missing_cmds"
        echo "The following commands are missing: $missing_cmds"
        # Prompt to install missing commands
        echo
        echo "Would you like to install them now? (y/n)"
        read -l choice

        if test "$choice" = "y"
            echo "Installing missing commands with Homebrew..."
            brew install $missing_cmds
            if test $status -ne 0
                echo "Error: Failed to install one or more commands."
                set -e fish_trace fish_log
                return 1
            else
                echo "All missing commands installed successfully!"
            end
        else
            echo "Please install the missing commands manually. (brew install $missing_cmds)"
            set -e fish_trace fish_log
            return 1
        end
    end
end

function get_brew_repo_url
    # Arguments: formula name 
    set -l formula_name $argv[1]
    
    trace "searching repo for formula [$formula_name]"

    if test -z "$formula_name"
        trace "Error calling get_brew_repo_url: no formula"
        return 1
    end

    # Retrieve the repo URL using brew ruby
    set -l repo (brew ruby -e "f = Formula['$formula_name']; puts f.head.url" 2>/dev/null)

    trace "Repo value obtained via brew ruby head.url: [$repo]"

    # If not found, fallback to homepage
    if test -z "$repo"
        trace "No head repo found, fallback json brew info"
        set repo (brew info --json=v2 "$formula_name" | jq -r '.formulae[]?.homepage // empty, .casks[]?.homepage // empty')
        trace "Formula git repo (from json homepage): [$repo]"

        if test -z "$repo"
            trace "No formula found for $formula_name"
            return 1
        end
    else
        # Clean up `.git` suffix if present
        set repo (echo $repo | sed 's#\.git$##')
    end

    # Output the result
    echo $repo
end

