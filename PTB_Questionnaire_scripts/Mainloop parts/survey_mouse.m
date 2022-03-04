function [selects] = survey_mouse(pairNo, labName, filename)
% The full course of an experiment

%clearvars;
%rng('shuffle');

% Add current folder and all sub-folders
%addpath(genpath([pwd '/..']));

% -------------------------------------------------------
%                       Input checks
% -------------------------------------------------------

if nargin < 3
  error('Input args "pairNo", "labName" and "filename" are required!');
end

if ~ismember(pairNo, 1:999)
    error('Input arg "pairNo" should be one of 1:999!');
end 

if ~ismember(labName, {'Mordor', 'Gondor'})
    error('Input arg "labName" should be one of {"Mordor", "Gondor"}!');
end

if ~ismember(filename, {'debrief_BG1.csv', 'debrief_BG2.csv', 'debrief_BG3.csv',...
                        'debrief_BG4.csv', 'debrief_BG5.csv', 'debrief_freeConv.csv',...
                        'debrief_playback.csv'})
    error(['Input arg "filename" should be one of the following: ', char(10)...
          '"debrief_BG1.csv", "debrief_BG2.csv", "debrief_BG3.csv"',char(10)...
          '"debrief_BG4.csv", "debrief_BG5.csv", "debrief_freeConv.csv" or "debrief_playback"']);
end

if ~exist(filename, 'file')
    error('File "%s" does not exist!', filename);
endif


%--------------------------------------------------------------------------
%                       Global variables
%--------------------------------------------------------------------------
global window windowRect fontsize xCenter yCenter white;


%--------------------------------------------------------------------------
%                       Screen initialization
%--------------------------------------------------------------------------

% First create the screen for simulation displaying
% Using function prepareScreen.m
% This returned vbl may not be precise; flip again to get a more precise one
% This screen size is for test
[window, windowRect, vbl, ifi] = prepareScreen([0 0 1920 1080]);
HideCursor;


%--------------------------------------------------------------------------
%                       Global settings
%--------------------------------------------------------------------------

% Screen center
[xCenter, yCenter] = RectCenter(windowRect);


% Define some DEFAULT values
isdialog = false; % Change this value to determine whether to use dialog

showQuestNum = 7; % Number of questions to display in one screen; you may need to try few times to get best display
ansNum = 7; % Number of answers for each question

if strcmp(filename, 'testfile.csv')
  survey_name = 'test';
  survey_type = 'question'; % Type of the survey, can be "question", "likert"
  questNum = 5; % Number of questions in this survey
  ansNum = 2;
end

if strcmp(filename, 'debrief_BG1.csv')
  survey_name = 'BG1';
  survey_type = 'likert'; % Type of the survey, can be "question", "likert"
  questNum = 16; % Number of questions in this survey
end

if strcmp(filename, 'debrief_BG2.csv')
  survey_name = 'BG2';
  survey_type = 'likert'; 
  questNum = 13;  
end

if strcmp(filename, 'debrief_BG3.csv')
  survey_name = 'BG3';
  survey_type = 'likert'; 
  questNum = 16; 
end

if strcmp(filename, 'debrief_BG4.csv')
  survey_name = 'BG4';
  survey_type = 'likert'; 
  questNum = 13;  
end

if strcmp(filename, 'debrief_freeConv.csv')
  survey_name = 'freeConv';
  survey_type = 'likert'; 
  questNum = 14;  
end

if strcmp(filename, 'debrief_playback.csv')
  survey_name = 'playback';
  survey_type = 'likert'; 
  questNum = 8; 
  showQuestNum = 8; 
end

% construct the .mat file for later saving
datadir = "/media/lucab/HV620S/MATLAB_PTB_Questionnaire-master/data/";
surveyDataFile = [datadir, "pair", num2str(pairNo), labName, "_", survey_name, "_survey.mat"];

%------------------------------------------------------------------------------------
%                     Prepare survey texture 
%------------------------------------------------------------------------------------

% Survey texture for later drawing; the file is loaded inside
% prepareSurvey.m; for the detail of the csv file's structure, see loadSurvey.m

[paperTexture, paperRect, questH, ansH, questYs, ansYs] = prepareSurvey(isdialog, filename, survey_type, questNum, ansNum, showQuestNum);

%-------------------------------------------------------------------------------------

% Set FONT for instructions
Screen('Textsize', window, 23);
Screen('TextFont', window, 'Liberation Sans');

% COLOR settings
% Set color for identifying currently focused question and answer
% and selected answer
qcolor = [0 0 1 0.1];
acolor = [1 0 0 0.5];
scolor = [0 1 0 0.2];

##% Base rect for questions and answers
##baseQRect = [0 0 595 questH];
##if strcmp(survey_type, 'likert')
##    aCenters = linspace(595/(ansNum*2), 595*((ansNum-0.5)/ansNum), ansNum) + (xCenter-595/2);
##end
##
##paperlimit = [xCenter-595/2 xCenter+595/2];

##% Base rect for questions and answers
##baseQRect = [0 0 763 questH];
##if strcmp(survey_type, 'likert')
##    aCenters = linspace(763/(ansNum*2), 763*((ansNum-0.5)/ansNum), ansNum) + (xCenter-763/2);
##end
##
##paperlimit = [xCenter-763/2 xCenter+763/2];

% Base rect for questions and answers
baseQRect = [0 0 1190 questH];
if strcmp(survey_type, 'likert')
    aCenters = linspace(1190/(ansNum*2), 1190*((ansNum-0.5)/ansNum), ansNum) + (xCenter-1190/2);
end

paperlimit = [xCenter-1190/2 xCenter+1190/2];

% Keep a record of selections during loop
% These will be used to draw marks
selects = zeros([questNum, ansNum]);
currQ = 1;
currA = 0;
% To keep the marks in right place while scrolling screen
offsetRange = [showQuestNum-questNum 0];
offset = 0;

% Record selected rects here
seleRects = nan(4, questNum); % This is for drawing
tempRects = nan(4, questNum); % This is for recording

ShowCursor;

%-------------------------------------------------------------------------------
% First draw instructions
%-------------------------------------------------------------------------------

instruc = ["Kérlek töltsd ki a következő kérdőívet. A válaszaidon ne gondolkozz sokat!" char(10),...
           char(10), "A következő kérdésekre úgy görgethetsz, ha leviszed az egeret a lap aljára. " char(10),... 
           char(10), char(10), "Kattins bárhova a képernyőn és kezdheted is a kitöltést."];

Screen('FillRect', window, 1, paperRect);
[~, ny] = DrawFormattedText(window, instruc, 'center', 'center', 0);
%DrawFormattedText(window, currDeviceIn, 'center', ny+questH, 0);
Screen('Flip', window);

% Wait for 10 secs here for participants to read the instruction before
% check for any input
WaitSecs(5);

% If any key clicked, go to the loop
checkClicked(window);


%================================================================================================
%                              MAIN LOOP 
%================================================================================================

% Show the survey
Screen('DrawTextures', window, paperTexture, [], paperRect, 0, 0);
Screen('Flip', window);


% Start loop to monitor the mouse position and check for click
while true
    % Get current coordinates of mouse
    [x, y, buttons] = GetMouse(window);
    
    % Don't let the mouse exceed our paper
    if x > paperlimit(2)
        SetMouse(paperlimit(2), y);
    elseif x < paperlimit(1)
        SetMouse(paperlimit(1), y);
    end
    
    % Scroll the paper
    % Since GetMouseWheel is not supported in linux,
    % I'll use something like hot corners to scroll the paper
    if y > windowRect(4)-2 && offset > offsetRange(1)
        offset = offset - 1;
        SetMouse(x, y-50);
    elseif y < windowRect(2) + 2 && offset < offsetRange(2)
        offset = offset + 1;
        SetMouse(x, y+50);
    end
    
    % Move the survey texture with the offset
    newpaper = paperRect;
    newpaper(2:2:end) = newpaper(2:2:end) + offset * questH;
    Screen('DrawTextures', window, paperTexture, [], newpaper, 0, 0);
    
    % Find the nearest question from mouse
    [~, newcurrQ] = min(abs(questYs+offset*questH - y));
    if newcurrQ ~= currQ
        currA = 0;
    end
    currQ = newcurrQ;

    currY = questYs(currQ) + offset * questH;
    qrect = CenterRectOnPointd(baseQRect, xCenter, currY);
    Screen('FillRect', window, qcolor, qrect); % draw a rect over the question
    
    % Find the nearest answer from mouse
    switch survey_type
        case 'question'
            currAYs = ansYs(currQ, :) + offset*questH;
            if y >= currAYs(1) - ansH(currQ, 1)/2 && y <= currAYs(end) + ansH(currQ, end)
                [~, currA] = min(abs(currAYs - y));
                currY = ansYs(currQ, currA);
                %arect = CenterRectOnPointd([0 0 763 ansH(currQ, currA)], xCenter, currY);
                %arect = CenterRectOnPointd([0 0 595 ansH(currQ, currA)], xCenter, currY);
                arect = CenterRectOnPointd([0 0 1190 ansH(currQ, currA)], xCenter, currY);
            else
                currA = 0;
            end
        case 'likert'
            currAYs = ansYs(currQ) + offset*questH;
            if y >= currAYs - ansH/2 && y <= currAYs + ansH/2
                [~, currA] = min(abs(aCenters - x));
                currY = ansYs(currQ);
                %arect = CenterRectOnPointd([0 0 round(763 / ansNum) fontsize], aCenters(currA), currY);
                %arect = CenterRectOnPointd([0 0 round(595 / ansNum) fontsize], aCenters(currA), currY);
                arect = CenterRectOnPointd([0 0 round(1190 / ansNum) fontsize], aCenters(currA), currY);
            else
                currA = 0;
            end
    end
    
    if currA % If any answer gets hovered
        if any(buttons) % And if any button gets clicked
            tempRects(:, currQ) = arect;
            selects(currQ, :) = 0;
            selects(currQ, currA) = 1;
        end
        arect(2:2:end) = arect(2:2:end) + offset * questH;
        Screen('FrameRect', window, acolor, arect); % draw a rect over the answer
    end
    % Draw rects to identify selected answers
    k = find(selects);
    if ~isempty(k) % check if any answer been selected
        seleRects = tempRects;
        seleRects(2:2:end, :) = seleRects(2:2:end, :) + offset * questH;
        Screen('FillRect', window, scolor, seleRects);
    end

    Screen('Flip', window);

    % If all questions have been answered, quit the survey after 3 secs
    if size(k, 1) == questNum
        WaitSecs(3);
        break
    end

    % Do not go back until all buttons are released
    while find(buttons)
        [x, y, buttons] = GetMouse(window);
    end
end

%======================================================
%               Clean up
%======================================================
                
% Get the results
[row, col] = find(selects);
selects = [row, col];
selects = sortrows(selects, 1);

% save results to .mat file
save(surveyDataFile, 'selects');
selects % show in command line

WaitSecs(1);
Screen('Flip', window);

% End of survey
DrawFormattedText(window, ["Kérdőív vége. ", char(10), char(10), "Köszönjük a kitöltést."], 'center', 'center', 0);
Screen('Flip', window);
WaitSecs(3);

Screen('Close');
sca;

endfunction