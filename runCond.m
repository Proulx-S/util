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
      tsStartTime   % [scalar s] time of the first preprocessed (dummy-removed) ts frame relative to the full (with-dummy) ts 0s start = (nFrameOrig-nFrame)*tr. dsgn.onsetList is in full-ts time, so account for this offset when aligning ts to onsets.
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