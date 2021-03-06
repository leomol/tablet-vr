% LinearMaze - Controller for a linear maze using custom behavioral apparatus.
% 
% Movement is initiated by a subject running on a treadmill. Multiple monitors
% are placed around the field of view of the subject to create an immersive
% virtual environment. These monitors consist of tablets synchronized with
% the controller via WiFi, using UDP packets.
% Actuators such as pinch valves for reward or punishment can also be controlled here.
% Synchronization with data acquisition systems can be accomplished using
% methods start, stop, and reset.
% Constant forward speed can also be produced in the absence of a treadmill
% by changing the property speed.
% Behavioral data is saved locally every step and exported to a mat file at
% the end of the recording session.
% 
% LinearMaze methods:
%   blank  - Show blank for a given duration.
%   delete - Release all resources.
%   log    - Create a log entry using the same syntax as sprintf.
%   pause  - Show blank and disable behavior for a given duration.
%   print  - Print on screen and create a log entry using the same syntax as sprintf.
%   reset  - Reset trial, position, rotation, frame count and encoder steps.
%   start  - Send high pulse to trigger-out and enable behavior.
%   stop   - Send low pulse to trigger-out and disable behavior.
% 
% LinearMaze properties:
%   gain   - Forward speed factor in closed-loop when the rotary encoder produces movement.
%   speed  - Forward speed in open-loop.
% 
% Please note that these classes are in early stages and are provided "as is"
% and "with all faults". You should test throughly for proper execution and
% proper data output before running any behavioral experiments.
%
% Tested on MATLAB 2018a.
% 
% See also CircularMaze, TableTop, TwoChoice.

% 2017-12-13. Leonardo Molina.
% 2018-09-28. Leonardo Molina.
classdef LinearMaze < handle
    properties
        % intertrialBehavior - Whether to permit behavior during an intertrial.
        intertrialBehavior = false
        
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 1
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = true
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true
		
        % rewardMode - When to deliver a reward.
        %  onTrial: deliver a reward when a new trial is issued.
        %  onTrialLick: enable a reward when a new trial is issued which must
        %    be claimed by licking the feeder within the rewardWindow.
        %  onPositionLick: enable a reward when a target position is reached
        %    and reward must be claimed by licking the feeder within the rewardWindow.
        rewardMode = 'onPositionLick'
        
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration = 0.040
        
        % rewardTone - Frequency and duration of the tone during a reward.
        rewardTone = [2000, 0.5]
        
        % rewardWindow - Time (s) window after a trial to allow claiming a reward.
        rewardWindow = 3
        
        % rewardPosition - Position to reward on lick.
        rewardPosition = -50
        
        % tapeTrigger - Whether to initiate a new trial when photosensor
        % detects a tape strip in the belt.
        tapeTrigger = false
        
        % treadmill - Arduino controlled apparatus.
        treadmill
    end
    
    properties (SetAccess = private)
        % filename - Name of the log file.
        filename
        
        % scene - Name of an existing scene (Tunnel|Classroom).
        scene = 'Tunnel';
		
        % vertices - Vertices of the maze (x1, y1, x2, y2, ... in cm).
        vertices = [0, -100, ...
                    0,    0, ...
                    0, 1000, ...
                    0, -Inf]
        
        % resetNode - When resetNode is reached, re-start.
        resetNode = 2
    end
    
    properties (Dependent)
        % gain - Forward speed factor in closed-loop when the rotary encoder produces movement.
        gain
        
        % speed - Forward speed in open-loop.
        speed
    end
    
    properties (Access = private)
        % addresses - IP addresses listed under monitors.
        addresses
        
        % blankId - Process id for scheduling blank periods.
        blankId
        
        % className - Name of this class.
        className
        
        % enabled - Whether to allow treadmill to cause movement.
        enabled = false
        
        % fid - Log file identifier.
        fid
        
        % figureHandle - UI handle to control figure.
        figureHandle
        
        mGain = 1
        
        mSpeed = 0
        
        % nodes - Nodes object for controlling behavior.
        nodes
        
        % offsets - Monitor rotation offset listed under monitors.
        offsets
        
        % pauseId - Process id for scheduling pauses.
        pauseId
        
        % rewardEnabled - Whether a reward is enabled in the current trial.
        rewardEnabled = false
        
        % rewardTimeout - Time when a reward is set to expire.
        rewardTimeout = 0
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler
        
        % sender - Network communication object.
        sender
        
        % startTime - Reference to time at start.
        startTime
        
        % tapeControl - Control when to trigger a trial based on tape crossings.
        tapeControl = [0, 1]
        
        % textBox - Textbox GUI.
        textBox
        
        % trial - Trial number.
        trial = 1
        
        % update - Last string logged during an update operation.
        update = ''
    end
    
    properties (Constant)
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this class.
        programVersion = '20180928'
    end
    
    methods
        function obj = LinearMaze(varargin)
            % LinearMaze()
            %   Controller for a liner-maze.
            % LinearMaze('com', comPortName, ...)
            %   Provide the serial port name of the treadmill (rotary encoder, pinch valve,
            %   photo-sensor, and lick-sensors assumed connected to an Arduino microcontroller
            %   running a matching firmware).
            % LinearMaze('monitors', {ip1, offset1, ip2, offset2, ...}, ...)
            %   Provide IP address of each monitor tablet and rotation offset for each camera.
            
            keys = varargin(1:2:end);
            values = varargin(2:2:end);
            k = find(strcmpi(keys, 'com'), 1);
            if isempty(k)
                com = [];
            else
                com = values{k};
            end
            k = find(strcmpi(keys, 'monitors'), 1);
            if isempty(k)
                monitors = {'127.0.0.1', 0};
            else
                monitors = values{k};
            end
            
            % Initialize network.
            obj.addresses = monitors(1:2:end);
            obj.offsets = [monitors{2:2:end}];
            obj.sender = UDPSender(32000);
            
            % Create a log file.
            folder = fullfile(getenv('USERPROFILE'), 'Documents', 'VR');
            session = sprintf('VR%s', datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = Files.open(obj.filename, 'a');
            
            % Remember version and session names.
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s-%s', obj.className, LinearMaze.programVersion);
            obj.print('nodes-version,%s', Nodes.programVersion);
            obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            obj.print('filename,%s', obj.filename);
            
            % Show blank.
            obj.sender.send('enable,Blank,1;', obj.addresses);
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Initialize treadmill controller.
            if isempty(com)
                obj.treadmill = TreadmillInterface();
                obj.print('treadmill-version,%s', TreadmillInterface.programVersion);
            else
                obj.treadmill = ArduinoTreadmill(com);
                obj.treadmill.bridge.register('ConnectionChanged', @obj.onBridge);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            obj.treadmill.register('Tape', @obj.onTape);
            obj.treadmill.register('Lick', @obj.onLick);
            
            % Initialize nodes.
            obj.nodes = Nodes();
            obj.nodes.register('Change', @(position, distance, yaw, rotation)obj.onChange(position, distance, yaw));
            obj.nodes.register('Lap', @(lap)obj.onLap);
            obj.nodes.register('Node', @obj.onNode);
            obj.nodes.vertices = obj.vertices;
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off', 'DeleteFcn', @(~, ~)obj.delete());
            h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
            h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
            h(3) = uicontrol('Style', 'PushButton', 'String', 'Reset', 'Callback', @(~, ~)obj.reset());
            h(4) = uicontrol('Style', 'PushButton', 'String', 'Log text', 'Callback', @(~, ~)obj.onLogButton());
            h(5) = uicontrol('Style', 'Edit');
            p = get(h(1), 'Position');
            set(h, 'Position', [p(1:2), 4 * p(3), p(4)]);
            align(h, 'Left', 'Fixed', 0.5 * p(1));
            obj.textBox = h(5);
            set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 4 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
            
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
        end
        
        function blank(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank for a given duration.
            
            Objects.delete(obj.blankId);
            if duration == 0
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.blankId = obj.scheduler.delay({@obj.blank, 0}, duration);
            end
        end
        
        function set.gain(obj, gain)
            obj.mGain = gain;
            obj.print('gain,%.2f', gain);
        end
        
        function gain = get.gain(obj)
            gain = obj.mGain;
        end
        
        function set.speed(obj, speed)
            obj.print('speed,%.2f', speed);
            obj.mSpeed = speed;
        end
        
        function speed = get.speed(obj)
            speed = obj.mSpeed;
        end
        
        function delete(obj)
            % LinearMaze.delete()
            % Release all resources.
            
            obj.treadmill.trigger = false;
            delete(obj.treadmill);
            delete(obj.scheduler);
            delete(obj.nodes);
            delete(obj.sender);
            obj.log('note,delete');
            fclose(obj.fid);
            LinearMaze.export(obj.filename);
            if ishandle(obj.figureHandle)
                set(obj.figureHandle, 'DeleteFcn', []);
                delete(obj.figureHandle);
            end
        end
        
        function log(obj, format, varargin)
            % LinearMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid, '%.2f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
        end
        
        function pause(obj, duration)
            % LinearMaze.pause(duration)
            % Show blank and disable behavior for a given duration.
            
            Objects.delete(obj.pauseId);
            if duration == 0
                obj.enabled = true;
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.enabled = false;
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.pauseId = obj.scheduler.delay({@obj.pause, 0}, duration);
            end
        end
        
        function print(obj, format, varargin)
            % LinearMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        function reset(obj)
            % LinearMaze.reset()
            % Reset trial, position, rotation, frame count and encoder steps.
            
            obj.trial = 1;
            obj.nodes.vertices = obj.vertices;
            % Frame counts and steps are reset to zero.
            obj.treadmill.frame = 0;
            obj.treadmill.step = 0;
            obj.print('note,reset');
        end
        
        function start(obj)
            % LinearMaze.start()
            % Send high pulse to trigger-out and enable behavior.
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Hide user menu.
            obj.sender.send('enable,Menu,0;', obj.addresses);
            
            % Hide blank and enable external devices and behavior.
            obj.sender.send('enable,Blank,0;', obj.addresses);
            
            % Send a high pulse to trigger-out.
            obj.treadmill.trigger = true;
            obj.enabled = true;
            obj.print('note,start');
        end
        
        function stop(obj)
            % LinearMaze.stop()
            % Send low pulse to trigger-out and disable behavior.
            
            % Show blank and disable external devices and behavior.
            obj.treadmill.trigger = false;
            obj.sender.send('enable,Blank,1;', obj.addresses);
            obj.enabled = false;
            obj.print('note,stop');
        end
    end
    
    methods (Access = private)
        function newTrial(obj)
            % LinearMaze.newTrial()
            % Send a reward pulse, play a tone, log data, pause.
            
            switch obj.rewardMode
                case 'onTrial'
                    obj.treadmill.reward(obj.rewardDuration);
                    Tools.tone(obj.rewardTone(1), obj.rewardTone(2));
                    obj.rewardEnabled = false;
                case 'onTrialLick'
                    obj.rewardTimeout = toc(obj.startTime) + obj.rewardWindow;
                    obj.rewardEnabled = true;
                case 'onPositionLick'
                    obj.rewardEnabled = false;
            end
            
            % Disable movement and show blank screen for the given duration.
            if obj.intertrialBehavior
                obj.blank(obj.intertrialDuration);
            else
                obj.pause(obj.intertrialDuration);
            end
            obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
            obj.trial = obj.trial + 1;
            obj.print('trial,%i', obj.trial);
        end
        
        function onBridge(obj, connected)
            if connected
                obj.print('note,Arduino connected.');
            else
                obj.print('note,Arduino disconnected.');
            end
        end
        
        function onChange(obj, position, distance, yaw)
            % LinearMaze.onChange(position, distance, yaw)
            % Update monitors with any change in position and rotation.
            % Create an entry in the log file if logOnChange == true.
            
            obj.sender.send(Tools.compose([sprintf(...
                'position,Main Camera,%.2f,1,%.2f;', position(1), position(2)), ...
                'rotation,Main Camera,0,%.2f,0;'], yaw + obj.offsets), ...
                obj.addresses);
            
            if obj.logOnChange
                obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, distance, yaw, position(1), position(2));
            end
        end
        
        function onFrame(obj, frame)
            % LinearMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            if obj.logOnFrame
                obj.log('data,%i,%i,%.2f,%.2f,%.2f,%.2f', frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
            end
            
            % Change the name to reflect frame number.
            set(obj.figureHandle, 'Name', sprintf('%s - Frame: %i', mfilename('Class'), frame));
        end
        
        function onLap(obj)
            % LinearMaze.onLap()
            % Ran thru all nodes, disable motion during the intertrial.
            
            obj.newTrial();
        end
        
        function onLogButton(obj)
            % LinearMaze.onLogButton()
            % Log user text.
            
            if ~isempty(obj.textBox.String)
                obj.print('note,%s', obj.textBox.String);
                obj.textBox.String = '';
            end
        end
        
        function onTape(obj, forward)
            % LinearMaze.onTape(state)
            % Treadmill's photosensor detected a reflective tape in the belt.
            
            if obj.enabled && obj.tapeTrigger
                if forward
                    obj.tapeControl(1) = obj.tapeControl(1) + 1;
                else
                    obj.tapeControl(1) = obj.tapeControl(1) - 1;
                end
                if obj.tapeControl(1) == obj.tapeControl(2)
                    obj.tapeControl(2) = obj.tapeControl(2) + 1;
                    obj.newTrial();
                end
            end
        end
        
        function onLick(obj, state)
            % LinearMaze.onLick(state)
            % Log licks. Also if enabled, deliver a reward on lick.
            
            if state
                if toc(obj.startTime) < obj.rewardTimeout && obj.rewardEnabled
                    obj.rewardTimeout = 0;
                    obj.treadmill.reward(obj.rewardDuration);
                    Tools.tone(obj.rewardTone(1), obj.rewardTone(2));
                end
                obj.log('lick');
            end
        end
        
        function onNode(obj, node)
            % LinearMaze.onNode(node)
            % Reached a reset node.
            
            if ~obj.tapeTrigger && ismember(node, obj.resetNode)
                obj.nodes.vertices = obj.vertices;
                obj.newTrial();
            end
        end
        
        function onStep(obj, step)
            % LinearMaze.onStep(step)
            % The rotary encoder changed, update behavior if enabled.
            % Create an entry in the log file otherwise.
            
            if obj.enabled && obj.speed == 0 && ~obj.nodes.rotating
                % Rotary encoder changes position unless open-loop speed is different than 0.
                obj.nodes.push(step * obj.gain);
            end
        end
        
        function onUpdate(obj)
            % LinearMaze.onUpdate()
            % Create an entry in the log file if logOnUpdate == true.
            
            if isequal(obj.rewardMode, 'onPositionLick') && obj.nodes.position(2) >= obj.rewardPosition && obj.rewardEnabled == false
                obj.rewardEnabled = true;
                obj.rewardTimeout = toc(obj.startTime) + obj.rewardWindow;
            end
            
            if obj.speed ~= 0 && obj.enabled && ~obj.nodes.rotating
                % Open-loop updates position when open-loop speed is different 0.
                obj.nodes.push(obj.speed / obj.nodes.fps);
            end
            
            if obj.logOnUpdate
                str = sprintf('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
                if ~strcmp(str, obj.update)
                    obj.update = str;
                    obj.log(str);
                end
            end
        end
    end
    
    methods (Static)
        function export(filename)
            % LinearMaze.export(filename)
            % Convert log file to a mat file.
            
            header = {'time (s)', 'frame', 'encoder-step', 'unfolded-distance (cm)', 'y-rotation (degrees)', 'x-position (cm)', 'z-position (cm)'};
            data = str2double(CSV.parse(CSV.load(filename), [-1 1:6], 'data'));
            [folder, filename] = fileparts(filename);
            save(fullfile(folder, sprintf('%s.mat', filename)), 'header', 'data');
        end
    end
end

%#ok<*NASGU>