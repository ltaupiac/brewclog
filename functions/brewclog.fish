function brewclog
    # Function: brewclog
    # Version 1.0 
    # Author Laurent Taupiac
    # Purpose: display the last changlog of a brew formula

### Help
Usage: brewclog [options] <formula>
Displays the changelog of the latest GitHub release of a Homebrew formula.

Options:
  -v, --verbose : Show additional information
  -d, --debug   : Show debugging information
  -h, --help    : Show this help message

### Dependancies
jq   - Commandline JSON processor 
glow - Render markdown on the CLI, with pizzazz!

### Limitations
Works only for github 

    # Required commands
    set -l cmd_req jq glow
    for c in $cmd_req
        if not type -q $c
            echo "The command [$c] must be installed (e.g., brew install $c)"
            set -e fish_trace fish_log
            return 1
        end
    end

    set -l verbose 0
    set -l commande ""

    # Using argparse to handle arguments
    # --stop-nonopt stops parsing at the first non-option argument
    # v/verbose, d/debug, h/help define short and long options
    argparse --stop-nonopt v/verbose h/help d/debug -- $argv
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

    # If --help / -h is set, display help
    if set -q _flag_help
        echo "Usage: brewclog [options] <formula>"
        echo "Version 1.0"
        echo "Purpose: display the last changlog of a brew formula"
        echo
        echo "Options:"
        echo "  -v, --verbose : Show additional information"
        echo "  -d, --debug   : Show debugging information"
        echo "  -h, --help    : Show this help message"
        return
    end

    # Check if verbose mode is enabled
    if set -q _flag_verbose
        set verbose 1
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

