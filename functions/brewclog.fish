function brewclog
    # Function: brewclog
    set -l bcl_version "Version 1.0.4"
    # Define required commands
    set -l bcl_required_cmds jq glow trurl    # Author Laurent Taupiac
    # Purpose: display the last changlog of a brew formula

    set -l verbose 0
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
        echo "  -t, --trace   : Show additional information"
        echo "  -d, --debug   : Show debugging information"
        echo "  -h, --help    : Show this help message"
        echo "  -v, --version : Show version"
        return 0
    end

    # Check if trace mode is enabled
    if set -q _flag_trace
        set verbose 1
    end 

    # After argparse, $argv contains only non-option arguments
    if test (count $argv) -ne 1
        echo "Error: no package name specified."
        echo "Use brewclog --help for more information."
        set -e fish_trace fish_log
        return 1
    end

    # Check and install required commands
    check_and_install_cmds $bcl_required_cmds

    # The first non-option argument is the formula name
    set -l commande $argv[1]

    # Retrieve the repo URL using brew ruby
    set -l repo (brew ruby -e "f = Formula['$commande']; puts f.head.url" 2>/dev/null )

    if test $verbose = 1
        echo "Repo value obtained via brew ruby head.url: [$repo]"
    end

    # If not found, fallback to homepage
    if test -z "$repo"
        if test $verbose = 1
            echo "No head repo found, falling back via brew info: [fallback]"
        end
        set repo (brew info --json "$commande" | jq -r '.[]|.homepage')
        if test $verbose = 1
            echo "Formula git repo: [$repo]"
        end
        if test -z "$repo"
            echo "No formula found for $commande"
            set -e fish_trace fish_log
            return 1
        end
    else
        set repo (echo $repo | sed 's#\.git$##')
    end

    # Check the host before continuing
    set -l current_host (trurl --get {host} "$repo")
    if test "$current_host" != "github.com"
        if test $verbose = 1
            echo "Current host: [$current_host]"
        end
        echo "This repository is not yet supported. Only GitHub is supported."
        echo "host: $repo"
        set -e fish_trace fish_log
        return 1
    end

    # Add the /releases/latest suffix
    set repo (echo $repo | sed 's#$#/releases/latest#')

    if test $verbose = 1
        echo "Repo with /releases/latest suffix: [$repo]"
    end

    # Change the host to api.github.com
    set repo (trurl --set host='api.github.com' $repo)

    # Extract the path and add /repos as a prefix
    set -l extracted_path (trurl --get {path} "$repo")
    set -l path "/repos$extracted_path"

    if test $verbose = 1
        echo "Recalculated path: [$path]"
    end
    
    # Update the path
    set -l repo (trurl --set path="$path" "$repo")

    if test $verbose = 1
        echo "Repo for changelog: [$repo]"
    end

    # Retrieve the tag_name and body of the release + display with glow
    curl -s "$repo" | jq -r '.tag_name, .body' | glow -p
    set -e fish_trace fish_log
end

function check_and_install_cmds
    echo "checking tools"
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

