"""
Module to extract DICOM acquisition timestamps and identify interleaved/simultaneous series.
Generates a user-editable grouping script for organizing series subfolders.

Main function: dicom_series_to_protocol_queue(input_dir, output_dir; ...)
"""

using DICOM
using Dates
using Printf

const TIME_TOLERANCE_SECONDS = 1.0  # Default tolerance for considering acquisitions simultaneous


# DICOM tag tuples
const ACQUISITION_TIME_TAG = (0x0008, 0x0032)
const SERIES_TIME_TAG = (0x0008, 0x0031)
const CONTENT_TIME_TAG = (0x0008, 0x0033)
const ACQUISITION_DATE_TAG = (0x0008, 0x0022)
const SERIES_DATE_TAG = (0x0008, 0x0021)
const STUDY_DATE_TAG = (0x0008, 0x0020)
const PROTOCOL_NAME_TAG = (0x0018, 0x1030)

struct SeriesInfo
    folder_name::String
    timestamps::Vector{DateTime}
    min_time::DateTime
    max_time::DateTime
    file_count::Int
    protocol_name::Union{String, Nothing}
end

function extract_dicom_data(dicom_file::String)::Tuple{Union{DateTime, Nothing}, Union{String, Nothing}}
    """Extract timestamp and ProtocolName from a DICOM file in a single parse.
    Returns: (timestamp, protocol_name)
    """
    try
        dcm = dcm_parse(dicom_file)
        
        # Extract timestamp
        timestamp = nothing
        # Try multiple timestamp fields in order of preference
        # AcquisitionTime (0008,0032) - most accurate for when data was acquired
        if haskey(dcm, ACQUISITION_TIME_TAG)
            acq_time_val = dcm[ACQUISITION_TIME_TAG]
            acq_time_str = string(acq_time_val)
            if !isempty(acq_time_str) && acq_time_str != "nothing"
                timestamp = parse_dicom_time(acq_time_str, dcm)
            end
        end
        
        if timestamp === nothing && haskey(dcm, SERIES_TIME_TAG)
            series_time_val = dcm[SERIES_TIME_TAG]
            series_time_str = string(series_time_val)
            if !isempty(series_time_str) && series_time_str != "nothing"
                timestamp = parse_dicom_time(series_time_str, dcm)
            end
        end
        
        if timestamp === nothing && haskey(dcm, CONTENT_TIME_TAG)
            content_time_val = dcm[CONTENT_TIME_TAG]
            content_time_str = string(content_time_val)
            if !isempty(content_time_str) && content_time_str != "nothing"
                timestamp = parse_dicom_time(content_time_str, dcm)
            end
        end
        
        # Extract ProtocolName
        protocol_name = nothing
        if haskey(dcm, PROTOCOL_NAME_TAG)
            protocol_name_val = dcm[PROTOCOL_NAME_TAG]
            protocol_name_str = string(protocol_name_val)
            if !isempty(protocol_name_str) && protocol_name_str != "nothing"
                protocol_name = strip(protocol_name_str)
            end
        end
        
        return (timestamp, protocol_name)
    catch e
        # Suppress verbose error output
        return (nothing, nothing)
    end
end

function extract_dicom_timestamp(dicom_file::String)::Union{DateTime, Nothing}
    """Extract acquisition timestamp from a DICOM file.
    Deprecated: Use extract_dicom_data() instead for better performance.
    """
    timestamp, _ = extract_dicom_data(dicom_file)
    return timestamp
end

function parse_dicom_time(time_str::String, dcm)::Union{DateTime, Nothing}
    """Parse DICOM time string and combine with date to create DateTime."""
    try
        # Get date from DICOM file
        date_str = ""
        if haskey(dcm, ACQUISITION_DATE_TAG)
            date_val = dcm[ACQUISITION_DATE_TAG]
            date_str = string(date_val)
        elseif haskey(dcm, SERIES_DATE_TAG)
            date_val = dcm[SERIES_DATE_TAG]
            date_str = string(date_val)
        elseif haskey(dcm, STUDY_DATE_TAG)
            date_val = dcm[STUDY_DATE_TAG]
            date_str = string(date_val)
        end
        
        if isempty(date_str) || date_str == "nothing"
            return nothing
        end
        
        # Parse date (format: YYYYMMDD)
        if length(date_str) < 8
            return nothing
        end
        year = parse(Int, date_str[1:4])
        month = parse(Int, date_str[5:6])
        day = parse(Int, date_str[7:8])
        
        # Parse time (format: HHMMSS.FFFFFF or HHMMSS)
        if length(time_str) < 6
            return nothing
        end
        hour = parse(Int, time_str[1:2])
        minute = parse(Int, time_str[3:4])
        second_str = time_str[5:end]
        
        # Handle fractional seconds
        if occursin('.', second_str)
            parts = split(second_str, '.')
            second = parse(Int, parts[1])
            microsecond_str = parts[2]
            # Pad or truncate to 6 digits for microseconds
            if length(microsecond_str) > 6
                microsecond_str = microsecond_str[1:6]
            elseif length(microsecond_str) < 6
                microsecond_str = lpad(microsecond_str, 6, '0')
            end
            microsecond = parse(Int, microsecond_str)
            # Convert microseconds to milliseconds (DateTime expects 0-999)
            millisecond = div(microsecond, 1000)
        else
            if length(second_str) >= 2
                second = parse(Int, second_str[1:2])
            else
                second = parse(Int, second_str)
            end
            millisecond = 0
        end
        
        return DateTime(year, month, day, hour, minute, second, millisecond)
    catch e
        # Suppress verbose error output
        return nothing
    end
end

function extract_protocol_name(dicom_file::String)::Union{String, Nothing}
    """Extract ProtocolName from a DICOM file.
    Deprecated: Use extract_dicom_data() instead for better performance.
    """
    _, protocol_name = extract_dicom_data(dicom_file)
    return protocol_name
end

function analyze_series_folder(folder_path::String, folder_name::String)::Union{SeriesInfo, Nothing}
    """Analyze all DICOM files in a series folder and extract timestamps and ProtocolName."""
    dcm_files = filter(f -> endswith(f, ".dcm"), readdir(folder_path))
    
    if isempty(dcm_files)
        return nothing
    end
    
    timestamps = DateTime[]
    protocol_names = Set{String}()
    
    for dcm_file in dcm_files
        file_path = joinpath(folder_path, dcm_file)
        # Parse DICOM file once and extract both timestamp and ProtocolName
        timestamp, protocol_name = extract_dicom_data(file_path)
        
        if timestamp !== nothing
            push!(timestamps, timestamp)
        end
        
        if protocol_name !== nothing
            push!(protocol_names, protocol_name)
        end
    end
    
    if isempty(timestamps)
        println("  Warning: No valid timestamps found in folder: $folder_name")
        return nothing
    end
    
    sort!(timestamps)
    
    # Get the ProtocolName (use the first one found, or nothing if none found)
    protocol_name = length(protocol_names) > 0 ? first(protocol_names) : nothing
    
    return SeriesInfo(
        folder_name,
        timestamps,
        minimum(timestamps),
        maximum(timestamps),
        length(dcm_files),
        protocol_name
    )
end

function find_interleaved_series(series_list::Vector{SeriesInfo}, time_tolerance_seconds::Float64=TIME_TOLERANCE_SECONDS)::Vector{Vector{String}}
    """Identify groups of series that were acquired simultaneously/interleaved."""
    groups = Vector{String}[]
    processed = Set{String}()
    
    for (i, series1) in enumerate(series_list)
        if series1.folder_name in processed
            continue
        end
        
        current_group = [series1.folder_name]
        push!(processed, series1.folder_name)
        
        # Check overlap with other series
        for (j, series2) in enumerate(series_list)
            if i == j || series2.folder_name in processed
                continue
            end
            
            # Check if series overlap in time
            if series_overlap(series1, series2, time_tolerance_seconds)
                push!(current_group, series2.folder_name)
                push!(processed, series2.folder_name)
            end
        end
        
        # Add group regardless of size (including single series)
        push!(groups, sort!(current_group))
    end
    
    # Sort groups by their earliest acquisition time
    # Create tuples of (earliest_time, group) for sorting
    group_times = []
    for group in groups
        # Find the earliest min_time among all series in this group
        earliest_time = nothing
        for folder_name in group
            for series in series_list
                if series.folder_name == folder_name
                    if earliest_time === nothing || series.min_time < earliest_time
                        earliest_time = series.min_time
                    end
                    break
                end
            end
        end
        if earliest_time !== nothing
            push!(group_times, (earliest_time, group))
        end
    end
    
    # Sort by earliest time and extract just the groups
    sort!(group_times, by=x -> x[1])
    sorted_groups = [group for (_, group) in group_times]
    
    return sorted_groups
end

function series_overlap(series1::SeriesInfo, series2::SeriesInfo, tolerance_seconds::Float64)::Bool
    """Check if two series overlap in acquisition time."""
    # Check if the time ranges overlap
    time_range1 = (series1.min_time, series1.max_time)
    time_range2 = (series2.min_time, series2.max_time)
    
    # Simple overlap check
    if series1.max_time < series2.min_time || series2.max_time < series1.min_time
        return false
    end
    
    # More detailed check: look for interleaved timestamps
    # If timestamps from different series are interleaved, they were acquired together
    all_timestamps = vcat(series1.timestamps, series2.timestamps)
    sort!(all_timestamps)
    
    # Count how many times we switch between series
    switches = 0
    prev_series = nothing
    
    for ts in all_timestamps
        # Check which series this timestamp belongs to
        current_series = 0
        if ts in series1.timestamps
            current_series = 1
        elseif ts in series2.timestamps
            current_series = 2
        end
        
        if prev_series !== nothing && prev_series != current_series && current_series != 0
            switches += 1
        end
        if current_series != 0
            prev_series = current_series
        end
    end
    
    # If there are many switches relative to the number of files, they're interleaved
    # Also check if timestamps are very close together
    min_switch_ratio = 0.3  # At least 30% of timestamps should cause switches
    if switches > min_switch_ratio * length(all_timestamps)
        return true
    end
    
    # Check if timestamps are within tolerance
    for ts1 in series1.timestamps
        for ts2 in series2.timestamps
            time_diff = abs(Dates.value(ts1 - ts2)) / 1000.0  # Convert milliseconds to seconds
            if time_diff <= tolerance_seconds
                return true
            end
        end
    end
    
    return false
end

function generate_grouping_script(groups::Vector{Vector{String}}, all_series::Vector{SeriesInfo}, output_dir::String, input_dir::String)
    """Generate a user-editable bash script for grouping interleaved series."""
    base_dir = input_dir
    
    # If output_dir contains ${BASE_DIR}, don't escape it (it's a bash variable reference)
    # Otherwise, escape it as a literal path
    if occursin("\${BASE_DIR}", output_dir)
        dest_dir_str = output_dir
    else
        dest_dir_str = escape_string(output_dir)
    end
    
    script_content = """#!/bin/bash
# This script groups interleaved/simultaneous DICOM series subfolders.
# Generated automatically by $(basename(@__FILE__))
# Edit this file to adjust groupings and destination paths as needed.

# Base directory containing the series folders
BASE_DIR="$(escape_string(base_dir))"

# Destination directory for grouped series
DEST_DIR="$dest_dir_str"

# Commands to copy/group the series folders
# Each group represents series that were acquired simultaneously/interleaved

"""
    
    # Calculate number of digits needed for zero-padding
    num_groups = length(groups)
    num_digits = length(string(num_groups))
    
    for (i, group) in enumerate(groups)
        # Verify ProtocolName consistency and get group name
        protocol_name, all_match, mismatches = verify_group_protocol_names(group, all_series, base_dir)
        
        # Format queue number with zero-padding
        queue_num = lpad(string(i), num_digits, '0')
        
        if protocol_name !== nothing && all_match
            sanitized_protocol = sanitize_for_filesystem(protocol_name)
            group_name = "Q$queue_num-$sanitized_protocol"
            script_content *= "# Group $i (Q$queue_num, ProtocolName: $protocol_name): $(join(group, ", "))\n"
        else
            if protocol_name !== nothing
                sanitized_protocol = sanitize_for_filesystem(protocol_name)
                group_name = "Q$queue_num-$sanitized_protocol"
            else
                group_name = "Q$queue_num-unknown"
            end
            script_content *= "# Group $i (Q$queue_num): $(join(group, ", "))\n"
            if protocol_name === nothing
                script_content *= "# Warning: No ProtocolName found in DICOM files\n"
            elseif !all_match
                script_content *= "# Warning: ProtocolName mismatch detected!\n"
                for mismatch in mismatches
                    script_content *= "#   $mismatch\n"
                end
            end
        end
        
        if length(group) > 1
            script_content *= "# These series were acquired simultaneously/interleaved\n"
        else
            script_content *= "# Single series (not interleaved with others)\n"
        end
        script_content *= "mkdir -p \"\${DEST_DIR}/$(escape_string(group_name))\"\n"
        
        for folder in group
            folder_path = joinpath(base_dir, folder)
            script_content *= "cp -r \"$(escape_string(folder_path))\" \"\${DEST_DIR}/$(escape_string(group_name))/\"\n"
        end
        script_content *= "\n"
    end
    
    script_content *= """
# Summary of all series analyzed:
"""
    
    for series in all_series
        folder_path = joinpath(base_dir, series.folder_name)
        duration = Dates.value(series.max_time - series.min_time) / 1000.0
        script_content *= "# $(escape_string(series.folder_name)): $(series.file_count) files, duration: $(@sprintf("%.2f", duration))s\n"
    end
    
    return script_content
end

function escape_string(s::String)::String
    """Escape special characters in a string for bash."""
    # Replace backslashes, dollar signs, and quotes
    s = replace(s, "\\" => "\\\\")
    s = replace(s, "\$" => "\\\$")
    s = replace(s, "\"" => "\\\"")
    s = replace(s, "`" => "\\`")
    return s
end

function sanitize_for_filesystem(name::String)::String
    """Sanitize a string for use as a filesystem directory name."""
    # Replace problematic characters with underscores
    sanitized = replace(name, r"[<>:\"/\\|?*]" => "_")
    # Replace spaces with underscores
    sanitized = replace(sanitized, " " => "_")
    # Remove leading/trailing dots and spaces
    sanitized = strip(sanitized, ['.', ' '])
    # Limit length to avoid filesystem issues
    if length(sanitized) > 200
        sanitized = sanitized[1:200]
    end
    return sanitized
end

function verify_group_protocol_names(group::Vector{String}, all_series::Vector{SeriesInfo}, base_dir::String)::Tuple{Union{String, Nothing}, Bool, Vector{String}}
    """Verify all files in a group have the same ProtocolName.
    Returns: (protocol_name, all_match, mismatches)
    """
    protocol_names = Set{Union{String, Nothing}}()
    mismatches = String[]
    
    # Check ProtocolName from series info first
    for folder_name in group
        series_info = nothing
        for series in all_series
            if series.folder_name == folder_name
                series_info = series
                break
            end
        end
        
        if series_info !== nothing
            push!(protocol_names, series_info.protocol_name)
        end
    end
    
    # Also verify by checking actual DICOM files
    for folder_name in group
        folder_path = joinpath(base_dir, folder_name)
        if !isdir(folder_path)
            continue
        end
        
        dcm_files = filter(f -> endswith(f, ".dcm"), readdir(folder_path))
        if isempty(dcm_files)
            continue
        end
        
        # Check a few files to ensure consistency
        files_to_check = min(5, length(dcm_files))
        for i in 1:files_to_check
            file_path = joinpath(folder_path, dcm_files[i])
            protocol_name = extract_protocol_name(file_path)
            push!(protocol_names, protocol_name)
        end
    end
    
    # Remove nothing values
    protocol_names = filter(x -> x !== nothing, protocol_names)
    
    if isempty(protocol_names)
        return (nothing, true, String[])  # No ProtocolName found, but not a mismatch
    end
    
    unique_names = collect(protocol_names)
    if length(unique_names) == 1
        return (unique_names[1], true, String[])
    else
        # Find which folders have different ProtocolNames
        for folder_name in group
            folder_path = joinpath(base_dir, folder_name)
            if !isdir(folder_path)
                continue
            end
            dcm_files = filter(f -> endswith(f, ".dcm"), readdir(folder_path))
            if !isempty(dcm_files)
                file_path = joinpath(folder_path, dcm_files[1])
                protocol_name = extract_protocol_name(file_path)
                if protocol_name !== nothing && !(protocol_name in unique_names[1:1])
                    push!(mismatches, "$folder_name: $protocol_name")
                end
            end
        end
        return (unique_names[1], false, mismatches)
    end
end

function dicom_series_to_protocol_queue(input_dir::String, output_dir::String; output_script_name::Union{String, Nothing}=nothing, time_tolerance_seconds::Float64=TIME_TOLERANCE_SECONDS)
    """
    Extract DICOM acquisition timestamps and identify interleaved/simultaneous series.
    Generates a user-editable grouping script for organizing series subfolders.
    
    Arguments:
        input_dir: Directory containing DICOM series subfolders
        output_dir: Directory where the generated bash script will write grouped series
        output_script_name: Name of the generated bash script (default: derived from this script's name)
        time_tolerance_seconds: Tolerance for considering acquisitions simultaneous (default: 1.0)
    """
    if !isdir(input_dir)
        error("Input directory not found: $input_dir")
    end
    
    # Determine output script name
    if output_script_name === nothing
        output_script_name = replace(basename(@__FILE__), r"\.jl$" => ".sh")
    end
    
    println("Analyzing DICOM series in: $input_dir")
    println("Output directory: $output_dir")
    
    # Get all subdirectories
    all_items = readdir(input_dir)
    series_folders = filter(item -> isdir(joinpath(input_dir, item)), all_items)
    
    println("Found $(length(series_folders)) series folders")
    
    # Analyze each series folder
    series_info_list = SeriesInfo[]
    
    for folder_name in series_folders
        folder_path = joinpath(input_dir, folder_name)
        println("Analyzing: $folder_name")
        
        info = analyze_series_folder(folder_path, folder_name)
        if info !== nothing
            push!(series_info_list, info)
            duration = Dates.value(info.max_time - info.min_time) / 1000.0  # Convert to seconds
            println("  - Files: $(info.file_count), Timestamps: $(length(info.timestamps)), Duration: $(@sprintf("%.2f", duration))s")
        end
    end
    
    println("\nFound $(length(series_info_list)) series with valid timestamps")
    
    # Find interleaved/simultaneous series
    println("\nIdentifying interleaved/simultaneous series...")
    groups = find_interleaved_series(series_info_list, time_tolerance_seconds)
    
    println("\nFound $(length(groups)) groups of interleaved/simultaneous series:")
    
    # Verify ProtocolName consistency for each group
    println("\nVerifying ProtocolName consistency in groups...")
    for (i, group) in enumerate(groups)
        protocol_name, all_match, mismatches = verify_group_protocol_names(group, series_info_list, input_dir)
        if protocol_name !== nothing && all_match
            println("  Group $i: ProtocolName = '$protocol_name' ✓ (all files match)")
        elseif protocol_name !== nothing && !all_match
            println("  Group $i: ProtocolName MISMATCH detected!")
            for mismatch in mismatches
                println("    - $mismatch")
            end
        else
            println("  Group $i: No ProtocolName found in DICOM files")
        end
    end
    
    println("\nGroups:")
    for (i, group) in enumerate(groups)
        println("  Group $i: ", join(group, ", "))
    end
    
    # Generate grouping script
    println("\nGenerating grouping script: $output_script_name")
    script_content = generate_grouping_script(groups, series_info_list, output_dir, input_dir)
    
    open(output_script_name, "w") do f
        write(f, script_content)
    end
    
    # Make the script executable
    run(`chmod +x $output_script_name`)
    
    println("Done! Edit $output_script_name to adjust groupings and destination paths as needed.")
end

