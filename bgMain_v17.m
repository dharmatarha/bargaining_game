function bgMain_v17(pairNo, player, labName, roundNo, tokenNo, confType, confNo, strangeImgNo)
%% Bargaining Game main experiment
%
% USAGE: bgMain_v17(pairNo, player, labName, roundNo, tokenNo, confType,... 
%                   confNo, strangeImgNo, roundNo)
%
% Function to play a round of Bargaining Game. 
%
% Assumptions:
% - The game is played in Mordor and Gondor labs at TTK, Budapest. The two
%   lab control PCs are on the LAN with predefined IP addresses, open 
%   ports, correct hardware setup.
% - The function is started with matching parameters on both PCs,
%   less than 30 seconds apart.
% - Dependencies UPDhandshake.m and bgParams.m are available.
% - Pre-generated game configs are available.
% - Images are available in the "sorted_BOSS_NOUN_rs_100x100" folder.
% - The function is started with corresponding gstreamer RTP streams for 
%   the webcam feeds.
% - The function is started with corresponding audio stream 
%   (see audioScript_BG)
%
% The goal of the game is to make mutually beneficial deals (bargains)
% while also collecting the "must-have" tokens. Difficulty is set by the
% arguments.
% 
% Game interface:
% The display consists of two main parts, the "shelves" and the "counter".
% The items (tokens) the player has belong to the shelves. The shelves take 
% the upper part of the screen, while the counter is located at the bottom.
% Players can place the tokens on the counter by clicking on the images of 
% tokens on the shelves. Tokens on the counter can be exchanged with the
% other player's tokens placed on the counter by clicking on the "Bargain"
% ("Csere") button.
% Left mouse clicks "add" a token from the shelves to the counter, while
% right clicks "place back" a token from the counter to the shelves.
%
% The game uses hardcoded screen locations and color settings. Screens are
% expected to have a resolution of 1920x1080.
%
% The game runs for a maximum of "timeout" seconds, or the players can 
% terminate the game once they both collected their "must-haves", or you 
% can exit by pressing ESC.
%
%
% Mandatory inputs:
% pairNo    - Numeric value, pair number, one of 1:999
% player    - Numeric value, either 1 or 2. Defines player role (starting,
%           etc.)
% labName   - Char array, one of {"Mordor", "Gondor"}. Lab name for
%           participant, used for saving out data and setting network 
%           related variables
% roundNo   - Serial no. of the round for the pair. One of
%           1:99.
%
% Optional inputs:
% tokenNo       - Number of tokens in the game, one of 3:8. Defaults to 8.
% confType      - Numeric value, one of 1:5. Defines the tpye of initial
%               config to use, with larger numbers meaning "harder" 
%		bargaining conditions. Defaults to 1.
% confNo        - Numeric value, one of 1:20. Defines the config number to
%               use from given config type, one of 1:50. Defaults to 1.
% strangeImgNo  - Number of hard-to-label images used for tokens, one of
%               0:tokenNo. Defaults to 0.
%
% 
% Outputs:
%
%
%
%


% Octave packages used
pkg load image
pkg load sockets



%% Input checks

if nargin < 8 || isempty(strangeImgNo)
    strangeImgNo = 0;
end
if nargin < 7 || isempty(confNo)
    confNo = 1;
end
if nargin < 6 || isempty(confType)
    confType = 1;
end
if nargin < 5 || isempty(tokenNo)
    tokenNo = 8;
end
if nargin < 4
    error('Input args "pairNo", "player", "labName" and "roundNo" are required!');
end
if ~ismember(labName, {'Mordor', 'Gondor'})
    error('Input arg "labName" should be one of {"Mordor", "Gondor"}!');
end
if ~ismember(player, [1 2])
    error('Input arg "player" should be 1 or 2!');
end
if ~ismember(pairNo, 1:99)
    error('Input arg "pairNo" should be one of 1:999!');
end
if ~ismember(roundNo, 1:99)
    error('Input arg "roundNo" should be one of 1:999!');
end
if ~ismember(confType, 1:5)
    error('Input arg "confType" should be one of 1:5!');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%    Magic numbers / hardcoded params    %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Network address of remote PC for handshake and udp communication
if strcmp(labName, 'Mordor')
    remoteIP = '192.168.1.20';
elseif strcmp(labName, 'Gondor')
    remoteIP = '192.168.1.10';
end

% base folders
resDir = ["/home/mordor/CommGame/pair", num2str(pairNo), "/"];
baseDir = "/home/mordor/CommGame/bargaining_game/";  % repo
imgDir = "sorted_BOSS_NOUN_rs_100x100/";  % folder in repo containing token images


%% Video stream settings

% port receiveing RTP over UDP (video stream from gstreamer on other PC)
videoPort = 19009;

% gstreamer spec for reading in RTP stream
gstSpec = ['udpsrc port=', num2str(videoPort),' caps="application/x-rtp,media=',...
'(string)video,clock-rate=(int)90000,encoding-name=(string)RAW,sampling=',...
'(string)YCbCr-4:2:0,depth=(string)8,width=(string)1280,height=(string)720,',...
'colorimetry=(string)SMPTE240M,payload=(int)96,a-framerate=(string)30" ',...
'! queue ! rtpvrawdepay ! videoconvert'];

% filename for saving timestamps and other relevant vars
videoSaveFile = [resDir, "pair", num2str(pairNo), "_", labName, "_BG", num2str(roundNo), "_times.mat"];

% video recording
moviename = [resDir, "pair", num2str(pairNo), "_", labName, "_BG", num2str(roundNo), ".mov"];
vidLength = 1800;  % maximum length for video in secs
codec = ':CodecType=DEFAULTencoder';  % default codec
codec = [moviename, codec];

% video settings
waitForImage = 0;  % setting for Screen('GetCapturedImage'), 0 = polling (non-blocking); 1 = blocking wait for next image
vidSamplingRate = 30;  % expected video sampling rate, real sampling rate will differ
vidDropFrames = 1;  % dropframes flag for StartVideoCapture, 0 = do not drop frames; 1 = drop frame if necessary, only return the last captured frame
vidRecFlags = 16;  % recordingflags arg for OpenVideoCapture, 16 = use parallel thread in background; consider adding 1, 32, 128, 2048, 4096
vidRes = [0 0 1280 720];  % frame resolution
screenRes = [1920, 1080];
% draw video frames to center-top
frameDrawRect = [(screenRes(1)-vidRes(3))/2, 0, (screenRes(1)-vidRes(3))/2+vidRes(3), vidRes(4)];  

% preallocate frame info holding vars, adjust for potentially higher-than-expected sampling rate
frameCaptTime = nan((vidLength+60)*vidSamplingRate, 1);
flipTimeStamps = nan((vidLength+60)*vidSamplingRate, 3);  % three columns for the three flip timestamps returned by Screen
droppedFrames = frameCaptTime;


%% UPD comm parameters, socket binding

localPort = 10998;
remotePort = 10998;
remoteAddr = struct('addr', remoteIP, 'port', remotePort);
% open and bind socket used for the game
udpSocket = socket(AF_INET, SOCK_DGRAM);
bind(udpSocket, localPort);
connect(udpSocket, remoteAddr);


%% Load config 

% get an easy config from the .mat file in the repo
if confType == 1
    confF = [baseDir, "easyConfigs.mat"];
    confField = "easyConfigs";
elseif confType == 2
    confF = [baseDir, "harderConfigs.mat"];
    confField = "harderConfigs";    
end
tmp = load(confF);
conf = tmp.(confField)(confNo);

% extract prices, token distribution and must-haves
tokenPrices = conf.prices(1:tokenNo, player);
tokenAmounts = conf.tokens(1:tokenNo, player);
mustHaves = conf.mustHaves(1:tokenNo, player);


%% Basic parameters for the game

% max number of types of tokens on counter
counterTypesMax = 3;
% indices and numbers of ordinary / strange tokens
rand("state", tokenNo);
normImgNo = tokenNo-strangeImgNo;
normIdx = randperm(20, normImgNo);
% strangeIdx = [];
strangeIdx = randperm(7, strangeImgNo);
normNo = numel(normIdx);
strangeNo = numel(strangeIdx);


%% Load and select images

% get a list of potential images
tmp = dir([baseDir, imgDir, "*.png"]);

% get cell arrays for "normal" and "strange" token images:
% "strange" images have names starting with "20"
normFiles = cell(0, 1);
strangeFiles = cell(0, 1);
nc = 0; sc = 0;  % counters
for i = 1:length(tmp)
    if strcmp(tmp(i).name(1:2), "20")
        sc = sc+1;
        strangeFiles{sc, 1} = tmp(i).name;
    else
        nc = nc+1;
        normFiles{nc, 1} = tmp(i).name;
    end  % if
end  % for

% select "normNo" and "strangeNo" images according to earlier provided indices
if length(normFiles) < normNo
    error([char(10), "Not enough normal token images in ", imgDir, "!"]);
end
if length(strangeFiles) < strangeNo
    error([char(10), "Not enough strange (tangram-like) token images in ", imgDir, "!"]);
end
imgFiles = vertcat(normFiles(normIdx), strangeFiles(strangeIdx));

% total number of images used
imgNo = length(imgFiles);

% load images into cell array, display their sizes
imgs = cell(imgNo, 1);
for i = 1:imgNo
    imgs{i} = imread([baseDir, imgDir, imgFiles{i}]);
end
disp([char(10), 'Loaded ', num2str(imgNo), ' images, with sizes:']);
for i = 1:imgNo
    disp(size(imgs{i}));
end


%% Trigger preparations

% init parallel port control
ppdev_mex('Open', 1);
trigL = 2000;  % microseconds
trigSignal = 100;


%% Screen locations for images and prices / amounts

imgLoc = [0.1, 0.08;...  % defines img center coordinates (x, y) in scale 0-1, where (0, 0) is the top left corner
          0.1, 0.23;...  
          0.1, 0.38;...
          0.1, 0.53;...
          0.9, 0.08;...
          0.9, 0.23;...
          0.9, 0.38;...
          0.9, 0.53];
imgTargetSize = [100, 100];  % size for images - images should be already resized into this size

% locations and rect size for token prices on the shelves
% priceLoc = [0.23, 0.20;...
%             0.43, 0.20;...
%             0.63, 0.20;...
%             0.83, 0.20;...
%             0.23, 0.40;...
%             0.43, 0.40;...
%             0.63, 0.40;...
%             0.83, 0.40];
priceLoc = [imgLoc(:, 1)+0.03, imgLoc(:, 2)+0.07];
priceRectSize = [60, 60];

% locations and rect size for token numbers on the shelves
% shelvesNoLoc = [0.17, 0.20;...
%             0.37, 0.20;...
%             0.57, 0.20;...
%             0.77, 0.20;...
%             0.17, 0.40;...
%             0.37, 0.40;...
%             0.57, 0.40;...
%             0.77, 0.40];
shelvesNoLoc = [imgLoc(:, 1)-0.03, imgLoc(:, 2)+0.07];
shelvesNoRectSize = [60, 60];

% about counters - depends on "counterTypesMax"
counterLoc = [0.05, 0.85;...  % positions similarly to "imgLoc"
          0.15, 0.85;...
          0.25, 0.85;...
          0.35, 0.85];
% sanity check - compatibilty with "counterTypesMax"
if counterTypesMax > size(counterLoc, 1)
    error(['There are not enough locations specified in "counterLoc" for the ',...
    'allowed number of token types on the counter!']);
end
counterRectSize = [120, 140];

% locations and rect size for token numbers on the counter
% (below token images on counter)
counterNoLoc = counterLoc;
counterNoLoc(:, 2) = counterNoLoc(:, 2)+0.1;
counterNoRectSize = [60, 60];

% locations on the counter for the other player
counterLocOther = [0.95, 0.85;...
          0.85, 0.85;...
          0.75, 0.85;...
          0.65, 0.85];
% locations and rect size for token numbers on the counter, for the other player
counterNoLocOther = counterLocOther;
counterNoLocOther(:, 2) = counterNoLocOther(:, 2)+0.10;


%% Screen locations for buttons and summed value displays

bargainLoc = [0.5, 0.82];
bargainRectSize = [120, 120];
totalWealthLoc = [0.5, 0.73];
totalWealthRectSize = [100, 60];
playerOfferLoc = [0.40, 0.85];
playerOfferRectSize = [60, 60];
otherOfferLoc = [0.60, 0.85];
otherOfferRectSize = [60, 60];
mustHavesEndingLoc = [0.5, 0.92];
mustHavesEndingRectSize = [100, 80];

% screen locations for line between shelves and counter
lineLoc = [0, 0.68, 1, 0.68];
lineWidth = 2;
lineColor = [0 0 0];


%% Psychtoolbox params

backgrColor = [255 255 255 0];  % white transparent background
instrTime = 10;  % max time for displaying instructions
timeout = 930;  % max wait time to quit
exitKey = 'Escape';
addButtonState = [1 0 0];  % mouse button vector for left click
subtractButtonState = [0 0 1];  % mouse button vector for right click
txtColor = [0, 0, 0];  % black letters
txtSize = 30;



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

%     % get frame interval
%     ifi = Screen('GetFlipInterval', onWin);
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

    
    %% Init video capture device
    
    % Try to set video capture to custom pipeline
    try
        Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', gstSpec));
    catch ME
        disp('Failed to set Screen(''SetVideoCaptureParameter''), errored out.');
        sca; 
        rethrow(ME);
    end
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', onWin, -9, vidRes, [], [], [], codec, vidRecFlags);
    % Wait a bit for OpenVideoCapture to return
    WaitSecs('YieldSecs', 1);
    
    

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
        priceRect(:, i) = CenterRectOnPoint(baseRect, priceLoc(i, 1)*xPix, priceLoc(i, 2)*yPix);
    end    

    % get rectangles for token amounts on the shelves (number of available tokens, 
    % text boxes below and to the left of token images)
    shelvesNoRect = nan(4, imgNo);
    baseRect = [0, 0, shelvesNoRectSize(1), shelvesNoRectSize(2)];
    for i = 1:imgNo
        shelvesNoRect(:, i) = CenterRectOnPoint(baseRect, shelvesNoLoc(i, 1)*xPix, shelvesNoLoc(i, 2)*yPix);
    end    

    % get rectangles for token images on the counter for current player
    counterRect = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterRectSize(1), counterRectSize(2)];
    for i = 1:counterTypesMax
        counterRect(:, i) = CenterRectOnPoint(baseRect, counterLoc(i, 1)*xPix, counterLoc(i, 2)*yPix);
    end

    % get rectangles for token numbers on the counter for current player
    % (text boxes below the token images)
    counterNoRect = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterNoRectSize(1), counterNoRectSize(2)];
    for i = 1:counterTypesMax
        counterNoRect(:, i) = CenterRectOnPoint(baseRect, counterNoLoc(i, 1)*xPix, counterNoLoc(i, 2)*yPix);
    end

    % get rectangles for token images on the counter for OTHER player
    counterRectOther = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterRectSize(1), counterRectSize(2)];
    for i = 1:counterTypesMax
        counterRectOther(:, i) = CenterRectOnPoint(baseRect, counterLocOther(i, 1)*xPix, counterLocOther(i, 2)*yPix);
    end

    % get rectangles for token numbers on the counter for OTHER player
    counterNoRectOther = nan(4, counterTypesMax);  % number of tokens on counter is capped
    baseRect = [0, 0, counterNoRectSize(1), counterNoRectSize(2)];
    for i = 1:counterTypesMax
        counterNoRectOther(:, i) = CenterRectOnPoint(baseRect, counterNoLocOther(i, 1)*xPix, counterNoLocOther(i, 2)*yPix);
    end

    % get rectangle for the bargain button
    baseRect = [0, 0, bargainRectSize(1), bargainRectSize(2)];
    bargainRect = CenterRectOnPoint(baseRect, bargainLoc(1)*xPix, bargainLoc(2)*yPix);

    % get rectangle for the value of player's offer
    baseRect = [0, 0, playerOfferRectSize(1), playerOfferRectSize(2)];
    playerOfferRect = CenterRectOnPoint(baseRect, playerOfferLoc(1)*xPix, playerOfferLoc(2)*yPix);

    % get rectangle for the value of other's offer
    baseRect = [0, 0, otherOfferRectSize(1), otherOfferRectSize(2)];
    otherOfferRect = CenterRectOnPoint(baseRect, otherOfferLoc(1)*xPix, otherOfferLoc(2)*yPix);
    
    % get rectangle for the total value on player's shelves
    baseRect = [0, 0, totalWealthRectSize(1), totalWealthRectSize(2)];
    totalWealthRect = CenterRectOnPoint(baseRect, totalWealthLoc(1)*xPix, totalWealthLoc(2)*yPix);
    
    % get rectangle for must-haves ending button
    baseRect = [0, 0, mustHavesEndingRectSize(1), mustHavesEndingRectSize(2)];
    mustHavesEndingRect = CenterRectOnPoint(baseRect, mustHavesEndingLoc(1)*xPix, mustHavesEndingLoc(2)*yPix);    
    
    % Prepare rectangles for must haves:
    % These rects are based on (1) the rects of tokens on "shelves" 
    % and (2) the rects of prices 
    mustHavesExtraWidth = 0;  % extra width / size of rectangle for must haves added to size of image and price rects, in screen ratio
    mustHavesRect = nan(4, imgNo);
    for i = 1:imgNo
        if ~isnan(mustHaves(i))
            mustHavesRect(1:2, i) = [shelvesRect(1, i)-mustHavesExtraWidth*xPix, shelvesRect(2, i)-mustHavesExtraWidth*yPix];
            mustHavesRect(3:4, i) = [shelvesRect(3, i)+mustHavesExtraWidth*xPix, shelvesRect(4, i)+mustHavesExtraWidth*yPix];
        end
    end
    
    % prepare rectangles for must have numbers
    mustHaveAmountRect = shelvesRect;
    mustHaveAmountRect(1, :) = mustHaveAmountRect(3, :);
    mustHaveAmountRect(3, :) = mustHaveAmountRect(3, :) + 60;
%    mustHaveAmountRect(1, :) = mustHaveAmountRect(1, :) + 0.05*xPix;
%    mustHaveAmountRect(3, :) = mustHaveAmountRect(3, :) + 0.05*xPix;
    mustHaveAmountRect(:, isnan(mustHaves)) = nan;
    
    
    %% Prepare a basic "shelves" texture with token images and prices, using an
    % offscreen window

    shelvesWin = Screen("OpenOffscreenWindow", onWin, backgrColor);  % white transparent background, so we can overlay it on other textures
    % set text size
    Screen("TextSize", shelvesWin, txtSize);

    % put token images into offscreen window
    Screen("DrawTextures", shelvesWin, imgTextures, [], shelvesRect);
    
    % add a frame for the counter
    counterFrameColor = [64, 64, 64];
    counterFrameRect = [0.05, 0.60, 0.95, 0.95];
    counterFrameWidth = 3;
    Screen("FrameRect", shelvesWin, counterFrameColor, counterFrameRect, counterFrameWidth);

    % draw prices on it as well
    for i = 1:imgNo
        DrawFormattedText(shelvesWin, [num2str(tokenPrices(i)), " ft"],...
            "center", "center", txtColor, [], [], [], [], [],...
            priceRect(:, i)');
    end    
    
    % add frames for must haves as well
    mustHaveColor = [255 0 0];
    mustHaveRectWidth = 4;
    Screen("FrameRect", shelvesWin, mustHaveColor, mustHavesRect, mustHaveRectWidth);
    
    % draw must have prices
    for i = 1:imgNo
        if ~isnan(mustHaves(i))
            DrawFormattedText(shelvesWin, [num2str(mustHaves(i)), "x"],...
                "center", "center", mustHaveColor, [], [], [], [], [],...
                mustHaveAmountRect(:, i)');
        end
    end    
    
    % add the bargain button
    bargainFrameColor = [0 0 0];
    bargainFillColor = [32, 32, 255, 32];
    bargainFlagColor = [255, 32, 32, 64];
    bargainFrameWidth = 3;
    Screen("FillOval", shelvesWin, bargainFillColor, bargainRect);
    Screen("FrameOval", shelvesWin, bargainFrameColor, bargainRect, bargainFrameWidth);
    DrawFormattedText(shelvesWin, "CSERE!", "center", "center", txtColor, [], [],...
            [], [], [], bargainRect);

    % add the must-haves ending button
    mustHavesEndingFrameColor = [0 0 0];
    mustHavesEndingFillColor = [160, 160, 160, 32];  % lighter grey, mostly transparent
    mustHavesEndingFlagColor = [32, 192, 32, 64];  % mostly green
    mustHavesEndingFrameWidth = 3;
    Screen("FillOval", shelvesWin, mustHavesEndingFillColor, mustHavesEndingRect);
    Screen("FrameOval", shelvesWin, mustHavesEndingFrameColor, mustHavesEndingRect, mustHavesEndingFrameWidth);
    DrawFormattedText(shelvesWin, "VÉGE!", "center", "center", txtColor, [], [],...
            [], [], [], mustHavesEndingRect);    
        
    % add a line between shelves and counter
    lineLoc = lineLoc .* [xPix, yPix, xPix, yPix];
    Screen("DrawLine", shelvesWin, lineColor,... 
        lineLoc(1), lineLoc(2), lineLoc(3), lineLoc(4), lineWidth);

        
    %% Prepare each token image as a separate texture 
    % for fast loading and placing on the counter. 
    % Brute force version: generate a texture for each image in each counter location.
    
    counterImgTex = zeros(imgNo, counterTypesMax);
    for i = 1:imgNo  % loop through images / tokens
        tmpTex = Screen("MakeTexture", onWin, imgs{i});
        for z = 1:counterTypesMax  % loop through potential counter locations
            counterImgTex(i, z) = Screen('OpenOffScreenWindow', onWin, backgrColor);
            Screen("DrawTexture", counterImgTex(i, z), tmpTex, [], counterRect(:, z)');
        end
    end

    % Same as above but for the OTHER player
    counterImgTexOther = zeros(imgNo, counterTypesMax);
    for i = 1:imgNo  % loop through images / tokens
        tmpTex = Screen("MakeTexture", onWin, imgs{i});
        for z = 1:counterTypesMax  % loop through potential counter locations
            counterImgTexOther(i, z) = Screen("OpenOffScreenWindow", onWin, backgrColor);
            Screen("DrawTexture", counterImgTexOther(i, z), tmpTex, [], counterRectOther(:, z)');
        end
    end

    
    % set mouse init position
    SetMouse(xC, yC, onWin);

    % draw and display instructions, wait a bit
    instrText = ["Egy 'Alku játék' következik." char(10), char(10),... 
                "Az a feladatod, hogy előnyös üzleteket köss a másik játékossal.", char(10),...
                "Rád bízzuk, hogy ezt hogyan teszed.", char(10), char(10),...
                "Hamarosan kezdünk."];
    DrawFormattedText(onWin, instrText, 'center', 'center', txtColor);
    Screen("Flip", onWin);
    WaitSecs(instrTime);


    %% Get shared starting time across machines
    
    sharedStartTime = UDPhandshake(remoteIP);
    
    
    %% Start video capture
    
    % Start capture 
    [reportedSamplingRate, vidCaptureStartTime] = Screen('StartVideoCapture', grabber, vidSamplingRate, vidDropFrames, sharedStartTime);
    lptwrite(1, trigSignal, trigL);
    % Check the reported sampling rate, compare to requested rate
    if reportedSamplingRate ~= vidSamplingRate
        warning(['Reported sampling rate from Screen(''StartVideoCapture'') is ', ...
        num2str(reportedSamplingRate), ' fps, not matching the requested rate of ', ...
        num2str(vidSamplingRate), ' fps!']);
    end
    
    % display tokens & prices using the basic "shelves" texture
    Screen("DrawTexture", onWin, shelvesWin);

    % draw the token numbers as well - these will be updated all the time
    for i = 1:imgNo
        DrawFormattedText(onWin, [num2str(tokenAmounts(i)), "x"],...
            "center", "center", txtColor, [], [], [], [], [],...
            shelvesNoRect(:, i)');
    end

    % flip window, get timestamp
    firstFlip = Screen("Flip", onWin);    
    lptwrite(1, trigSignal, trigL);
    
    % helper variables for the display loop
    oldtex = 0;
    vidFrameCount = 1;
    flipCounter = 1;
    
    
    
    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%    Main loop   %%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % preallocate flags, vars
    counterState = zeros(imgNo, 1);
    counterStarted = zeros(imgNo, 1);  
    shelvesState = tokenAmounts;
    changeFlag = false;  % flag for changing the content of the display
    shelves2counter = zeros(imgNo, 1);  % mapping between tokens on shelves and counter positions
    counter2shelves = zeros(counterTypesMax, 1);  % mapping from counter positions to shelves
    otherChange = false;  % flag for checking if there was a change on the counter by the other player
    other_c2s = counter2shelves;
    other_cState = counterState;
    previousIncoming = zeros(counterTypesMax+imgNo, 1);
    bargainFlag = false;  % flag for a player clicking on the bargain button
    bargainUpdate = false;  % flag for completing a bargain
    totalWealthValue = dot(shelvesState, tokenPrices);  % starting total wealth
    mustHavesBool = ~isnan(mustHaves);
    mustHavesFlag = false;  % flag for player fullfilling the must-have requirements
    mustHavesEndingFlag = false;  % flag for player clicking on the must-haves ending button
    mustHavesAllCollected = false;  % flag for both players finishing with must-haves
    

    % wait for key press or maximum allowed time
    while GetSecs < firstFlip + timeout  && ~mustHavesAllCollected

        % check for exit key
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown && find(keyCode) == KbName(exitKey)
            break;
        end

        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%    Check for video frame    %%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        
        % Check for next available image, return it as texture if there was one
        %
        % "text" will also behave as the flag for new video frame, tex > 0
        % only if there was a new texture
        [tex, frameCaptTime(vidFrameCount), droppedFrames(vidFrameCount)] = Screen("GetCapturedImage", onWin, grabber, waitForImage, oldtex);              
        if tex > 0
            oldtex = tex;
        end
        
        
        % try reading from the udp comms socket
        [incomingMessage, udpBytesCount] = recv(udpSocket, 512, MSG_DONTWAIT);  % non-blocking, udpBytesCount is -1 if there was no data
        if udpBytesCount ~= -1
            tmpCellArray = strsplit(char(incomingMessage), " ");  % from bytes to char, from char to cell array of char
            % decide first if we received a "bargainState" message 
            if numel(tmpCellArray) == 1 && strcmp(tmpCellArray{1}, "bargainState")
                % if we are already in bargain state, send out the message again and set flag for updating all states
                if bargainFlag
                    udpMessage = "bargainState";
                    send(udpSocket, udpMessage);
                    bargainUpdate = true;
                end
            % decide next if we received an "endingState" message 
            elseif numel(tmpCellArray) == 1 && strcmp(tmpCellArray{1}, "endingState")
                % if we are already in must-haves ending state, send out
                % the message again and set flag for exiting due to success
                if mustHavesEndingFlag
                    udpMessage = "endingState";
                    send(udpSocket, udpMessage);
                    mustHavesAllCollected = true;
                end                
            % else try to treat it as counter state vectors
            else
                incomingVector = cellfun(@str2double, tmpCellArray);  % numeric vector
                % only go on if the message is different than the last one
                if ~isequal(incomingVector, previousIncoming)
                    other_c2s = incomingVector(1:counterTypesMax)';  % counter2shelves vector for OTHER player
                    other_cState = incomingVector(counterTypesMax+1:end)';  % counterState vector for OTHER player
                    previousIncoming = incomingVector;
                    if any(other_c2s ~= 0)
                        tmpIdx = other_c2s;
                        tmpIdx(tmpIdx==0)=[];
                    end         
                    otherChange = true;
                end
            end  % if numel(tmpCellArray)
        end  % if udpBytesCount ~= -1
        

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%    No bargain update path    %%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Check mouse, decide if player placed / took away stg on / from counter,
        % handle basic udp comms

        if ~bargainUpdate

            % track mouse, give location relative to onscreen window
            [xM, yM, buttons] = GetMouse(onWin);


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%    Click detection part - decide what to do     %%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % if there is a button click, check if mouse cursor is in one of the 
            % image rects
            if any(buttons)
                mouseInRect = xM > shelvesRect(1, :) & xM < shelvesRect(3, :) & yM > shelvesRect(2, :) & yM < shelvesRect(4, :);  % returns logical row vector
                mouseInBargain = xM > bargainRect(1) && xM < bargainRect(3) && yM > bargainRect(2) && yM < bargainRect(4);  % returns logical for mouse in bargain button
                mouseInMustHavesEnding = xM > mustHavesEndingRect(1) && xM < mustHavesEndingRect(3) && yM > mustHavesEndingRect(2) && yM < mustHavesEndingRect(4);  % returns logical for mouse in must-haves ending button

                % if cursor is in one of the image rects, check if that token is on the counter
                % only do checks if we are not in bargain state ("bargainFlag")
                if any(mouseInRect)  && ~bargainFlag

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
                                counterState(mouseInRect) = counterState(mouseInRect) + 1;
                                shelvesState(mouseInRect) =  shelvesState(mouseInRect) - 1;
                                changeFlag = true;
                            end  % if any(counter2shelves==0)

                        end  % if isequal(buttons...

                    end  % if shelves2coutner(mouseInRect)

                end  % if any(mouseInRect)

                % if the cursor was on the bargain button, check the type of click and the state of the bargain flag
                if mouseInBargain
                    % if there was no bargain state, but player clicked on the button, start bargain state
                    if ~bargainFlag && isequal(buttons, addButtonState)
                        bargainFlag = true;
                    % if there was bargain state and player clicked on button, exist bargain state
                    elseif bargainFlag && isequal(buttons, addButtonState)
                        bargainFlag = false;
                    end
                end  % if mouseInBargain

                % if the cursor was on the must-haves ending button, check
                % if the player fullfilled the requirements, and if the
                % correct click type was used
                if mouseInMustHavesEnding && mustHavesFlag && isequal(buttons, addButtonState)
                    % set flag for ending the game due to must-haves
                    mustHavesEndingFlag = true;
                end  % if mouseInBargain                
                
                % wait till button is released (click ended)
                while any(buttons)
                    WaitSecs(0.01);  % 10 msecs
                    [~, ~, buttons] = GetMouse(onWin);
                end  % while

            end  % if any(buttons)


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%    Communication part - sending UDP packages    %%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % if there was any change, send the following information as a package:
            % (1) counter2shelves - the mapping from counter positions to shelves tokens
            % (2) counterState - the token amounts played on the counter, for all token types on the shelves
            if changeFlag
                udpMessage = num2str([counter2shelves; counterState]');  % string representation of concatenated vectors
                % send packet, do it twice for safety
                for i = 1:2
                    send(udpSocket, udpMessage);
                end  % for
            end  % if

            % if we are in bargain state, send that information to the other side
            if bargainFlag
                udpMessage = "bargainState";
                % only send it once, will repeatedly do so in the whil loop
                send(udpSocket, udpMessage);
            end  % if

            % if we are already in ending state due to collected must-haves and 
            % pressing the must-haves ending button, send corresponding message
            if mustHavesEndingFlag
                udpMessage = "endingState";
                % only send it once, will repeatedly do so in the while loop
                send(udpSocket, udpMessage);
            end  % if
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%    Draw token numbers and counter images if needed %%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % if the screen needs to be updated
            if changeFlag  || otherChange || tex > 0

                % draw images & prices for shelves
                Screen("DrawTextures", onWin, shelvesWin);            
            
                % draw updated token amounts on shelves
                for i = 1:imgNo
                    DrawFormattedText(onWin, [num2str(shelvesState(i)), "x"],... 
                            "center", "center", txtColor, [], [], [], [], [],... 
                            shelvesNoRect(:, i)');
                end  % for

                % highlight the bargain button if it was clicked on
                if bargainFlag
                    Screen("FillOval", onWin, bargainFlagColor, bargainRect);
                    Screen("FrameOval", onWin, bargainFlagColor, bargainRect, bargainFrameWidth);
                    DrawFormattedText(onWin, "CSERE!", "center", "center", txtColor, [], [],...
                        [], [], [], bargainRect);                    
                end
                
                % highlight the must-haves ending button if requirements
                % are met
                if mustHavesEndingFlag
                    Screen("FillOval", onWin, mustHavesEndingFlagColor, mustHavesEndingRect);
                    Screen("FrameOval", onWin, mustHavesEndingFrameColor, mustHavesEndingRect, mustHavesEndingFrameWidth);
                    DrawFormattedText(onWin, "VÉGE!", "center", "center", txtColor, [], [],...
                            [], [], [], mustHavesEndingRect);                    
                end                
                
                % draw updated counter numbers + corresponding image
                for i = 1:counterTypesMax
                    if counter2shelves(i) > 0
                        Screen("DrawTexture", onWin, counterImgTex(counter2shelves(i), i));
                        DrawFormattedText(onWin, [num2str(counterState(counter2shelves(i))), "x"],... 
                                "center", "center", txtColor, [], [], [], [], [],... 
                                counterNoRect(:, i)');                        
                    end  % if
                end  % for

                % draw the value of the counter
                playerOfferValue = dot(counterState, tokenPrices);
                if playerOfferValue > 0
                    DrawFormattedText(onWin, [num2str(playerOfferValue), " ft"],...
                        "center", "center", txtColor, [], [], [], [], [], ...
                        playerOfferRect);
                end
                
                % draw updated counter numbers + corresponding image for OTHER player
                for i = 1:counterTypesMax
                    if other_c2s(i) > 0
                        Screen("DrawTexture", onWin, counterImgTexOther(other_c2s(i), i));
                        DrawFormattedText(onWin, [num2str(other_cState(other_c2s(i))), "x"],... 
                                "center", "center", txtColor, [], [], [], [], [],... 
                                counterNoRectOther(:, i)');                        
                    end  % if
                end  % for

                % draw the value of the counter for OTHER player
                otherOfferValue = dot(other_cState, tokenPrices);
                if otherOfferValue > 0
                    DrawFormattedText(onWin, [num2str(otherOfferValue), " ft"],...
                        "center", "center", txtColor, [], [], [], [], [], ...
                        otherOfferRect);
                end                

                % draw the total wealth value
                DrawFormattedText(onWin, ["Összesen: ", num2str(totalWealthValue), " ft"],...
                    "center", "center", txtColor, [], [], [], [], [], ...
                    totalWealthRect);
                
                % draw new video frame if necessary
                if tex > 0
                    % Draw new texture from framegrabber.
                    Screen("DrawTexture", onWin, tex, [], frameDrawRect);
                    % adjust video frame counter
                    vidFrameCount = vidFrameCount + 1;   
                else
                    % Draw old texture again.
                    Screen("DrawTexture", onWin, oldtex, [], frameDrawRect);                     
                end  % if tex                
               
                % flip
                [flipTimeStamps(flipCounter, 1), flipTimeStamps(flipCounter, 2), flipTimeStamps(flipCounter, 3)] = Screen("Flip", onWin);
                flipCounter = flipCounter + 1;
                
                % set change flags back to default
                changeFlag = false;
                otherChange = false;

            end  % if changeFlag ||

        end  % if ~bargainUpdate



        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%    Bargain update path    %%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Update all state vectors and flags, reset update and change flags,
        % Display new token numbers

        if bargainUpdate
            % add tokens in other player's offer to own ones
            if any(other_c2s ~= 0)
                tmpIdx = other_c2s;
                tmpIdx(tmpIdx==0)=[];
                shelvesState(tmpIdx) = shelvesState(tmpIdx) + other_cState(tmpIdx);
            end  
            % reset both players' counter states
            counterState = zeros(imgNo, 1);
            counterStarted = zeros(imgNo, 1);  
            changeFlag = false;  % flag for changing the content of the display
            shelves2counter = zeros(imgNo, 1);  % mapping between tokens on shelves and counter positions
            counter2shelves = zeros(counterTypesMax, 1);  % mapping from counter positions to shelves
            otherChange = false;  % flag for checking if there was a change on the counter by the other player
            other_c2s = counter2shelves;
            other_cState = counterState;
            previousIncoming = zeros(counterTypesMax+imgNo, 1);
            bargainFlag = false;  % flag for a player clicking on the bargain button
            bargainUpdate = false;  % flag for completing a bargain
            totalWealthValue = dot(shelvesState, tokenPrices);
            
            %  Check if must haves have been collected    
            if ~mustHavesFlag
                if all(shelvesState(mustHavesBool) >= mustHaves(mustHavesBool))
                    mustHavesFlag = true;
                end
            end
            
            % draw images & prices for shelves
            Screen("DrawTextures", onWin, shelvesWin);        
        
            % update shelves and counter
            % draw updated token amounts on shelves
            for i = 1:imgNo
                DrawFormattedText(onWin, [num2str(shelvesState(i)), "x"],... 
                        "center", "center", txtColor, [], [], [], [], [],... 
                        shelvesNoRect(:, i)');
            end  % for

            % draw updated counter numbers + corresponding image
            for i = 1:counterTypesMax
                if counter2shelves(i) > 0
                    Screen("DrawTexture", onWin, countokenAmountsterImgTex(counter2shelves(i), i));
                    DrawFormattedText(onWin, [num2str(counterState(counter2shelves(i))), "x"],... 
                            "center", "center", txtColor, [], [], [], [], [],... 
                            counterNoRect(:, i)');                    
                end  % if
            end  % for

            % draw updated counter numbers + corresponding image for OTHER player
            for i = 1:counterTypesMax
                if other_c2s(i) > 0
                    Screen("DrawTexture", onWin, counterImgTexOther(other_c2s(i), i));
                    DrawFormattedText(onWin, [num2str(other_cState(other_c2s(i))), "x"],... 
                            "center", "center", txtColor, [], [], [], [], [],... 
                            counterNoRectOther(:, i)');
                end  % if
            end  % for

            % draw the total wealth value
            DrawFormattedText(onWin, ["Összesen: ", num2str(totalWealthValue), " ft"],...
                "center", "center", txtColor, [], [], [], [], [], ...
                totalWealthRect);            
            
            % highlight the must-haves ending button if requirements
            % are met
            if mustHavesEndingFlag
                Screen("FillOval", onWin, mustHavesEndingFlagColor, mustHavesEndingRect);
                Screen("FrameOval", onWin, mustHavesEndingFrameColor, mustHavesEndingRect, mustHavesEndingFrameWidth);
                DrawFormattedText(onWin, "VÉGE!", "center", "center", txtColor, [], [],...
                        [], [], [], mustHavesEndingRect);                    
            end  
            
            % draw new video frame if necessary
            if tex > 0
                % Draw new texture from framegrabber.
                Screen("DrawTexture", onWin, tex, [], frameDrawRect);
                % adjust video frame counter
                vidFrameCount = vidFrameCount + 1;       
            else
                % Draw old texture again.
                Screen("DrawTexture", onWin, oldtex, [], frameDrawRect);                
            end  % if tex            
            
            % flip
            [flipTimeStamps(flipCounter, 1), flipTimeStamps(flipCounter, 2), flipTimeStamps(flipCounter, 3)] = Screen("Flip", onWin);
            flipCounter = flipCounter + 1;

            % wait a bit
            WaitSecs(1);

        end  % if ~bargainUpdate

    end  % while


    % shutdown video and screen
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    stopCaptureTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    closeCaptureTime = GetSecs; 
    Priority(0);
    ppdev_mex('Close', 1);
    sca;

    % save major timestamps
    save(videoSaveFile, "sharedStartTime", "vidCaptureStartTime",...
    "frameCaptTime", "vidFrameCount", "flipTimeStamps", "stopCaptureTime",...
    "closeCaptureTime");   
    
    % goodbye
    disp("Thanks for shopping with us!");
    sca;
    disconnect(udpSocket);

    
% call Screen('CloseAll') and rethrow error if stg went south
catch ME
    lptwrite(1, trigSignal, trigL);
    ppdev_mex('Close', 1);
    sca;  % closes video too
    disconnect(udpSocket);
    Priority(0);
    rethrow(ME)

end


return




