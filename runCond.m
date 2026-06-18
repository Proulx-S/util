classdef runCond
    % Encapsulate various data derived from one or several repeated
    % acquisition runs. Each run must be acquired under similar acquisition
    % conditions, e.g. with the same MRI pulse sequence, same MRI protocol
    % and same fMRI task or stimulus.
    % Note that different task/event/stimulus conditions should go in
    % different runCond when acquired in different runs.

   properties
      % Header info
      info % [struct]
      sub
      ses % [run x 1]
      acq
      prsc
      vencAcq
      vencRec
      task
      dsgn
      dirs
      dirsOrig
      fList         % [run x 1]
      fPreprocList  % at preproc [run x multiVar x preprocStep] OR after preproc [run x echo x complexDataDerivatives]
      fPreprocMaskList % [run x 1 x preprocStep]
      fTransList    % [run x 1]
      fTransCatList % [run x 1]
      fOrigList     % [run x 1]
      bidsList     % [run x 1]
      bidsDir      % [run x 1]
      bidsDerivDir % [run x 1]
      wd % [run x 1]
      dataType    % [1 label]
      ppLabelList % [1 label]
      date          % [run x 1]
      acqTime       % [run x 1]
      nFrame        % [run x 1]
      nFrameOrig    % [run x 1]
      tr
      trExc
      nDummy        % [run x 1]
      nDummyRemoved % [run x 1]
      tsStartTime   % [scalar s] time of the first preprocessed (dummy-removed) ts frame in the stimulus clock = (nFrameOrig-nFrame)*tr. The stimulus clock t=0 is the MRI scanner trigger (sent to the stimulus computer at the START of one data point's acquisition); dsgn.onsetList/onDur are measured from it. Equivalent index form used by the analysis: triggerIdx = 1 - tsStartTime/dt (ts index of the t=0 data point; frame j sits at (j-triggerIdx)*dt). <=0 here, since lead-in frames acquired at/after t=0 were dropped.
      dt            % [run x 1]
      vSize         % [run x dim]
      % Data [run x 1]
      volTs
      volResp
      volMt
      volPsd
      volAnat
      bhvr   
      phs
      QA
      r
      R
      mri
      fClustId
      mainClustId
      fCnsr
      fCnsr_mainClust
   end
end