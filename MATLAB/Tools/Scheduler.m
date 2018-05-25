% Scheduler - Invoke functions or methods with a delay.
% Scheduler methods:
%   delay  - Invoke a method or function with a delay.
%   repeat - Invoke a method or function with repetition.
%   stop   - Stop a schedule.

% 2016-05-12. Leonardo Molina.
% 2018-03-22. Last modified.
classdef Scheduler < handle
    properties (Access = private)
        tickers = []
        count = 0
        timerTag
    end
    
    methods
        function obj = Scheduler(tag)
            % Scheduler.Scheduler
            % Creates an scheduler which invokes user callbacks after a delay or with a
            % given periodicity.
            
            if nargin == 1
                obj.timerTag = tag;
            else
                obj.timerTag = mfilename('class');
            end
        end
        
        function delete(obj)
            Timers.delete(obj.tickers);
        end
        
        function id = delay(obj, callback, delay)
            % id = Scheduler.delay(callback, delay)
            % Invoke a callback after the given delay. Output id is a 
            % reference to this process.
            % See also repeat.
            
            id = obj.repeat(callback, delay, 1);
        end
        
        function id = repeat(obj, callback, period, repetitions)
            % id = Scheduler.repeat(period, callback, repetitions)
            % Invoke a callback a number of times, with the given
            % periodicity. Repetitions defaults to infinity.
            % Output id is a reference to this process.
            % See also stop, Callbacks.invoke.
            
            period = min(max(round(period * 1e3), 0), 2.1474e6) / 1e3;
            if ~iscell(callback)
                callback = {callback};
            end
            if nargin < 4
                repetitions = Inf;
            end
            if period == 0
                id = 0;
                Callbacks.invoke(callback{:});
            else
                ticker = timer('Name', obj.timerTag, 'TimerFcn', {@Timers.forward, callback{:}}, 'ExecutionMode', 'fixedSpacing', 'StartDelay', period, 'Period', period, 'TasksToExecute', repetitions, 'BusyMode', 'drop'); %#ok<CCAT>
                id = obj.pushIndex(ticker);
                start(ticker);
            end
        end
        
        function stop(obj, id)
            % Scheduler.stop(id)
            % Stop a process associated to the given id.
            % Scheduler.stop()
            % Stop all processes.
            % See also Scheduler.repeat, Callbacks.call.
            
            if nargin == 2
                if id >= 1 && id <= Objects.numel(obj.tickers)
                    Timers.delete(obj.tickers(id));
                end
            else
                for id = 1:Objects.numel(obj.tickers)
                    obj.stop(id);
                end
            end
        end
    end
    
    methods (Access = private)
        function id = pushIndex(obj, ticker)
            obj.count = obj.count + 1;
            id = obj.count;
            obj.tickers = [obj.tickers ticker];
        end
    end
    
    methods (Static)
        function Delay(varargin)
            instance = Global.get('Scheduler', Scheduler());
            instance.delay(varargin{:});
        end
        
        function Repeat(varargin)
            instance = Global.get('Scheduler', Scheduler());
            instance.repeat(varargin{:});
        end
    end
end