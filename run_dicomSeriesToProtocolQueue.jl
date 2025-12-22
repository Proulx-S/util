#!/usr/bin/env julia
"""
Wrapper script for dicomSeriesToProtocolQueue.jl that handles repository management.

This script:
1. Checks for the repository containing dicomSeriesToProtocolQueue.jl
2. Clones it if it doesn't exist
3. Warns if it exists but is not up-to-date
4. Executes the function with user-defined directories
"""

# ============================================================================
# USER CONFIGURATION - Edit these values
# ============================================================================

# Input directory containing DICOM series subfolders
const INPUT_DIR = "/local/users/Proulx-S/db/multiVENC_sub01/dcm/PS_001_PS_001_19920101/Polimeni_Nadira_20251023_181032.500000"

# Output directory where grouped series will be written
const OUTPUT_DIR = "/local/users/Proulx-S/db/multiVENC_sub01/dcmQueue"

# Local path to repository (optional - defaults to current directory)
# If empty, will look for the script in the current directory
const REPO_PATH = ""  # e.g., "./dicom-tools" or "/path/to/repo"

# Repository URL (optional - only needed if repo doesn't exist locally)
const REPO_URL = "https://github.com/Proulx-S/util"  # e.g., "https://github.com/username/repo.git"


# ============================================================================
# Script implementation
# ============================================================================

using Pkg

function extract_repo_name(repo_url::String)::String
    """Extract repository name from a git URL."""
    # Remove .git suffix if present
    url = replace(repo_url, r"\.git$" => "")
    # Extract the last part of the path
    parts = split(url, '/')
    return parts[end]
end

function find_repo_path(base_path::String, repo_url::String)::String
    """Find the actual repository path, checking base_path and base_path/repo_name."""
    if !isdir(base_path)
        # Base path doesn't exist, will clone here
        return base_path
    end
    
    # First check if base_path itself is a git repo
    if isdir(joinpath(base_path, ".git"))
        return base_path
    end
    
    # Check if repo is cloned as a subdirectory
    repo_name = extract_repo_name(repo_url)
    repo_subdir = joinpath(base_path, repo_name)
    
    if isdir(repo_subdir) && isdir(joinpath(repo_subdir, ".git"))
        return repo_subdir
    end
    
    # Neither base_path nor subdirectory is a git repo
    return base_path
end

function check_git_repo_status(repo_path::String)::Tuple{Bool, Bool, String}
    """
    Check if a git repository exists and is up-to-date.
    Returns: (exists, is_up_to_date, message)
    """
    if !isdir(repo_path)
        return (false, false, "Repository directory does not exist: $repo_path")
    end
    
    if !isdir(joinpath(repo_path, ".git"))
        return (false, false, "Directory exists but is not a git repository: $repo_path")
    end
    
    # Check if there are uncommitted changes
    try
        result = read(`git -C $repo_path status --porcelain`, String)
        if !isempty(strip(result))
            return (true, false, "Repository has uncommitted changes")
        end
    catch e
        return (true, false, "Could not check git status: $e")
    end
    
    # Check if behind remote
    try
        run(`git -C $repo_path fetch --quiet`)
        local_commit = strip(read(`git -C $repo_path rev-parse HEAD`, String))
        remote_commit = strip(read(`git -C $repo_path rev-parse "@{u}"`, String))
        
        if local_commit != remote_commit
            return (true, false, "Repository is behind remote (local: $(local_commit[1:7]) vs remote: $(remote_commit[1:7]))")
        end
    catch e
        # If fetch fails, might not have a remote - that's okay for local repos
        return (true, true, "Repository exists (no remote configured)")
    end
    
    return (true, true, "Repository exists and is up-to-date")
end

function clone_repo(repo_url::String, target_path::String)
    """Clone a git repository to the target path."""
    if isempty(repo_url)
        error("Cannot clone repository: REPO_URL is not set")
    end
    
    repo_name = extract_repo_name(repo_url)
    
    # Determine where to clone
    if isdir(target_path) && isdir(joinpath(target_path, ".git"))
        # Already a git repo, don't clone
        return target_path
    elseif isdir(target_path) && !isdir(joinpath(target_path, repo_name))
        # Target path exists but repo subdirectory doesn't - clone into subdirectory
        repo_subdir = joinpath(target_path, repo_name)
        println("Cloning repository from $repo_url to $repo_subdir...")
        try
            run(`git clone $repo_url $repo_subdir`)
            println("Repository cloned successfully.")
            return repo_subdir
        catch e
            error("Failed to clone repository: $e")
        end
    elseif isdir(target_path) && isempty(readdir(target_path))
        # Directory exists but is empty - clone into it
        println("Cloning repository from $repo_url to $target_path...")
        try
            run(`git clone $repo_url $target_path`)
            println("Repository cloned successfully.")
            return target_path
        catch e
            error("Failed to clone repository: $e")
        end
    elseif !isdir(target_path)
        # Directory doesn't exist - git clone will create it
        println("Cloning repository from $repo_url to $target_path...")
        try
            run(`git clone $repo_url $target_path`)
            println("Repository cloned successfully.")
            return target_path
        catch e
            error("Failed to clone repository: $e")
        end
    else
        error("Target path $target_path exists and is not empty, and repository subdirectory already exists. Cannot clone here.")
    end
end

function find_script_path(repo_path::String)::String
    """Find the dicomSeriesToProtocolQueue.jl script in the repository."""
    script_name = "dicomSeriesToProtocolQueue.jl"
    
    # Check in repo root
    script_path = joinpath(repo_path, script_name)
    if isfile(script_path)
        return script_path
    end
    
    # Check in src/ directory
    script_path = joinpath(repo_path, "src", script_name)
    if isfile(script_path)
        return script_path
    end
    
    error("Could not find $script_name in repository: $repo_path")
end

function main()
    # Determine repository path
    if !isempty(REPO_PATH)
        base_path = abspath(expanduser(REPO_PATH))
        
        # Find the actual repo path (could be base_path or base_path/repo_name)
        if !isempty(REPO_URL)
            repo_path = find_repo_path(base_path, REPO_URL)
        else
            repo_path = base_path
        end
    else
        # Look in current directory
        repo_path = pwd()
        script_path = joinpath(repo_path, "dicomSeriesToProtocolQueue.jl")
        if isfile(script_path)
            # Script is in current directory, use it directly
            println("Using script from current directory: $script_path")
            include(script_path)
            Base.invokelatest(dicom_series_to_protocol_queue, INPUT_DIR, OUTPUT_DIR)
            return
        end
        # If REPO_PATH is empty but we need to clone, use current directory as base
        base_path = repo_path
    end
    
    # Check repository status
    exists, is_up_to_date, message = check_git_repo_status(repo_path)
    
    if !exists
        println("Repository not found: $message")
        if !isempty(REPO_URL)
            println("Attempting to clone repository...")
            # Clone to the appropriate location (base_path or base_path/repo_name)
            repo_path = clone_repo(REPO_URL, base_path)
            exists, is_up_to_date, message = check_git_repo_status(repo_path)
        else
            error("Repository does not exist and REPO_URL is not set. Cannot proceed.")
        end
    else
        println("Repository status: $message")
        if !is_up_to_date
            println("WARNING: Repository exists but may not be up-to-date. Consider running 'git pull' in $repo_path")
        end
    end
    
    # Store the up-to-date status for final warning
    repo_not_up_to_date = !is_up_to_date
    repo_path_for_warning = repo_path
    
    # Find and include the script
    script_path = find_script_path(repo_path)
    println("Loading script from: $script_path")
    include(script_path)
    
    # Execute the function (use invokelatest to avoid world age issues)
    println("\n" * "="^70)
    println("Executing dicom_series_to_protocol_queue")
    println("="^70)
    Base.invokelatest(dicom_series_to_protocol_queue, INPUT_DIR, OUTPUT_DIR)
    
    # Print final warning if repository is not up-to-date
    if repo_not_up_to_date
        println("\n" * repeat("!", 70))
        println("WARNING: The repository at $repo_path_for_warning is not up-to-date.")
        println("Consider running 'git pull' in that directory to get the latest version.")
        println(repeat("!", 70))
    end
end

# Run the script
main()

