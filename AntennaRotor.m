classdef AntennaRotor < handle
%     AntennaRotor a handle class for controlling the antenna rotator
%       Example:
%           ar = AntennaRotor('COM1', 9600);
%           ar.openPort();     
%           ar.setDegreesPerStep(2);
%           ar.setDirection('cw');
%           ar.executeStep();
%           ar.close();
%       Constructors:
%                 obj = AntennaRotor(portName)
%                 obj = AntennaRotor(portName, baudrate)
%       Functions:
%                 setControllerAddress(address)
%                 setup()
%                 disableSafetyLimits()
%                 enableSafetyLimits()
%                 resetSystem()
%                 setDegreesPerStep(degrees_per_step)
%                 setDirection(direction)
%                 activateStep()
%                 goToZero()
%                 emergencyStop()
%                 openFile()
%                 openPort()
%                 close()
%                 response = query(queryStr)
%                 printf(varargin)
%                 response = scanf()
    properties(Constant)
        PAUSE_TIME_FOR_STEP_MS = 100;
    end
    properties(SetAccess = protected)
        degrees_per_step = 1;
        direction = 'cw';
        portname = 'COM1';
        baudrate = 9600;
        comportObj;
        safetylimits = 1;
        controlleraddress = 0;
    end
    properties(SetAccess = public)
        current_angle = 0;
    end
    
    methods
        function obj = AntennaRotor(portName, baudrate)
        % class constructor
            if nargin > 0
                obj.portname = portName;
            end
            if nargin > 1
                obj.baudrate = baudrate;
            end
        end
        function setControllerAddress(obj, address)
            obj.controllerAddress = address;
        end
        function setup(obj)
            obj.printf('A10\r\n');
            obj.printf('V10\r\n');
            obj.printf('D10000\r\n');
            obj.printf('H-\r\n');
        end
        function disableSafetyLimits(obj)
            obj.safetylimits = 0;
            obj.printf('%dLD3\r\n');
        end
        function enableSafetyLimits(obj)
            obj.printf('%dLD0\r\n', obj.controlleraddress);
            obj.safetylimits = 1;
        end
        function resetSystem(obj)
            obj.printf('%dZ\r\n', obj.controlleraddress);
        end
        function setDegreesPerStep(obj, degrees_per_step)
            obj.degrees_per_step = degrees_per_step;
            obj.printf('D%d\r\n', obj.degrees_per_step*1000);
        end
        function setDirection(obj, direction)
            if strcmpi(direction,'cw')
                obj.direction = 'cw';
                obj.printf('H+\r\n');
            else
                obj.direction = 'ccw';
                obj.printf('H-\r\n');
            end
        end
        function activateStep(obj)
            obj.printf('G\r\n');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
            end
            pause(PAUSE_TIME_FOR_STEP/1000*obj.degrees_per_step)
        end
        function goToZero(obj)
            obj.printf('H-\r\n');
            obj.printf('%dLD0\r\n', obj.controlleraddress);
            obj.printf('GH-2\r\n');
            obj.current_angle = 0;
        end
        function emergencyStop(obj)
            obj.printf('MN\r\n')
            obj.printf('K\r\n')
        end
        function openFile(obj)
            obj.comportObj = fopen(obj.portname,'a');
        end
        function openPort(obj)
            obj.comportObj = serial(obj.portname,'BaudRate',obj.baudrate,'DataBits',8);
            fopen(obj.comportObj);
        end
        function close(obj)
            fclose(obj.comportObj);
        end
        function response = query(obj, queryStr)
            response = query(obj.comportObj, queryStr);
        end
        function printf(varargin)
            obj = varargin{1};
            fprintf(obj.comportObj, varargin{2:end});
        end
        function response = scanf(obj)
            response = fscanf(obj.comportObj);
        end

    end
    
end

