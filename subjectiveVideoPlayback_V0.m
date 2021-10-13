function subjectiveVideoPlayback_V0(pairNo, labName)
%% Initial video playback script for the free conversation task (or 
%% the Bargaining Game) with subjective evaluation of predictability 
%% aka a slider that moves horizontally with the mouse
%
% - movement of mouse on the slider is recorded at every video frame
% - slider position is defined relative to the screen size 
% - a line indicating the center of the scale is optional
% - exits after video is done playing or max timeout is reached (vidLength) or 
%   if you press ESC
% 
% Usage:
%         pairNo (1:999), labName ("Mordor", "Gondor") is required
%         video dir is hardcoded as: /home/mordor/...
%

if ~isnumeric(pairNo) || ~ismember(pairNo, 1:999)
    error("Input arg pairNo should be one of 1:999!");
endif
if ~ischar(labName) || ~ismember(labName, {"Mordor", "Gondor"})
    error("Input arg labName should be one of Mordor/Gondor as char array!");
endif


% screen params
backgrColor = [255 255 255];  % white background
windowTextSize = 26;  % general screen openwindow text size
windowSize = [0 0 1920 1080];
vidLength = 10;
instruction = ["A következő részben vissza fogjuk játszani az előző beszélgetést." char(10),...
              "A feladatot az lesz, hogy a csúszka segítségével folyamtosan jelezd, " char(10),...
              "hogy az adott pillanatban mennyire volt meglepő amit a másik személy mondott." char(10),...
              char(10), "A skálán az 'Egyáltalán nem lepődtem meg' és a 'Nagyon meglepődtem' " char(10),...
              "között tudsz mozogni az egérrel."];
instr_time = 5;
txtColor = [0, 0, 0];  % black letters
vidRect = [round(windowSize(3)/8) 0 round(windowSize(3)/8*7) 864];
%vidRect = [round(windowSize(3)/8) 0 round(windowSize(3)/8*7) windowSize-(windowSize(4)/100*20)];
%vidRect = [96 0 1728 972];

% video folders
vidDir = '/home/lucab/Videos/';
%vidDir = 'C:\Users\Luca\Videos\';
tmpdir = dir(vidDir);
moviename = ["pair", num2str(pairNo), labName, ".mov"];
%moviename = ["pair", num2str(pairNo), labName, ".mp4"];
moviefilename = [vidDir, moviename];

%% Psychtoolbox initializations

PsychDefaultSetup(1);
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));
RestrictKeysForKbCheck(KbName('ESCAPE'));  % only report ESCape key press via KbCheck
GetSecs; WaitSecs(0.1);  % dummy calls

try
  
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', screen, backgrColor, windowSize);
    Screen('TextSize', win, 24); 
    %Screen('Flip',win); 
    HideCursor(win, 0);
    
    % display instruction for given time 
    DrawFormattedText(win, instruction, 'center', 'center', txtColor);
    Screen("Flip", win);
    WaitSecs(instr_time);
   
%%%%%%%%%%%% Slider params %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    question      = "Mennyire meglepő?";
    anchors       = {'nem meglepő', 'meglepő'};
    rect          = windowSize;
    center        = round([rect(3) rect(4)]/2);
    lineLength    = 10; % length of the scale
    width         = 3; % width of scale
    sliderwidth   = 5; 
    scalaLength   = 0.8; % length of scale relative to window size
    scalaPosition = 0.9; % scale position relative to screen (0 is top, 1 is bottom)
    sliderColor   = [0 125 250]; % light blue 
    scaleColor    = [0 0 0];
    device        = 'mouse';
    %aborttime     = Inf;
    %responseKeys  = [KbName('return') KbName('LeftArrow') KbName('RightArrow')];
    GetMouseIndices;
    startPosition = 'left'; % position of scale
    displayPos    = true; % display numeric position of slider (0-100)
    rangeType     = 2; % The type of range of the scale. If 1,
%                        then the range is from -100 to 100. If 2, then the
%                        range is from 0 to 100
    stepSize      = 1; % the number of pixel the slider moves with each step.
    
    % Sets the default key depending on choosen device
    if strcmp(device, 'mouse')
      mouseButton   = 1; % X mouse button
    end
    
    %% Checking number of screens and parsing size of the global screen
    screens       = Screen('Screens');
    if length(screens) > 1 % Checks for the number of screens
      screenNum        = 1;
    else
      screenNum        = 0;
    end
    globalRect          = Screen('Rect', screenNum);
    
    %% Coordinates of scale lines and text bounds
    if strcmp(startPosition, 'right')
      x = globalRect(3)*scalaLength;
    elseif strcmp(startPosition, 'center')
      x = globalRect(3)/2;
    elseif strcmp(startPosition, 'left')
      x = globalRect(3)*(1-scalaLength);
    else
      error('Only right, center and left are possible start positions');
    end
    SetMouse(round(x), round(rect(4)*scalaPosition), win, 0);
    %midTick    = [center(1) rect(4)*scalaPosition - lineLength - 5 center(1) rect(4)*scalaPosition  + lineLength + 5];
    leftTick   = [rect(3)*(1-scalaLength) rect(4)*scalaPosition - lineLength rect(3)*(1-scalaLength) rect(4)*scalaPosition  + lineLength];
    rightTick  = [rect(3)*scalaLength rect(4)*scalaPosition - lineLength rect(3)*scalaLength rect(4)*scalaPosition  + lineLength];
    horzLine   = [rect(3)*scalaLength rect(4)*scalaPosition rect(3)*(1-scalaLength) rect(4)*scalaPosition];
    if length(anchors) == 2
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{2}))];
    else
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{3}))];
    end

    % Calculate the range of the scale, which will be needed to calculate the
    % position
    scaleRange = round(rect(3)*(1-scalaLength)):round(rect(3)*scalaLength); % Calculates the range of the scale
    scaleRangeShifted = round((scaleRange)-mean(scaleRange)); % Shift the range of scale so it is symmetrical around zero

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%% Opening the movie file %%%%%%%%%%%%%
   
    KbReleaseWait;
    WaitSecs('YieldSecs', 1);
    
    [moviePtr, duration, fps, moviewidth, movieheight, framecount] = Screen('OpenMovie', win, moviefilename);
    disp(["Movie " moviefilename, " opened and ready to play! Moviepointer: ", num2str(moviePtr)]);
      
    % preallocate vector for mouse position per video frame
    sliderPos = nan(framecount,1);
    sliderValueFile = ["pair", num2str(pairNo), labName, "_sliderPosition.mat"];
  
    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    answer = 0;
    slidercount = 0;

%%%%% Drawing just the scale and slider first %%%%%%
    
    ShowCursor('Arrow', win, 0);
    
    % Drawing the question as text
    DrawFormattedText(win, question, 'center', rect(4)*(scalaPosition - 0.03)); 
    
    % Drawing the anchors of the scale as text
    if length(anchors) == 2
      % Only left and right anchors
      DrawFormattedText(win, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Left point
      DrawFormattedText(win, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Right point    
    end
    
    % Drawing the scale
    %Screen('DrawLine', win, scaleColor, midTick(1), midTick(2), midTick(3), midTick(4), width);         % Mid tick
    Screen('DrawLine', win, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
    Screen('DrawLine', win, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
    Screen('DrawLine', win, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line
      
    %Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
    DrawFormattedText(win, "Kezdődik a visszajátszás!", 'center', 'center', txtColor);
    
    Screen('Flip', win);
    WaitSecs(3);
 
%%%%% Playing movie %%%%%
 
    droppedFrames = Screen('PlayMovie', moviePtr, 1);
    WaitSecs(2);
    disp([char(10) 'Starting movie' char(10)]);
    startAt = GetSecs;
    
%%%%%%%%%%%%%%%% Main while loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
 
    %for i = 1:framecount
      
    while ~KbCheck && GetSecs < startAt+vidLength 
      
      tex = Screen('GetMovieImage', win, moviePtr, 1);  
      
      if tex > 0 
        Screen('DrawTexture', win, tex, [], vidRect);  % Draw new texture              
                  
        % Parse user input for x location
        if strcmp(device, 'mouse')
          [x,~,buttons,~,~,~] = GetMouse(win, 0);  
        else
          error('Unknown device');
        end
        
        % Stop at upper and lower bound
        if x > rect(3)*scalaLength
          x = rect(3)*scalaLength;
        elseif x < rect(3)*(1-scalaLength)
          x = rect(3)*(1-scalaLength);
        end
        
        % Drawing the question as text
        DrawFormattedText(win, question, 'center', rect(4)*(scalaPosition - 0.03)); 
        
        % Drawing the anchors of the scale as text
        if length(anchors) == 2
          % Only left and right anchors
          DrawFormattedText(win, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Left point
          DrawFormattedText(win, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Right point
          %else 
          % Left, middle and right anchors
          %DrawFormattedText(win, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Left point
          %DrawFormattedText(win, anchors{2}, 'center',  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Middle point
          %DrawFormattedText(win, anchors{3}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40, [],[],[],[],[],[],[]); % Right point
        end
        
        % Drawing the scale
        %Screen('DrawLine', win, scaleColor, midTick(1), midTick(2), midTick(3), midTick(4), width);         % Mid tick
        Screen('DrawLine', win, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
        Screen('DrawLine', win, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
        Screen('DrawLine', win, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line
        
        % The slider
        Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
        
        % Caculates position
        if rangeType == 1
          position = round((x)-mean(scaleRange)); % Calculates the deviation from the center
          position = (position/max(scaleRangeShifted))*100; % Converts the value to percentage
        elseif rangeType == 2
          position = round((x)-min(scaleRange)); % Calculates the deviation from 0. 
          position = (position/(max(scaleRange)-min(scaleRange)))*100; % Converts the value to percentage 
         
          % store mouse position data 
          sliderPos(count+1, :) = round(position);                   
        end
                 
        % Display position
        if displayPos
          DrawFormattedText(win, num2str(round(position)), 'center', rect(4)*(scalaPosition - 0.05));             
        end              
        
        oldtex = tex;  % Recycle movie image texture
        Screen('Flip', win);  % Show new texture
        count = count + 1;  % counter for movie image                                     
        
      else % if
        WaitSecs('YieldSecs', 0.005);
        Screen('Flip', win);
        
      end % if
                    
    endwhile
   % end % for

%%% Cleaning up 

    save(sliderValueFile, "sliderPos");
 
    Screen('CloseMovie');
    Screen('Close');
    sca;
      
catch ME
    sca;
    rethrow(ME);
    
end %try
    
endfunction
