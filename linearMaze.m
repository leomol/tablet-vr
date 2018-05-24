% 2017-12-13. Leonardo Molina.
% 2018-05-15. Leonardo Molina.
% 2018-05-18. Anil Verman.

classdef linearMaze < handle
    properties
        % intertrialBehavior - Whether to permit behavior during an intertrial.
        intertrialBehavior = false;
        
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 0;
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false;
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = true;
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true;
		
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration = 0.040;
        
        % rewardTone - Frequency and duration of the tone during a reward.
        rewardTone = [2000 0.1];
        
        % tapeTrigger - Whether to initiate a new trial when photosensor
        % detects a tape strip in the belt.
        tapeTrigger = false;
        
        %rand_movie - random 0 or 1 for left or right path for movie mode
        rand_movie = randi([0,1]);
        
        %property of path: YMaze
        %path = pushYMaze();
    end
    
    properties (SetAccess = private)
        % com - Serial port name.
        com = 'COM3';
        
        % filename - Name of the log file.
        filename
        
        % monitors - Target IP addresses and rotation offset for each camera.
        monitors = {'127.0.0.1', 0, '192.168.1.105', 0, '192.168.1.135', -90, '192.168.1.109', 90};
        
        % scene - Name of an existing scene.
        scene = 'linearMaze';
		
        % vertices - Vertices of the maze (x1, y1, x2, y2, ... in cm).
%         vertices = [0, -100, ...
%                     0, 0, ...
%                     0, 1000, ...
%                     0, -Inf];
        vertices = [0, -100,...
                    0, -45,...
                    -35, 0];%this node will either be left or right fork
        
        % resetNode - When resetNode is reached, re-start.
        resetNode = 3;
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
        
        % className - Name of this class.
        className
        
        % enabled - Whether to allow treadmill to cause movement.
        enabled = false;
        
        % fid - Log file identifier.
        fid
        
        % figureHandle - UI handle to control figure.
        figureHandle
        
        mGain = 1;
        
        mSpeed = 50;
        
        % nodes - Nodes object for controlling behavior.
        nodes
        
        % offsets - Monitor rotation offset listed under monitors.
        offsets
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler
        
        % sender - Network communication object.
        sender
        
        % startTime - Reference to time at start.
        startTime
        
        % tapeControl - Control when to trigger a trial based on tape crossings.
        tapeControl = [0 1]
        
        % textBox - Textbox GUI.
        textBox
        
        % treadmill - Arduino controlled apparatus.
        treadmill
        
        % trial - Trial number.
        trial = 1
        
        % update - Last string logged during an update operation.
        update = ''
    end
    
    properties (Constant)
        % programVersion - Version of this class.
        programVersion = '20180515';
    end
    
    methods
        function obj = linearMaze(com)
            % TreadmillMaze()
            % TreadmillMaze(com)
            % Controller for a liner-maze.
            
            if nargin == 0
                com = [];
            end
            
            % Create a log file.
            folder = fullfile(getenv('USERPROFILE'), 'Documents','GitHub', 'VR');
            session = sprintf('VR%s', datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = Files.open(obj.filename, 'a');
            
            % Remember version and session names.
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s', obj.className, TreadmillMaze.programVersion);
            obj.print('nodes-version,%s', Nodes.programVersion);
            obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            obj.print('filename,%s', obj.filename);
            
            % Initialize network.
            obj.addresses = obj.monitors(1:2:end);
            obj.offsets = [obj.monitors{2:2:end}];
            obj.sender = UDPSender(32000);
            
            % Show blank.
            obj.sender.send('enable,Blank,1;', obj.addresses);
            
            % Load an existing scene.
            obj.sender.send(sprintf('scene,%s;', obj.scene), obj.addresses);
            
            % Initialize treadmill controller.
            if isempty(com)
                obj.treadmill = PretendTreadmill();
                obj.print('treadmill-version,%s', PretendTreadmill.programVersion);
            else
                obj.treadmill = ArduinoTreadmill(obj.com);
                obj.treadmill.bridge.register('ConnectionChanged', @obj.onBridge);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            obj.treadmill.register('Tape', @obj.onTape);
            
            % Scheduler object for non-blocking pauses.
            obj.scheduler = Scheduler();
            
            % Initialize nodes.
            obj.nodes = Nodes();
            obj.nodes.register('Change', @(position, distance, yaw, rotation)obj.onChange(position, distance, yaw));
            obj.nodes.register('Lap', @(lap)obj.onLap);
            obj.nodes.register('Node', @obj.onNode);
            obj.nodes.register('Update', @obj.onUpdate);
            obj.nodes.vertices = obj.vertices;
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', mfilename('Class'), 'MenuBar', 'none', 'NumberTitle', 'off', 'DeleteFcn', @(~, ~)obj.delete());
            h(1) = uicontrol('Style', 'PushButton', 'String', 'Stop',  'Callback', @(~, ~)obj.stop());
            h(2) = uicontrol('Style', 'PushButton', 'String', 'Start', 'Callback', @(~, ~)obj.start());
            h(3) = uicontrol('Style', 'PushButton', 'String', 'Reset', 'Callback', @(~, ~)obj.reset());
            h(4) = uicontrol('Style', 'PushButton', 'String', 'Log text', 'Callback', @(~, ~)obj.uiLog());
            h(5) = uicontrol('Style', 'Edit');
            p = get(h(1), 'Position');
            set(h, 'Position', [p(1:2), 4 * p(3), p(4)]);
            align(h, 'Left', 'Fixed', 0.5 * p(1));
            obj.textBox = h(5);
            set(obj.figureHandle, 'Position', [obj.figureHandle.Position(1), obj.figureHandle.Position(2), 4 * p(3) + 2 * p(1), 2 * numel(h) * p(4)])
        end
        
        function blank(obj, duration)
            % TreadmillMaze.pause(duration)
            % Show blank for a given duration.
            
            duration = 0; %hardcoded to not have a delay
            obj.scheduler.stop();
            if duration == 0
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.scheduler.delay({@obj.blank, 0}, duration);
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
            % TreadmillMaze.delete()
            % Release all resources.
            
            obj.treadmill.trigger = false;
            delete(obj.treadmill);
            delete(obj.scheduler);
            delete(obj.nodes);
            delete(obj.sender);
            obj.log('note,delete');
            fclose(obj.fid);
            TreadmillMaze.export(obj.filename);
            if ishandle(obj.figureHandle)
                set(obj.figureHandle, 'DeleteFcn', []);
                delete(obj.figureHandle);
            end
        end
        
        function log(obj, format, varargin)
            % TreadmillMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid, '%.2f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
        end
        
        function pause(obj, duration)
            % TreadmillMaze.pause(duration)
            % Show blank and disable behavior for a given duration.
            
            obj.scheduler.stop();
            if duration == 0
                obj.enabled = true;
                obj.sender.send('enable,Blank,0;', obj.addresses);
            elseif duration > 0
                obj.enabled = false;
                obj.sender.send('enable,Blank,1;', obj.addresses);
                obj.scheduler.delay({@obj.pause, 0}, duration);
            end
        end
        
        function print(obj, format, varargin)
            % TreadmillMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        function reset(obj)
            % TreadmillMaze.reset()
            % Reset trial, position, rotation, frame count and encoder steps.
            
            obj.trial = 1;
            obj.nodes.vertices = obj.vertices;
            % Frame counts and steps are reset to zero.
            obj.treadmill.frame = 0;
            obj.treadmill.step = 0;
            obj.print('note,reset');
        end
        
        function start(obj)
            % TreadmillMaze.start()
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
            % TreadmillMaze.stop()
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
            % TreadmillMaze.newTrial()
            % Send a reward pulse, play a tone, log data, pause, new rand_movie value(0,1) generated.
            
            obj.rand_movie = randi([0,1]); %set path left or right
            if obj.rand_movie == 0 %left path
                obj.nodes.vertices(end-1:end) = [-35,0];
            elseif obj.rand_movie == 1 %right path
                obj.nodes.vertices(end-1:end) = [35,0];
            end
                
            
            obj.treadmill.reward(obj.rewardDuration);
            %Tools.tone(obj.rewardTone(1), obj.rewardTone(2)); makes beep
     
        
            
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
            % TreadmillMaze.onChange(position, distance, yaw)
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
            % TreadmillMaze.onFrame(frame)
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
            % TreadmillMaze.onLap()
            % Ran thru all nodes, disable motion during the intertrial.
            
            obj.newTrial();
        end
        
        function onTape(obj, forward)
            % TreadmillMaze.onTape(state)
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
        
        function onNode(obj, node)
            % TreadmillMaze.onNode(node)
            % Reached a reset node.
            
            if ~obj.tapeTrigger && ismember(node, obj.resetNode)
                obj.nodes.vertices = obj.vertices;
                obj.newTrial();
            end
        end
        
        function onStep(obj, step)
            % TreadmillMaze.onStep(step)
            % The rotary encoder changed, update behavior if enabled
            % Create an entry in the log file otherwise.
            
            if obj.speed == 0 && obj.enabled && ~obj.nodes.rotating
                % Rotary encoder changes position unless open-loop speed is different than 0.
                obj.nodes.push(step * obj.gain);
            end
        end
        
        function onUpdate(obj)
            % TreadmillMaze.onUpdate()
            % Create an entry in the log file if logOnUpdate == true.
            
            if obj.speed ~= 0 && obj.enabled && ~obj.nodes.rotating
                % Open-loop updates position when open-loop speed is different 0.
                obj.nodes.push(obj.speed / obj.nodes.fps);
                
                %obj.pushYMaze(obj.speed / obj.nodes.fps); for my push func
            end
            
            if obj.logOnUpdate
                str = sprintf('data,%i,%i,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.nodes.distance, obj.nodes.yaw, obj.nodes.position(1), obj.nodes.position(2));
                if ~strcmp(str, obj.update)
                    obj.update = str;
                    obj.log(str);
                end
            end
        end
        
%         function pushYMaze(obj, speed)
%             %random 0 or 1
%             % if 0
%             %    do left path
%             % if 1 
%             %    do right path
%             split = 5; %split position
%             
%             if obj.rand_movie == 0 %left
%                 theta = -45; %degrees
%                 if obj.position(1) < split %if z value is less than where split is 
%                     %go straight
%                     obj.nodes.push(obj.speed / obj.nodes.fps);
%                     
%                 else 
%                     %take left path
%                     
%                 end
%                 
%             elseif obj.rand_movie == 1%right
%                 theta = 45; %degrees
%                 if obj.position(1) < split %if z value is less than where the split is 
%                     %go straight
%                     obj.nodes.push(obj.speed / obj.nodes.fps);
%                 else
%                     %take right path
%                     
%                 end
%             end
%             obj.distance = obj.distance + change;
%             theta = obj.distance / obj.radius;
%             obj.position = obj.radius * [sin(theta), cos(theta)];
% 
%             % Update monitors with any change in position and rotation.
%             % Always head tangent to the circle.
%             obj.rotation = 90 + atan2(obj.position(1), obj.position(2)) / pi * 180;
%             
%             
%             obj.sender.send(Tools.compose([sprintf(...
%                 'position,Main Camera,%.2f,1,%.2f;', obj.position(1), obj.position(2)), ...
%                 'rotation,Main Camera,0,%.2f,0;'], obj.rotation + obj.offsets), ...
%                 obj.addresses);
%         end
            
        
        function uiLog(obj)
            % TreadmillMaze.uiLog()
            % Log user text.
            
            obj.print('note,%s', obj.textBox.String);
            obj.textBox.String = '';
        end
    end
    
    methods (Static)
        function export(filename)
            % TreadmillMaze.export(filename)
            % Convert log file to a mat file.
            
            header = {'time (s)', 'frame', 'encoder-step', 'unfolded-distance (cm)', 'y-rotation (degrees)', 'x-position (cm)', 'z-position (cm)'};
            data = str2double(CSV.parse(CSV.load(filename), [-1 1:6], 'data'));
            [folder, filename] = fileparts(filename);
            save(fullfile(folder, sprintf('%s.mat', filename)), 'header', 'data');
        end
    end
end

%#ok<*NASGU>