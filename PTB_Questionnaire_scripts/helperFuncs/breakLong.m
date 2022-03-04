function [ newString, lineNum ] = breakLong( oldString )
%BREAKLONG Break long strings into multiple lines when there is a "newline" character: two spaces

wheresNewline = strfind(oldString, "  ");

if wheresNewline > 0
  howLong = ceil(length(oldString) / wheresNewline);
  strings = cell(1, howLong);
else
  howLong = 1;
  strings = cell(1, howLong);
end


if howLong > 1 
    for i = 1:(howLong-1)
        strings{i} = oldString(wheresNewline*(i-1)+1:wheresNewline*i);
    end
    strings{i+1} = oldString(wheresNewline*i+1:end);
    lineNum = i + 1;
else
    strings{1} = oldString;
    lineNum = 1;
end

newString = strjoin(strings, '\n');

endfunction

