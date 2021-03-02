%% Function to generate token and price configs in the Bargaining Game
%
%
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
        
        
        
        
        
        
        
        
        