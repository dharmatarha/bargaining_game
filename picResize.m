function resizedImgs = picResize(mainDir, imgTargetSize)
%% function for resizing high res JPG images for stimulus display 
%
% USAGE
%
% inputs (mandatory):    - mainDir = str, folder containing the images we want to convert 
%                        - imgTargetSize = 2-element vector with desired pixel size 
% 
% output:                - cell array of resized imgs
% 

%mainDir = '/home/lucab/alku_képek/sorted_BOSS_NOUN/';
%imgTargetSize = [180, 180];

% check input
if ~isdir(mainDir)
  errorMessage = sprintf('Error: The following folder does not exist:\n%s', mainDir);
  uiwait(warndlg(errorMessage));
  return;
end

% get path to imgs
filePattern = fullfile(mainDir, '*.jpg');
imgFiles = dir(filePattern);
imgNo = length(imgFiles);

% reading imgs
imageArray = cell(imgNo,1);
for k = 1:imgNo
  baseFileName = imgFiles(k).name;
  fullFileName = fullfile(mainDir, baseFileName);
  %fprintf(1, 'Now reading %s\n', fullFileName);
  imageArray{k} = imread(fullFileName);
  disp(['Now reading ', fullFileName, ',', newline, ' size: ' num2str(size(imageArray{k,:}))]);
end

disp([newline 'Loaded ', num2str(imgNo), ' images']);
disp([newline, 'Now resizing...']);

% resizing
resizedImgs = cell(imgNo,1);
for k = 1:imgNo
    resizedImgs{k} = imresize(imageArray{k}, imgTargetSize);
end

% show preview of first image 
%imshow(resizedImgs{1,1});

% save files
for k = 1:imgNo  
   newFilename = [imgFiles(k).name(1:end-4), '_RE_', num2str(k), '.png']; % imwrite does not support jpg!
   imwrite(resizedImgs{k}, newFilename); 
end

disp([newline, 'Done, check images!']);


return