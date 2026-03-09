function S = emptyStruct(S)
%EMPTYSTRUCT  Empty all non-struct fields; recurse into struct fields.
%   S = emptyStruct(S) returns a struct with the same field names as S.
%   Each field that is not a struct is set to an empty value of the same type
%   (e.g. [] for numeric, {} for cell, '' for char). Each field that is a struct
%   is replaced by the result of emptyStruct applied to that field (recursively).
%   Struct arrays are supported: each element is emptied in place.

    if isempty(S)
        return;
    end

    fn = fieldnames(S);
    for i = 1:numel(S)
        for k = 1:numel(fn)
            f = fn{k};
            val = S(i).(f);
            if isstruct(val)
                S(i).(f) = emptyStruct(val);
            else
                S(i).(f) = emptyValue(val);
            end
        end
    end
end

function out = emptyValue(x)
% Return an empty value matching the type of x.
    if iscell(x)
        out = {};
    elseif ischar(x)
        out = '';
    elseif isstring(x)
        out = "";
    elseif islogical(x)
        out = false(0);
    elseif isnumeric(x) || isa(x, 'function_handle')
        out = [];
    elseif istable(x)
        out = table();
    else
        out = [];
    end
end
