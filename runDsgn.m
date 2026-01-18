classdef runDsgn
    % Encapsulate definition of stimulus design.

   properties
      % Header info
      task      % [str] label
      onsetList % [num: 1 x nEvent] onset time of each event/trial, in seconds (trigger time = 0)
      ondurList % [num: 1 x nEvent] duration of each event/trial, in seconds
      dt        % [num] time grid on which events/trials were defined (not sure it's usefull, should probably be the default tr for response shape estimation with afni's 3dDeconvolve)
      cond      % [int: 1 x nEvent] index of event/trial condition (0 is special for null event/trial, other conditions should be increments of 1)
      condLabel % [cellstr: 1 x nConditions] event/trial condition labels (indices corresponds to values of cond)
      condK     % [int: 1 x 1] number of event/trial conditions
      nReg      % [i] number of regressors
      winSec    % [num,num] window length,step in seconds
      win       % [int,int] window length,step in number of frames
   end
end
