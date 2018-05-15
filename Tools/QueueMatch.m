% 2016-05-12. Leonardo Molina.
% 2018-03-22. Last modified.
classdef QueueMatch < handle
    properties (Access = private)
        target
        nCompleted = 0
    end
    
    methods
        function obj = QueueMatch(target)
            obj.target = target;
        end
        
        function [nc, at] = Push(obj, input)
            nc = obj.nCompleted;
            at = 0;
            if ~isempty(obj.target)
                for c = 1:Objects.numel(input)
                    if input(c) == obj.target(nc + 1)
                        at = c;
                        obj.nCompleted = obj.nCompleted + 1;
                        nc = obj.nCompleted;
                        if nc == Objects.numel(obj.target)
                            obj.nCompleted = 0;
                            break;
                        end
                    else
                        at = 0;
                        nc = 0;
                        obj.nCompleted = 0;
                    end
                end
            end
        end
    end
end