% PretendTreadmill()
% Control using TreadmillInterface for debugging purpuses.
% 
% PretendTreadmill methods:
%   reward - Send a reward for the given duration.
% 
% PretendTreadmill events:
%   register('Frame', @callback) - An input frame was detected.
%   register('Step', @callback)  - Treadmill position changed.

% 2018-03-05. Leonardo Molina.
% 2018-05-17. Last modified.
classdef PretendTreadmill < Event
    properties
        % step - Encoder position.
        step = 0
        
        % frame - trigger-in count.
        frame = 0
    end
    
    properties (Dependent)
        % trigger - trigger-out pulse.
        trigger
    end
    
    properties (Constant)
        % programVersion - Program version.
        programVersion = '20180517'
    end
    
    properties (Access = private)
        % triggerState - Binary state of the triggerPin.
        triggerState = false
    end
    
    methods
        function obj = PretendTreadmill()
            % PretendTreadmill()
        end
        
        function delete(~)
            % PretendTreadmill.delete
        end
        
        function reward(~, ~)
            % PretendTreadmill.reward(duration)
            % Pretend to send a pulse for the given duration to the rewarding device (e.g. pinch-valve).
        end
        
        function triggerState = get.trigger(obj)
            triggerState = obj.triggerState;
        end
        
        function set.trigger(obj, triggerState)
            if numel(triggerState) == 1 && islogical(triggerState)
                obj.triggerState = triggerState;
            end
        end
    end
end