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

% get an easy config from the .mat file in the repo
tmp = load('easyConfigs.mat');
conf = tmp.easyConfigs(1);

% extract prices, token distribution and must-haves
tokenPrices = conf.prices(:, player);
tokenAmounts = conf.tokens(:, player);
mustHaves = conf.mustHaves(:, player);


% about images
imgDir = '/home/adamb/Pictures/bg_set/';
imgFiles = {'apple1.jpg';...
             'onion1.jpg';...
             'lipstick1.jpg';...
             'cake1.jpg';...
             'hanger1.jpg';...
             'leaf1.jpg';...
             'paperclip1.jpg';...
             'stapler1.jpg'};
         
% imgDir = 'C:\Users\Luca\Documents\mta-ttk anyagok\alku_jatek\';
% imgFiles = {'kerti_szerszamok.png';...
%              'minitraktor.jpg';...
%              'talicska.jpeg';...
%              'viragfold.jpg';...
%              'kanna.png';...
%              'magok.jpg';...
%              'locsolocso.jpg';...
%              'kerteszsityak.jpg'};

imgNo = length(imgFiles);
imgLoc = [0.2, 0.10;...  % defines img center coordinates (x, y) in scale 0-1, where (0, 0) is the top left corner
          0.4, 0.10;...  
          0.6, 0.10;...
          0.8, 0.10;...
          0.2, 0.30;...
          0.4, 0.30;...
          0.6, 0.30;...
          0.8, 0.30];
% imgTargetSize = [150, 150];  % width, height in pixels
imgTargetSize = [120, 140];  % width, height in pixels

% psychtoolbox and control params
backgrColor = [255 255 255 0];  % white transparent background
instrTime = 1;  % time for displaying instructions
timeout = 10;  % max wait time to quit
exitKey = 'Escape';
addButtonState = [1 0 0];  % mouse button vector for left click
subtractButtonState = [0 0 1];  % mouse button vector for right click
txtColor = [0, 0, 0];  % black letters
txtSize = 30;

% about counters
counterLoc = [0.2, 0.65;...  % similarly to "imgLoc"
          0.4, 0.65;...
          0.6, 0.65;...
          0.8, 0.65;...
          0.2, 0.85;...
          0.4, 0.85;...
          0.6, 0.85;...
          0.8, 0.85];
counterRectSize = [120, 140];

priceLoc = [0.23, 0.20;...
            0.43, 0.20;...
            0.63, 0.20;...
            0.83, 0.20;...
            0.23, 0.40;...
            0.43, 0.40;...
            0.63, 0.40;...
            0.83, 0.40];
priceRectSize = [60, 60];

tokenNoLoc = [0.17, 0.20;...
            0.37, 0.20;...
            0.57, 0.20;...
            0.77, 0.20;...
            0.17, 0.40;...
            0.37, 0.40;...
            0.57, 0.40;...
            0.77, 0.40];
tokenNoRectSize = [60, 60];

% % randomized prices (predefined manually with initConfGenerator)
% tokenPrices = tmpPrices(:, player);            
% tokenAmounts = tmpTokens(:, player);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%    Prepare images    %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load images into cell array, display their sizes
imgs = cell(imgNo, 1);
imgSizes = nan(imgNo, 2);
for i = 1:imgNo
    imgs{i} = imread([imgDir, imgFiles{i}]);
end
disp([char(10), 'Loaded ', num2str(imgNo), ' images, with sizes:']);
%disp([newline, 'Loaded ', num2str(imgNo), ' images, with sizes:']);
for i = 1:imgNo
    imgSizes(i, :) = size(imgs{i});
    disp(imgSizes(i,:));
end

% resize pictures in advance
disp([char(10), 'Resizing images to target rect size: ', num2str(imgTargetSize)]),
for i = 1:imgNo
    imgs{i} = imresize(imgs{i}, imgTargetSize);
end
disp('Done');

% % do a very crude cropping if image dims 1-2 are different,
% % just simply chop off from the larger dim
% if any(imgSizes(:, 1)-imgSizes(:, 2) ~= 0)
%     idx = find(imgSizes(:, 1)-imgSizes(:, 2) ~= 0);
%     for i = idx'
%         if imgSizes(idx, 1) > imgSizes(idx, 2)
%             imgs{idx} = imgs{idx}(1:imgSizes(idx, 2), :, :);
%         elseif imgSizes(idx, 1) < imgSizes(idx, 2)
%             imgs{idx} = imgs{idx}(:, 1:imgSizes(idx, 1), :);
%         end
%     end
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%    Psychtoolbox init    %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% put everything psychtoolbox-related in a try-loop
try

    PsychDefaultSetup(2);

    Screen('Preference', 'SkipSyncTests', 2);

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

    % rectangles for prices
    priceRect = nan(4, imgNo);
    baseRect = [0, 0, priceRectSize(1), priceRectSize(2)];
    for i = 1:imgNo
        priceRect(:,i) = CenterRectOnPoint(baseRect, priceLoc(i, 1)*xPix, priceLoc(i, 2)*yPix);
    end    

    % rectangles for token amounts (numbers)
    tokenNoRect = nan(4, imgNo);
    baseRect = [0, 0, tokenNoRectSize(1), tokenNoRectSize(2)];
    for i = 1:imgNo
        tokenNoRect(:,i) = CenterRectOnPoint(baseRect, tokenNoLoc(i, 1)*xPix, tokenNoLoc(i, 2)*yPix);
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

    % use an offscreen window to put the price texts in a tecture 
    offWin = Screen('OpenOffscreenWindow', onWin, backgrColor);  % white transparent background, so we can overlay it on other textures
    % set text size
    Screen('TextSize', offWin, txtSize);
    for i = 1:imgNo
        DrawFormattedText(offWin, [num2str(tokenPrices(i)), ' ft'],...
            'center', 'center', txtColor, [], [], [], [], [],...
            priceRect(:, i)');
    end

    % put token images into same offscreen window
    Screen('DrawTextures', offWin, imgTextures, [], destRect);
    
%     % display token images
%     Screen('DrawTextures', onWin, imgTextures, [], destRect);
    
    % display tokens & prices using the offscreen window
    Screen('DrawTexture', onWin, offWin);
             
    % draw the token numbers as well - these will be updated all the time
    for i = 1:imgNo
        DrawFormattedText(onWin, [num2str(tokenAmounts(i)), 'x'],...
            'center', 'center', txtColor, [], [], [], [], [],...
            tokenNoRect(:, i)');
    end
    
    % flip window, get timestamp
    firstFlip = Screen('Flip', onWin);

%     WaitSecs(6);
%     
%     % goodbye
%     disp('Thanks for shopping with us!');
%     sca;
% 
% % call Screen('CloseAll') and rethrow error if stg went south
% catch ME
%     sca;
%     rethrow(ME)
% 
% end    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%    Mouse tracking loop    %%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % preallocate flags, vars
    oldCounterState = zeros(imgNo, 1);
    counterState = zeros(imgNo, 1);
    counterStarted = zeros(imgNo, 1);  
    oldTokenState = tokenAmounts;
    tokenState = tokenAmounts;
    
%     % counter starts at the number of tokens the player has
%     for i = 1:imgNo
%       counterState(i,:) = tokenAmounts(i,:);
%     end
    
    
    changeFlag = false;
    % wait for key press or maximum allowed time
    while GetSecs < firstFlip + timeout

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
                if isequal(buttons, addButtonState) && tokenState(mouseInRect) > 0
                    oldCounterState = counterState;
                    oldTokenState = tokenState;
                    counterState(mouseInRect) = counterState(mouseInRect) + 1;
                    tokenState(mouseInRect) =  tokenState(mouseInRect)-1;
                    changeFlag = true;
                elseif isequal(buttons, subtractButtonState) && counterState(mouseInRect) > 0
                    oldCounterState = counterState;
                    oldTokenState = tokenState;
                    counterState(mouseInRect) = counterState(mouseInRect) - 1;
                    tokenState(mouseInRect) =  tokenState(mouseInRect)+1;
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
            
            % draw updated token amounts
            for i = 1:imgNo
                DrawFormattedText(onWin, [num2str(tokenState(i)), 'x'],... 
                        'center', 'center', txtColor, [], [], [], [], [],... 
                        tokenNoRect(:, i)');
            end  % for
            
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
            
            % draw images & prices
            Screen('DrawTextures', onWin, offWin);
            
            % flip
            Screen('Flip', onWin);
            
            % set change flag back to default
            changeFlag = false;
            
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




