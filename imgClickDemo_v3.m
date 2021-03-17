%function imgClickDemo
%% Demo for rudimentary first version of Bargaining Game
%
% The display consists of two main parts, the "shelves" and the "counter".
% The items (tokens) the player has belong to the shelves. 
% Whenever an offer is to be made, tokens are placed on the counter by
% clicking on the images of tokens on the shelves. That's it practically.
% 
% The shelves take the upper part of the screen, while the counter is located 
% at the bottom.
%
% Left mouse clicks "add" a token from the shelves to the counter, while right 
% clicks "place back" a token from the counter to the shelves.
%
% Uses hardcoded locations, params, etc.
%
% Times out after "timeout" seconds or you can exit by pressing ESC
%
% Current version limits the number of types of tokens allowed on the 
% counter ("counterTypesMax")
%
%


pkg load image
pkg load sockets


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

% max number of types of tokens on counter
counterTypesMax = 3;


% about images
%imgDir = '/home/adamb/Pictures/bg_set/';
%imgFiles = {'apple1.jpg';...
%             'onion1.jpg';...
%             'lipstick1.jpg';...
%             'cake1.jpg';...
%             'hanger1.jpg';...
%             'leaf1.jpg';...
%             'paperclip1.jpg';...
%             'stapler1.jpg'};
imgDir = '/home/adamb/Pictures/';
imgFiles = {'ollo.jpg';...
             'locsolocso.jpg';...
             'minitraktor.jpg';...
             'kombifogo.jpg';...
             'kaktusz.jpg';...
             'magok.jpg';...
             'mozsar.jpg';...
             'konzervdoboz.jpg'};

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

% about counters - depends on "counterTypesMax"
counterLoc = [0.10, 0.75;;...  % positions similarly to "imgLoc"
          0.25, 0.75;...
          0.40, 0.75;...
          0.55, 0.75];
% sanity check - compatibilty with "counterTypesMax"
if counterTypesMax > size(counterLoc, 1)
    error(['There are not enough locations specified in "counterLoc" for the ',...
    'allowed number of token types on the counter!']);
end
counterRectSize = [120, 140];

% locations and rect size for token prices on the shelves
priceLoc = [0.23, 0.20;...
            0.43, 0.20;...
            0.63, 0.20;...
            0.83, 0.20;...
            0.23, 0.40;...
            0.43, 0.40;...
            0.63, 0.40;...
            0.83, 0.40];
priceRectSize = [60, 60];

% locations and rect size for token numbers on the shelves
shelvesNoLoc = [0.17, 0.20;...
            0.37, 0.20;...
            0.57, 0.20;...
            0.77, 0.20;...
            0.17, 0.40;...
            0.37, 0.40;...
            0.57, 0.40;...
            0.77, 0.40];
shelvesNoRectSize = [60, 60];

% locations and rect size for token numbers on the shelves
% (below token images on counter)
counterNoLoc = counterLoc;
counterNoLoc(:, 2) = counterNoLoc(:, 2)+0.10;
counterNoRectSize = [60, 60];

% Network address of remote PC for handshake and udp communication
remoteIP = '10.160.21.115';


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

% resize pictures in advance
disp([char(10), 'Resizing images to target rect size: ', num2str(imgTargetSize)]),
for i = 1:imgNo
    imgs{i} = imresize(imgs{i}, imgTargetSize);
end
disp('Done');


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


    %% Define rectangles for displaying token images, prices, numbers, etc.

    % get destination rectangles for tokens on the "shelves" (token images)
    % they are all sized "imgTargetSize", centered on the coordinates in "imgLoc"
    shelvesRect = nan(4, imgNo);
    baseRect = [0, 0, imgTargetSize(1), imgTargetSize(2)];  % a default rect in top-left, with width and height given by imgTargetSize
    for i = 1:imgNo
        shelvesRect(:, i) = CenterRectOnPoint(baseRect, imgLoc(i, 1)*xPix, imgLoc(i, 2)*yPix);
    end

    % get rectangles for prices of tokens on the shelves 
    % (text boxes below and to the right of token images)
    priceRect = nan(4, imgNo);
    baseRect = [0, 0, priceRectSize(1), priceRectSize(2)];
    for i = 1:imgNo
        priceRect(:,i) = CenterRectOnPoint(baseRect, priceLoc(i, 1)*xPix, priceLoc(i, 2)*yPix);
    end    

    % get rectangles for token amounts on the shelves (number of available tokens, 
    % text boxes below and to the left of token images)
    shelvesNoRect = nan(4, imgNo);
    baseRect = [0, 0, shelvesNoRectSize(1), shelvesNoRectSize(2)];
    for i = 1:imgNo
        shelvesNoRect(:,i) = CenterRectOnPoint(baseRect, shelvesNoLoc(i, 1)*xPix, shelvesNoLoc(i, 2)*yPix);
    end    

    % get rectangles for token images on the counter
    counterRect = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterRectSize(1), counterRectSize(2)];
    for i = 1:counterTypesMax
        counterRect(:, i) = CenterRectOnPoint(baseRect, counterLoc(i, 1)*xPix, counterLoc(i, 2)*yPix);
    end

    % get rectangles for token numbers on the counter
    % (text boxes below the token images)
    counterNoRect = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterNoRectSize(1), counterNoRectSize(2)];
    for i = 1:counterTypesMax
        counterNoRect(:, i) = CenterRectOnPoint(baseRect, counterNoLoc(i, 1)*xPix, counterNoLoc(i, 2)*yPix);
    end


    %% Prepare a basic "shelves" texture with token images and prices, using an
    % offscreen window

    shelvesWin = Screen('OpenOffscreenWindow', onWin, backgrColor);  % white transparent background, so we can overlay it on other textures
    % set text size
    Screen('TextSize', shelvesWin, txtSize);
    % draw prices
    for i = 1:imgNo
        DrawFormattedText(shelvesWin, [num2str(tokenPrices(i)), ' ft'],...
            'center', 'center', txtColor, [], [], [], [], [],...
            priceRect(:, i)');
    end
    % put token images into same offscreen window
    Screen('DrawTextures', shelvesWin, imgTextures, [], shelvesRect);


    %% Prepare each token image as a separate texture 
    % for fast loading and placing on the counter. 
    % Brute force version: generate a texture for each image in each counter location.
    counterImgTex = zeros(imgNo, counterTypesMax);
    for i = 1:imgNo  % loop through images / tokens
        tmpTex = Screen('MakeTexture', onWin, imgs{i});
        for z = 1:counterTypesMax  % loop through potential counter locations
            counterImgTex(i, z) = Screen('OpenOffScreenWindow', onWin, backgrColor);
            Screen('DrawTexture', counterImgTex(i, z), tmpTex, [], counterRect(:, z)');
        end
    end


    % set mouse init position
    SetMouse(xC, yC, onWin);

    % draw and display instructions, wait a bit
    instrText = ['Just click around on the images you will see,' char(10),... 
               'try left-right mouse clicks, see what they do.', char(10), char(10),...
                'We start in a moment...'];
    DrawFormattedText(onWin, instrText, 'center', 'center', txtColor);
    Screen('Flip', onWin);
    WaitSecs(instrTime);

    % display tokens & prices using the basic "shelves" texture
    Screen('DrawTexture', onWin, shelvesWin);

    % draw the token numbers as well - these will be updated all the time
    for i = 1:imgNo
        DrawFormattedText(onWin, [num2str(tokenAmounts(i)), 'x'],...
            'center', 'center', txtColor, [], [], [], [], [],...
            shelvesNoRect(:, i)');
    end

    % flip window, get timestamp
    firstFlip = Screen('Flip', onWin);

%    WaitSecs(6);
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
    counterState = tokenAmounts;
    counterStarted = zeros(imgNo, 1);  
    shelvesState = tokenAmounts;
    changeFlag = false;  % flag for changing the content of the display
    shelves2counter = zeros(imgNo, 1);  % mapping between tokens on shelves and counter positions
    counter2shelves = zeros(counterTypesMax, 1);  % mapping from counter positions to shelves


    % wait for key press or maximum allowed time
    while GetSecs < firstFlip + timeout

        % check for exit key
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown && find(keyCode) == KbName(exitKey)
            break;
        end

        % track mouse, give location relative to onscreen window
        [xM, yM, buttons] = GetMouse(onWin);


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%    Click detection part - decide what to do     %%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % if there is a button click, check if mouse cursor is in one of the 
        % image rects
        if any(buttons)
            mouseInRect = xM > shelvesRect(1, :) & xM < shelvesRect(3, :) & yM > shelvesRect(2, :) & yM < shelvesRect(4, :);  % returns logical row vector

            % if cursor is in one of the image rects, check if that token is on the counter
            if any(mouseInRect)

                % if token is already on the counter, check the type of button click and if the action is allowed
                if shelves2counter(mouseInRect)

                    % if player added a token from shelves to counter and there was at least one token on shelves,
                    % adjust the state vectors and set changeFlag for redrawing
                    if isequal(buttons, addButtonState) && shelvesState(mouseInRect) > 0
                        counterState(mouseInRect) = counterState(mouseInRect) + 1;
                        shelvesState(mouseInRect) =  shelvesState(mouseInRect)-1;
                        changeFlag = true;

                    % if player took a token back from the counter and there was at least one token on counter,
                    % adjust the state vectors and set changeFlag for redrawing,
                    % further check if token is off the counter completely
                    elseif isequal(buttons, subtractButtonState) && counterState(mouseInRect) > 0
                        counterState(mouseInRect) = counterState(mouseInRect) - 1;
                        shelvesState(mouseInRect) =  shelvesState(mouseInRect)+1;
                        changeFlag = true;
                        % if token is off the counter, set the mappings back to zero
                        if counterState(mouseInRect) == 0
                            counter2shelves(shelves2counter(mouseInRect)) = 0;
                            shelves2counter(mouseInRect) = 0;
                        end
                    end

                % if token is not on the counter yet, check the type of button click
                elseif shelves2counter(mouseInRect) == 0

                    % if player added a token from shelves to counter and there was at least one token on shelves,
                    % check if there is space on the counter
                    if isequal(buttons, addButtonState) && shelvesState(mouseInRect) > 0
                        % if there is any space, place the token there, adjust state vectors,
                        % and set changeFlag for rewdrawing,
                        % otherwise ignore the click
                        if any(counter2shelves==0)
                            % find the smallest index for an empty space on counter
                            counterSpaceIdx = find(counter2shelves==0, 1);
                            % adjust counter2shelves mapping
                            counter2shelves(counterSpaceIdx) = find(mouseInRect);
                            % adjust shelves2counter mapping
                            shelves2counter(mouseInRect) = counterSpaceIdx;
                            % adjust state vectors, set changeFlag
                            counterState(mouseInRect) = counterState(mouseInRect) - 1;
                            shelvesState(mouseInRect) =  shelvesState(mouseInRect)+1;
                            changeFlag = true;
                        end  % if any(counter2shelves==0)

                    end  % if isequal(buttons...

                end  % if shelves2coutner(mouseInRect)

            end  % if any(mouseInRect)

            % wait till button is released (click ended)
            while any(buttons)
                WaitSecs(0.01);  % 10 msecs
                [xM, yM, buttons] = GetMouse(onWin);
            end  % while

        end  % if any(buttons)


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%    Communication part - sending UDP packages    %%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if changeFlag
            


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%    Draw token numbers and counter images if needed %%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % if the screen needs to be updated
        if changeFlag

            % draw updated token amounts on shelves
            for i = 1:imgNo
                DrawFormattedText(onWin, [num2str(shelvesState(i)), 'x'],... 
                        'center', 'center', txtColor, [], [], [], [], [],... 
                        shelvesNoRect(:, i)');
            end  % for

            % draw updated counter numbers + corresponding image
            for i = 1:counterTypesMax
                if counter2shelves(i) > 0
                    DrawFormattedText(onWin, [num2str(counterState(counter2shelves(i))), 'x'],... 
                            'center', 'center', txtColor, [], [], [], [], [],... 
                            counterNoRect(:, i)');
                    Screen('DrawTexture', onWin, counterImgTex(counter2shelves(i), i));
                end  % if
            end  % for


            % draw images & prices for shelves
            Screen('DrawTextures', onWin, shelvesWin);

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




