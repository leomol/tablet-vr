% PretendTreadmill()
% Control using TreadmillInterface for debugging purpuses.
% 
% PretendTreadmill methods:
%   reward - Send a reward for the given duration.
%   register - Register to events.
% 
% PretendTreadmill events:
%   register('Frame', @callback) - An input frame was detected.
%   register('Step', @callback)  - Treadmill position changed.

% 2018-03-05. Leonardo Molina.
% 2018-05-10. Last modified.
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
        % fps - Frames per second for time integration.
        fps = 50
        
        % programVersion - Program version.
        programVersion = '20180510'
    end
    
    properties (Access = private)
        % figureHandle - UI handle to control figure.
        figureHandle
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler = Scheduler()
        
        % speed - Current speed (cm/s).
        speed = 15
        
        % triggerState - Binary state of the triggerPin.
        triggerState = false
    end
    
    methods
        function obj = PretendTreadmill()
            % PretendTreadmill()
            % - Create a figure to trigger treadmill like events.
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off');
            h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
            h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
            h(3) = uicontrol('Style', 'Edit', 'String', sprintf('%.2f', obj.speed), 'Callback', @(handle, event)obj.onText(handle));
            p = get(h(1), 'Position');
            set(h, 'Position', [p(1:2), 2 * p(3), p(4)]);
            align(h, 'Left', 'Fixed', 0.5 * p(1));
            set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 2 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
            
            obj.trigger = false;
            obj.start();
        end
        
        function delete(obj)
            % PretendTreadmill.delete
            % Release resources.
            
            delete(obj.scheduler);
            if Objects.isValid(obj.figureHandle)
                delete(obj.figureHandle);
            end
        end
        
        function reward(~, duration)
            % PretendTreadmill.reward(duration)
            % Pretend to send a pulse for the given duration to the rewarding device (e.g. pinch-valve).
            
            fprintf('[pretend-treadmill] Reward was delivered for %.2fs.\n', duration);
        end
        
        function start(obj)
            obj.stop();
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onStep, 1 / obj.fps);
            obj.scheduler.repeat(@obj.onFrame, 5 / obj.fps);
        end
        
        function stop(obj)
            delete(obj.scheduler);
        end
        
        function triggerState = get.trigger(obj)
            triggerState = obj.triggerState;
        end
        
        function set.trigger(obj, triggerState)
            if numel(triggerState) == 1 && islogical(triggerState)
                obj.triggerState = triggerState;
                if triggerState
                    state = 'HIGH';
                else
                    state = 'LOW';
                end
                fprintf('[pretend-treadmill] Trigger-out state: %s.\n', state);
            end
        end
    end
    
    methods (Access = private)
        function onText(obj, handle)
            % PretendTreadmill.onText(obj, handle)
            
            number = str2double(handle.String);
            if isnan(number) || isinf(number)
                handle.String = sprintf('%.2f', obj.speed);
            else
                obj.speed = number;
            end
        end
        
        function onFrame(obj)
            obj.frame = obj.frame + 1;
            obj.invoke('Frame', obj.frame);
        end
        
        function onStep(obj)
            obj.invoke('Step', obj.speed / obj.fps);
        end
    end
end