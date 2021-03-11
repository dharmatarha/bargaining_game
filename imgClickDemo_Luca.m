%function imgClickDemo
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

% which column of tokens, prices should we use 1-2
player = 1;

% about images
%imgDir = '/home/adamb/Pictures/';
imgDir = 'C:\Users\Luca\Documents\mta-ttk anyagok\alku_jatek\';
imgFiles = {'kerti_szerszamok.png';...
             'minitraktor.jpg';...
             'talicska.jpeg';...
             'viragfold.jpg';...
             'kanna.png';...
             'magok.jpg';...
             'locsolocso.jpg';...
             'kerteszsityak.jpg'};
imgNo = length(imgFiles);
imgLoc = [0.2, 0.25;...
          0.4, 0.25;...  % defines img center coordinates (x, y) in scale 0-1, where (0, 0) is the top left corner
          0.6, 0.25;...
          0.8, 0.25;...
          0.2, 0.6;...
          0.4, 0.6;...
          0.6, 0.6;...
          0.8, 0.6];
imgTargetSize = [150, 150];  % width, height in pixels

% psychtoolbox and control params
backgrColor = 255;  % white background
instrTime = 3;  % time for displaying instructions
timeout = 30;  % max wait time to quit
exitKey = 'Escape';
addButtonState = [1 0 0];  % mouse button vector for left click
subtractButtonState = [0 0 1];  % mouse button vector for right click

% about counters
counterLoc = [0.2, 0.44;...  % similarly to "imgLoc"
          0.4, 0.44;...
          0.6, 0.44;...
          0.8, 0.44;...
          0.2, 0.78;...
          0.4, 0.78;...
          0.6, 0.78;...
          0.8, 0.78];
counterRectSize = [150, 150];
txtColor = [0, 0, 0];
txtSize = 36;

% randomized prices (predefined manually with initConfGenerator)
tokenPrices = tmpPrices(:, player);            
priceLoc = [0.2, 0.38;...
            0.4, 0.38;...
            0.6, 0.38;...
            0.8, 0.38;...
            0.2, 0.72;...
            0.4, 0.72;...
            0.6, 0.72;...
            0.8, 0.72];
priceRectSize = [150, 150];
tokenAmounts = tmpTokens(:, player);


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
%disp([newline, 'Loaded ', num2str(imgNo), ' images, with sizes:']);
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
    
    Screen('Preference', 'SkipSyncTests', 1);

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
    
    % rectangles for prices
    priceRect = nan(4, imgNo);
    baseRect = [0, 0, priceRectSize(1), priceRectSize(2)];
    for i = 1:imgNo
        priceRect(:,i) = CenterRectOnPoint(baseRect, priceLoc(i, 1)*xPix, priceLoc(i, 2)*yPix);
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
    
    offWin = Screen('OpenOffscreenWindow', -1);
    for i = 1:imgNo
         pricesText = num2str(tokenPrices(i,1)), '$';
    end

    % display scaled images
    Screen('DrawTextures', onWin, imgTextures, [], destRect);
    %Screen('DrawTexture', offWin, pricesText, [], priceRect);
            
    % flip window, get timestamp
    firstFlip = Screen('Flip', onWin);


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%    Mouse tracking loop    %%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % preallocate flags, vars
    oldCounterState = zeros(imgNo, 1);
    counterState = zeros(imgNo, 1);
    counterStarted = zeros(imgNo, 1);  
    
    % counter starts at the number of tokens the player has
    for i = 1:imgNo
      counterState(i,:) = tokenAmounts(i,:);
    end
    
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
            
           % for i = 1:imgNo
                %if counterState(i) > 0
                %  DrawFormattedText(onWin, [num2str(tokenPrices(i,1)), '$'], 'center',...
                %      'center', txtColor, [], [], [], [], [], priceRect(:,i)');
                %end % if
           % end %for
            
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


%return




