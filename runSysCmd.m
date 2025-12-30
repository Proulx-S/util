function cmdOut = runSysCmd(cmd, outputFile ,verbose)
% runSysCmd - Execute a system command and log the command and output to a file
%
% Syntax:
%   runSysCmd(cmd, outputFile)
%
% Inputs:
%   cmd        - Cell array of command parts to be joined with newlines, or string
%   outputFile - Path to file where command and output will be logged
%
% Description:
%   Executes a system command, displays it, checks for errors, and logs both
%   the command and its output to the specified file with timestamps and separators.
%
% Example:
%   cmd = {'ls', '-la', '/tmp'};
%   runSysCmd(cmd, '/path/to/log.txt');
if ~exist('verbose','var') || isempty(verbose); verbose = false; end

% Display the command
if verbose
    disp(strjoin(cmd, newline));
end

% Execute the command
if verbose
    [cmdErr, cmdOut] = system(strjoin(cmd, newline), '-echo');
else
    [cmdErr, cmdOut] = system(strjoin(cmd, newline));
end
if cmdErr
    dbstack;
    error(cmdOut);
end

% Write command and output to log file
fid = fopen(outputFile, 'w');
fprintf(fid, '%s', strjoin(cmd, newline));
fprintf(fid, repmat('\n', 1, 5));
fprintf(fid, 'The above ran on %s\n%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 60));
fprintf(fid, 'Below is the output\n');
fprintf(fid, repmat('\n', 1, 5));
fprintf(fid, '%s\n', cmdOut);
fclose(fid);

disp(['command and terminal output logged to:' newline ' ' outputFile]);

end

