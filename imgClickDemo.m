function imgClickDemo
%% Demo for displaying images and registering mouse clicks on it
%
% As of now, it displays three images on the top half of the screen.
%
% Left mouse clicks initiate a counter (of clicks on images) in the
% bottom half of the screen and add plus one to the relevant number. 
%
% Right clicks subtract one from the relevant counter.
%
% Uses hardcoded locations, params, etc.
%
% Times out after "timeout" seconds or you can exit by pressing ESC
%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%    Magic numbers / hardcoded params    %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% about images
imgDir = '/home/adamb/Pictures/';
imgFiles = {'kaktusz.jpg';...
             'labda.png';...
             'talicska.jpeg'};
imgNo = length(imgFiles);
imgLoc = [0.25, 0.25;...  % defines img center coordinates (x, y) in scale 0-1, where (0, 0) is the top left corner
          0.5, 0.25;...
          0.75, 0.25];
imgTargetSize = [150, 150];  % width, height in pixels

% psychtoolbox and control params
backgrColor = 255;  % white background
instrTime = 8;  % time for displaying instructions
timeout = 30;  % max wait time to quit
exitKey = 'Escape';
addButtonState = [1 0 0];  % mouse button vector for left click
subtractButtonState = [0 0 1];  % mouse button vector for right click

% about counters
counterLoc = [0.25, 0.8;...  % similarly to "imgLoc"
          0.5, 0.8;...
          0.75, 0.8];
counterRectSize = [150, 150];
txtColor = [0, 0, 0];
txtSize = 36;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%    Prepare images    %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load images into cell array, display their sizes
imgs = cell(imgNo, 1);
imgSizes = nan(imgNo, 3);
for i = 1:imgNo
    imgs{i} = imread([imgDir, imgFiles{i}]);
end
disp([char(10), 'Loaded ', num2str(imgNo), ' images, with sizes:']);
for i = 1:imgNo
    imgSizes(i, :) = size(imgs{i});
    disp(imgSizes(i,:));
end

% do a very crude cropping if image dims 1-2 are different,
% just simply chop off from the larger dim
if any(imgSizes(:, 1)-imgSizes(:, 2) ~= 0)
    idx = find(imgSizes(:, 1)-imgSizes(:, 2) ~= 0);
    for i = idx'
        if imgSizes(idx, 1) > imgSizes(idx, 2)
            imgs{idx} = imgs{idx}(1:imgSizes(idx, 2), :, :);
        elseif imgSizes(idx, 1) < imgSizes(idx, 2)
            imgs{idx} = imgs{idx}(:, 1:imgSizes(idx, 1), :);
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%    Psychtoolbox init    %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% put everything psychtoolbox-related in a try-loop
try

    PsychDefaultSetup(2);

    % detect screens, use external / secondary screen if there is one
    screens = Screen('Screens');
    screenNumber = max(screens);

    % open onscreen window
    [onWin, onWinRect] = Screen('OpenWindow', screenNumber, backgrColor);

    % get frame interval
    ifi = Screen('GetFlipInterval', onWin);
    % get size in pixels
    [xPix, yPix] = Screen('WindowSize', onWin);
    % get coordinates of center
    [xC, yC] = RectCenter(onWinRect);
    % alpha-blending for smooth (anti-aliased) lines
    Screen('BlendFunction', onWin, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % set text size
    Screen('TextSize', onWin, txtSize);

    % set priority
    topPriorityLevel = MaxPriority(onWin);
    Priority(topPriorityLevel);

    % dummy calls
    GetSecs; WaitSecs(0.5); KbCheck;

    % create textures from images
    imgTextures = nan(imgNo, 1);
    for i = 1:imgNo
        imgTextures(i) = Screen('MakeTexture', onWin, imgs{i});
    end

    % get destination rectangles for images
    % they are all sized "imgTargetSize", centered on the coordinates in "imgLoc"
    destRect = nan(4, imgNo);
    baseRect = [0, 0, imgTargetSize(1), imgTargetSize(2)];  % default rect in top-left, with width and height given by imgTargetSize
    for i = 1:imgNo
        destRect(:, i) = CenterRectOnPoint(baseRect, imgLoc(i, 1)*xPix, imgLoc(i, 2)*yPix);
    end

    % get rectangles for counters
    counterRect = nan(4, imgNo);
    baseRect = [0, 0, counterRectSize(1), counterRectSize(2)];
    for i = 1:imgNo
        counterRect(:, i) = CenterRectOnPoint(baseRect, counterLoc(i, 1)*xPix, counterLoc(i, 2)*yPix);
    end

    % set mouse init position
    SetMouse(xC, yC, onWin);

    % instructions
    instrText = ['Just click around on the images you will see,' char(10),... 
               'try left-right mouse clicks, see what they do.', char(10), char(10),...
                'We start in a moment...'];
    DrawFormattedText(onWin, instrText, 'center', 'center', txtColor);
    Screen('Flip', onWin);
    WaitSecs(instrTime);

    % display scaled images
    Screen('DrawTextures', onWin, imgTextures, [], destRect);

    % flip window, get timestamp
    firstFlip = Screen('Flip', onWin);


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%    Mouse tracking loop    %%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % preallocate flags, vars
    oldCounterState = zeros(imgNo, 1);
    counterState = zeros(imgNo, 1);
    counterStarted = zeros(imgNo, 1);

    % wait for key press or maximum allowed time
    while GetSecs < firstFlip + timeout

        changeFlag = false;

        % check for exit key
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown && find(keyCode) == KbName(exitKey)
            break;
        end

        % track mouse, give location relative to onscreen window
        [xM, yM, buttons] = GetMouse(onWin);

        % if there is a button click, check if mouse cursor is in one of the 
        % image rects
        if any(buttons)
            mouseInRect = xM > destRect(1, :) & xM < destRect(3, :) & yM > destRect(2, :) & yM < destRect(4, :);  % returns logical row vector
            % if cursor is in one of the image rects, check for type of click
            if any(mouseInRect)
                if isequal(buttons, addButtonState)
                    oldCounterState = counterState;
                    counterState(mouseInRect) = counterState(mouseInRect) + 1;
                    changeFlag = true;
                elseif isequal(buttons, subtractButtonState) && counterState(mouseInRect) > 0
                    oldCounterState = counterState;
                    counterState(mouseInRect) = counterState(mouseInRect) - 1;
                    changeFlag = true;
                end
            end
            % wait till button is released (click ended)
            while any(buttons)
                WaitSecs(0.01);  % 10 msecs
                [xM, yM, buttons] = GetMouse(onWin);
            end  % while
        end  % if any(buttons)

        % init / adjust counter
        if changeFlag
            % draw updated counters
            for i = 1:imgNo
                if counterState(i) > 0
                    DrawFormattedText(onWin, [num2str(counterState(i)), 'x'],... 
                            'center', 'center', txtColor, [], [], [], [], [],... 
                            counterRect(:, i)');
                end  % if
            end  % for
            % display scaled images
            Screen('DrawTextures', onWin, imgTextures, [], destRect);
            % flip
            Screen('Flip', onWin);
        end  % if changeFlag

    end  % while

    % goodbye
    disp('Thanks for shopping with us!');
    sca;

% call Screen('CloseAll') and rethrow error if stg went south
catch ME
    sca;
    rethrow(ME)

end


return




