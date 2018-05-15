% 2017-12-13. Leonardo Molina.
% 2018-05-10. Last modified.
classdef CircularMaze < handle
    properties (Access = public)
        % gain - Forward speed factor.
        gain = 1
        
        % intertrial - Duration (s) of an intertrial when last node is reached.
        intertrialDuration = 0
        
        % logOnChange - Create a log entry with every change in position or rotation.
        logOnChange = false
        
        % logOnFrame - Create a log entry with every trigger-input.
        logOnFrame = true
        
        % logOnUpdate - Create a log entry at the frequency of the behavior controller.
        logOnUpdate = true
		
        % rewardDuration - Duration (s) the reward valve remains open after a trigger.
        rewardDuration = 0.050
        
        % scene - Name of an existing scene.
        scene = 'Classroom'
    end
    
    properties (SetAccess = private)
        % distance - Traveled distance over the path.
        distance = 0
        
        % filename - Name of the log file.
        filename
        
        % monitors - Target IP addresses and rotation offset for each camera.
        monitors = {'127.0.0.1', 0, '192.168.1.101', 0, '192.168.1.102', -90, '192.168.1.103', 90};
        
        % position - Current x/z position.
        position = [0, 0]
    end
    
    properties (Access = private)
        % addresses - IP addresses listed under monitors.
        addresses
        
        % className - Name of this class.
        className
        
        % enabled - Whether to allow treadmill to cause movement.
        enabled = false
        
        % fid - Log file identifier.
        fid
        
        % figureHandle - UI handle to control figure.
        figureHandle
        
        % nodes - Nodes object for controlling behavior.
        nodes
        
        % offsets - Monitor rotation offset listed under monitors.
        offsets
        
        % pauseId - Process id for scheduling pauses.
        pauseId
    
        % radius - Radius (cm) of the circular path.
        radius = 25
        
        % rotation - Rotation of the camera.
        rotation = 0
        
        % scheduler - Scheduler object for non-blocking pauses.
        scheduler
        
        % sender - Network communication object.
        sender
        
        % startTime - Reference to time at start.
        startTime
        
        % treadmill - Arduino controlled apparatus.
        treadmill
        
        % trial - Trial number.
        trial = 1
        
        % vertices - Vertices of the maze (x1, y1, x2, y2, ... in cm).
        vertices
        
        catPosition = 0
    end
    
    properties (Constant)
        % fps - Frames per seconds for time integration; should match VR game.
        fps = 50
        
        % programVersion - Version of this function.
        programVersion = '20180515'
    end
    
    methods
        function obj = CircularMaze(com)
            % CircularMaze()
            % CircularMaze(com)
            % Controller for a circular-maze.
            
            if nargin == 0
                com = [];
            end
            
            % Log file.
            root = getenv('USERPROFILE');
            folder = fullfile(root, 'Documents', 'VR');
            if exist(folder, 'dir') ~= 7
                mkdir(folder);
            end
            session = sprintf('VR%s', datestr(now, 'yyyymmddHHMMSS'));
            obj.filename = fullfile(folder, sprintf('%s.csv', session));
            obj.fid = fopen(obj.filename, 'a');
            obj.startTime = tic;
            
            % Initialize network.
            obj.addresses = obj.monitors(1:2:end);
            obj.offsets = [obj.monitors{2:2:end}];
            obj.sender = UDPSender(32000);
                        
            % Log program versions.
            obj.startTime = tic;
            obj.className = mfilename('class');
            obj.print('maze-version,%s,%s', obj.className, CircularMaze.programVersion);
            obj.print('nodes-version,%s', Nodes.programVersion);
            obj.print('filename,%s', obj.filename);
            
            % Initialize treadmill controller.
            if isempty(com)
                obj.treadmill = PretendTreadmill();
                obj.print('treadmill-version,%s', PretendTreadmill.programVersion);
            else
                obj.treadmill = ArduinoTreadmill(com);
                obj.print('treadmill-version,%s', ArduinoTreadmill.programVersion);
            end
            obj.treadmill.register('Frame', @obj.onFrame);
            obj.treadmill.register('Step', @obj.onStep);
            
            obj.scheduler = Scheduler();
            obj.scheduler.repeat(@obj.onUpdate, 1 / obj.fps);
            
            % Release resources when the figure is closed.
            obj.figureHandle = figure('Name', 'Close to terminate', 'MenuBar', 'none', 'NumberTitle', 'off', 'DeleteFcn', @(~, ~)obj.delete());
            
            % Auto-start.
            obj.start();
        end
        
        function delete(obj)
            % CircularMaze.delete()
            % Release all resources.
            
            delete(obj.scheduler);
            obj.treadmill.trigger = false;
            delete(obj.treadmill);
            delete(obj.sender);
            obj.log('delete');
            fclose(obj.fid);
            CircularMaze.export(obj.filename);
            if ishandle(obj.figureHandle)
                set(obj.figureHandle, 'DeleteFcn', []);
                delete(obj.figureHandle);
            end
        end
        
        function log(obj, format, varargin)
            % CircularMaze.log(format, arg1, arg2, ...)
            % Create a log entry using the same syntax as sprintf.
            
            fprintf(obj.fid, '%.4f,%s\n', toc(obj.startTime), sprintf(format, varargin{:}));
        end
        
        function pause(obj, duration)
            % CircularMaze.pause(duration)
            % Show blank and disable behavior for a given duration.
            
            obj.scheduler.stop(obj.pauseId);
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
            % CircularMaze.print(format, arg1, arg2, ...)
            % Print on screen and create a log entry using the same syntax as sprintf.
            
            fprintf('[%.1f] %s\n', toc(obj.startTime), sprintf(format, varargin{:}));
            obj.log(format, varargin{:});
        end
        
        function reset(obj)
            % CircularMaze.reset()
            % Reset trial, position, rotation, frame count and encoder steps.
            
            obj.trial = 1;
            % Frame counts and steps are reset to zero.
            obj.treadmill.frame = 0;
            obj.treadmill.step = 0;
            obj.print('note,reset');
        end
        
        function start(obj)
            % CircularMaze.start()
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
            % CircularMaze.stop()
            % Send low pulse to trigger-out and disable behavior.
            
            % Show blank and disable external devices and behavior.
            obj.treadmill.trigger = false;
            obj.sender.send('enable,Blank,1;', obj.addresses);
            obj.enabled = false;
            obj.print('note,stop');
        end
    end
    
    methods (Access = private)
        function onFrame(obj, frame)
            % CircularMaze.onFrame(frame)
            % The trigger input changed from low to high.
            % Create an entry in the log file if logOnFrame == true.
            
            % Log changes including frame count and rotary encoder changes.
            if obj.logOnFrame
                obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
            end
        end
        
        function onStep(obj, step)
            % CircularMaze.onStep(step)
            % The rotary encoder changed, update behavior if enabled
            % Create an entry in the log file otherwise.
            
            if obj.enabled
                change = step * obj.gain;
                obj.distance = obj.distance + change;
                theta = obj.distance / obj.radius;
                obj.position = obj.radius * [sin(theta), cos(theta)];
                
                % Update monitors with any change in position and rotation.
                % Always head tangent to the circle.
                obj.rotation = 90 + atan2(obj.position(1), obj.position(2)) / pi * 180;
                obj.sender.send(Tools.compose([sprintf(...
                    'position,Main Camera,%.2f,1,%.2f;', obj.position(1), obj.position(2)), ...
                    'rotation,Main Camera,0,%.2f,0;'], obj.rotation + obj.offsets), ...
                    obj.addresses);
                
                % Create an entry in the log file.
                if obj.logOnChange
                    obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
                end
            end
        end
        
        function onUpdate(obj)
            % CircularMaze.onUpdate()
            % Create an entry in the log file if logOnUpdate == true.
            
            obj.catPosition = obj.catPosition + 0.1;
            obj.sender.send(sprintf('position,Cat,0,%.2f,2;', obj.catPosition), obj.addresses);
            
            if obj.logOnUpdate
                obj.log('data,%i,%.2f,%.2f,%.2f,%.2f,%.2f', obj.treadmill.frame, obj.treadmill.step, obj.distance, obj.rotation, obj.position(1), obj.position(2));
            end
        end
    end
    
    methods (Static)
        function export(filename)
            % CircularMaze.export(filename)
            % Convert log file to a mat file.
            
            header = {'time (s)', 'frame', 'encoder-step (cm)', 'unfolded-distance (cm)', 'y-rotation (degrees)', 'x-position (cm)', 'z-position (cm)'};
            data = str2double(CSV.parse(CSV.load(filename), [-1 1:6], 'data'));
            [folder, filename] = fileparts(filename);
            save(fullfile(folder, sprintf('%s.mat', filename)), 'header', 'data');
        end
    end
end

%#ok<*NASGU>