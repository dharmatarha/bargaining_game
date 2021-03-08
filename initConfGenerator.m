%% Function to generate token and price configs in the Bargaining Game
%
%
%
% TODO:
% - include the effect of "must haves" in the potential wealth flow (PWF)
% indices
%
%

%% Base values for generating potential configurations

% no. of tokens
tokenNo = 8;
% range for no. of each token across players
nPerToken = 5:12; 
% potential price values
priceRange = 5:5:40;
% potential price difference values
diffRange = -20:5:20;

% no. of must-have tokens per player
mustHaveNo = 3;

% no. of random configs to generate
confNo = 10^4;


%% Generate potential configs

confTokens = nan(confNo, tokenNo, 2);
confPrices = confTokens;

confIdx = 1;
while confIdx ~= confNo
    
    % tokens, prices preallocation
    tokens = nan(tokenNo, 2);
	prices = tokens;
    
    % get total number for each token
    tokenSums = nPerToken(randi(length(nPerToken), 1, tokenNo))';
    % get two "parts" for each, where "parts" add up to total
    for i = 1:tokenNo
        tokens(i, 1) = randi(tokenSums(i), 1);
    end
    tokens(:, 2) = tokenSums-tokens(:,1);

    % get price difference for each token randomly from range of possible prices
    priceDiffs = diffRange(randi(length(diffRange), 1, tokenNo))';
    % select two-two prices conforming to the price differences
    for i = 1:tokenNo
        % for each token, select a first price randomly, then select a
        % corresponding second price satisfying the difference - repeat until
        % suitable prices were found
        tokenFlag = false;
        while ~tokenFlag
            firstP = priceRange(randperm(length(priceRange), 1));
            if any(priceRange == firstP + priceDiffs(i))
                secondP = firstP + priceDiffs(i);
                prices(i, :) = [firstP, secondP];
                tokenFlag = true;
            end
        end
    end

    % total wealth of the two players
    w1 = dot(tokens(:, 1), prices(:, 1));
    w2 = dot(tokens(:, 2), prices(:, 2));

    % keep the tables if the wealth of the two players are essentially equal
    % (the difference is less then 5% of the average wealth)
    if abs(w1-w2) < (mean([w1, w2])/20)
        confTokens(confIdx, :, :) = tokens;
        confPrices(confIdx, :, :) = prices;
        confIdx = confIdx + 1;
    end
    
end
        
        
%% Get sum of price differences for each potential config

confDiffSums = sum(squeeze(confPrices(:, :, 1)-confPrices(:, :, 2)), 2);
        

%% Get list and number of must-have tokens for each potential config

confMustHaves = nan(confNo, tokenNo, 2);

for confIdx = 1:confNo
    
    % The idea is to select "mustHaveNo" tokens that the other player has more
    % of, and to choose the corresponding amounts close to the maximum amounts

    % for a given "tokens" and "prices" matrix
    tokens = squeeze(confTokens(confIdx, :, :));
    prices = squeeze(confPrices(confIdx, :, :));

    % preallocate a "must-haves" matrix - each number correspond for the number
    % of tokens with the corresponding row the player has to collect
    mustHaves = nan(tokenNo, 2);

    % get differences in token numbers
    tokenDiff = tokens(:, 1) - tokens(:, 2);

    % select tokens for which the difference is at least three in either
    % direction
    [sortedDiff, sortIds] = sort(tokenDiff);
    % the most negative values correspond to tokens where the second player has
    % more, select those as necessary ones for the first player
    tmpMustHaveIds = sortIds(1:mustHaveNo);
    tmpSumTokens = sum(tokens(tmpMustHaveIds, :), 2);
    tmpEdges = randi(3, 1, 3); tmpEdges = tmpEdges-1;  % differences from the maximum numbers
    mustHaves(tmpMustHaveIds, 1) = tmpSumTokens-tmpEdges';
    % the most positive values correspond to tokens where the first player has
    % more, select those as necessary ones for the second player
    tmpMustHaveIds = sortIds(end-mustHaveNo+1:end);
    tmpSumTokens = sum(tokens(tmpMustHaveIds, :), 2);
    tmpEdges = randi(3, 1, 3); tmpEdges = tmpEdges-1;  % differences from the maximum numbers
    mustHaves(tmpMustHaveIds, 2) = tmpSumTokens-tmpEdges';

    % collect results into matrix of all must-haves
    confMustHaves(confIdx, :, :) = mustHaves;
    
end
        

%% Get wealth sums for each configuration, as calculated separately for both
% pricings

% preallocate
confWealth = nan(confNo, 2, 2);

for confIdx = 1:confNo        
        
    % for a given "tokens" and "prices" matrix
    tokens = squeeze(confTokens(confIdx, :, :));
    prices = squeeze(confPrices(confIdx, :, :));        
    
    % total wealth per token set, per pricing
    confWealth(confIdx, :, :) = tokens'*prices;  % matrix multiplication, results in 2 x 2 matrix
    
end

% % mean wealth on main diagonal for each config
% meanW = (confWealth(:, 1, 1) + confWealth(:, 2, 2)) / 2;
% asymmetry index for each config  =  ratios of off-diagonals
confAsym = max(confWealth(:, 1, 2)./confWealth(:, 2, 1), confWealth(:, 2, 1)./confWealth(:, 1, 2));
% bargaining difficulty index  =  ratio of off-diagonals to main diagonals
confBargDiff = (confWealth(:, 1, 2)+confWealth(:, 2, 1)) ./ (confWealth(:, 1, 1)+confWealth(:, 2, 2));


        

%% Select "easy" and "difficult" ones:

% easy: assymetry not too big + price differences sum is close to zero +
% bargaining difficulty is largeish 
easyConfs = confAsym < 1.1 & abs(confDiffSums) <= 10 & confBargDiff > 1.2 & confBargDiff < 1.5;

% more difficult ones: assymetry not too big + price differences sum is close to zero + bargaining difficulty is smaller, close to zero     
harderConfs = confAsym < 1.1 & abs(confDiffSums) <= 10 & confBargDiff > 1.01 & confBargDiff < 1.1;        
    
% % list first ten
% disp([char(10), '"Easy" configs: ']);
% disp(find(easyConfs, 10));    
% disp([char(10), '"Harder" configs: ']); 
% disp(find(harderConfs, 10)); 
    
   
    
%% Calculate total potential wealth-flows in both directions

% Potential wealth flow (PWF) is all value that oculd be traded in one or the
% other direction (from player 1 to player 2 or the other way around) based
% on the price differences.
% PWF is calculated as all tokens with a positive / negative price
% difference, multiplied with the number of available tokens, summed across
% tokens.

% preallocate
PWF = nan(confNo, 2);

for confIdx = 1:confNo        
    
    % for a given "tokens" and "prices" matrix
    tokens = squeeze(confTokens(confIdx, :, :));
    prices = squeeze(confPrices(confIdx, :, :));        
    
    % mask for price differences in one direction
    maskOne = prices(:, 2) > prices(:, 1);
    % get PWF, use price differences for calculation
    PWF(confIdx, 1) = dot(tokens(maskOne, 1), (prices(maskOne, 2)-prices(maskOne, 1)));
    
    % mask for price differences in other direction
    maskTwo = prices(:, 1) > prices(:, 2); 
    % get PWF, use price differences for calculation
    PWF(confIdx, 2) = dot(tokens(maskTwo, 2), (prices(maskTwo, 1)-prices(maskTwo, 2)));    

    
end
    

% get differences in PWFs
PWFdiff = PWF(:, 1) - PWF(:, 2);

% get easy / hard ones based on PWF
PWFeasy = abs(confDiffSums) <= 10 & ...
    PWF(:, 1) > 300 & ...
    PWF(:, 2) > 300 & ...
    PWFdiff < 50;

% get hard ones based on PWF
PWFhard = abs(confDiffSums) <= 10 & ...
    PWF(:, 1) > 50 & PWF(:, 1) < 150 & ... 
    PWF(:, 2) > 50 & PWF(:, 2) < 150 & ...
    PWFdiff < 50;

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
        