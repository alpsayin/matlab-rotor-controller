classdef AntennaRotor < handle
%     AntennaRotor a handle class for controlling the antenna rotator
% 
%       Author:     Alp Sayin
%       Date:       11.03.2014
% 
%       Example:
%           ar = AntennaRotor('COM1', 9600);
%           ar.openPort();     
%           ar.resetSystem();
%           ar.defaultSetup();
%           ar.disableSafetyLimits();
%           ar.setDegreesPerStep(2);
%           ar.setDirection('ccw');
%           ar.activateStep();
%           ar.close(); % never forget to close the port after you are done
%       
%       Example:
%           AntennaRotor.easyRotateCCW('COM4',30) % portname and degrees
%           AntennaRotor.easyRotateCW('COM4',30) % portname and degrees
% 
%       Constructors:
%                 obj = AntennaRotor(portName)
%                 obj = AntennaRotor(portName, baudrate)
% 
%       Functions:
%                 defaultSetup()
%                 disableSafetyLimits()
%                 enableSafetyLimits()
%                 resetSystem()
%                 setDegreesPerStep(degrees_per_step)
%                 setDirection(direction)
%                 setCW()
%                 setCCW()
%                 activateStep()
%                 activateStepAndWait()
%                 goToZero()
%                 setControllerAddress(address)
%                 setVelocity( revs_per_sec )
%                 setAcceleration( revs_per_sec_sq )
%                 emergencyStop()
%                 rotateCW()
%                 rotateCCW()
%                 openFile()
%                 openPort()
%                 close()
%                 response = query(queryStr)
%                 printf(varargin)
%                 println(str)
%                 response = scanf()
% 
    properties(Constant)
        DEGREES_PER_MOTOR_REV = 1000;
        RESET_DELAY = 2.5;
        COMMAND_DELAY = 0.2;
    end
    properties(SetAccess = protected)
        degrees_per_step = 1;
        direction = 'cw'; % cw or ccw
        portname = 'COM1'; % port name can be different for unix systems (e.g. /dev/ttyUSB0)
        baudrate = 9600;
        comportObj; %variable to hold serial port object
        safetylimits = 1; %variable to hold the current state if safety limits enabled
        controlleraddress = 2; % got no idea what this address refers to (taken directly from original program)
        current_angle = 0; % current direction of the antenna
        acceleration = 1;
        velocity = 1;
        connected = 0;
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
        function delete(obj)
            obj.close();
        end
        function defaultSetup(obj)
            obj.setVelocity(10);
            obj.setAcceleration(10);
            obj.setDegreesPerStep(10);
            obj.setCW();
        end
        function disableSafetyLimits(obj)
            obj.safetylimits = 0;
            obj.println('%dLD3', obj.controlleraddress);
        end
        function enableSafetyLimits(obj)
            obj.println('%dLD0', obj.controlleraddress);
            obj.safetylimits = 1;
        end
        function pos = getAbsolutePosition(obj)
            flushinput(obj.comportObj);
            obj.println('%dPR', obj.controlleraddress);
            pos = obj.scanf();
        end
        function resetPosition(obj)
            obj.println('%dPZ', obj.controlleraddress);
        end
        function resetSystem(obj)
            obj.println('%dZ', obj.controlleraddress);
            pause(AntennaRotor.RESET_DELAY);
        end
        function setDegreesPerStep(obj, degrees_per_step)
            obj.degrees_per_step = degrees_per_step;
            obj.println('D%d', obj.degrees_per_step*obj.DEGREES_PER_MOTOR_REV);
        end
        function setDirection(obj, direction)
            if strcmpi(direction,'cw')
                obj.setCW();
            else
                obj.setCCW();
            end
        end
        function setCW(obj)
            obj.direction = 'cw';
            obj.println('H+');
        end
        function setCCW(obj)
            obj.direction = 'ccw';
            obj.println('H-');
        end
        function activateStep(obj)
            obj.println('G');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
            end
        end
        function activateStepAndWait(obj)
            obj.println('G');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
            end
            delay = obj.degrees_per_step/obj.velocity;
            pause(delay)
        end
        function goToHome(obj)
            if strcmpi(obj.direction, 'cw')
                obj.setCCW();
            else
                obj.setCW();
            end
            obj.disableSafetyLimits();
            obj.println('GH-2');
            obj.current_angle = 0;
        end
        function emergencyStop(obj)
            obj.println('MN')
            obj.println('K')
        end
        function setControllerAddress(obj, address)
            obj.controlleraddress = address;
        end
        function setVelocity(obj, revs_per_sec)
            obj.velocity = revs_per_sec;
            obj.println('V%d', obj.velocity);
        end
        function setAcceleration(obj, revs_per_sec_sq)
            obj.acceleration = revs_per_sec_sq;
            obj.println('A%d', obj.acceleration);
        end
        function openFile(obj)
        % debug method to test the protocol with files, shouldn't be used
        % for production
            obj.comportObj = fopen(obj.portname,'a');
        end
        function openPort(obj)
            obj.comportObj = serial(obj.portname,'BaudRate',obj.baudrate,'DataBits',8);
            fopen(obj.comportObj);
            obj.connected = 1;
        end
        function close(obj)
            fclose(obj.comportObj);
            obj.connected = 0;
        end
        function response = query(obj, queryStr)
            response = query(obj.comportObj, queryStr);
        end
        function printf(varargin)
            obj = varargin{1};
            fprintf(obj.comportObj, varargin{2:end});
        end
        function println(varargin)
            obj = varargin{1};
            str = sprintf(varargin{2:end});
            fprintf(obj.comportObj, [str char(13) char(10)]);
            fprintf([str char(13) char(10)]);
        end
        function response = scanf(obj)
            response = fscanf(obj.comportObj);
        end
        function rotateCW(obj, degrees)
            obj.defaultSetup();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setDegreesPerStep(degrees);
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setCW();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.disableSafetyLimits();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.activateStep();
        end
        function rotateCCW(obj, degrees)
            obj.defaultSetup();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setDegreesPerStep(degrees);
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setCCW();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.disableSafetyLimits();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.activateStep();
        end
    end
    methods(Static)
        function easyRotateCW( portname, degrees)
            obj = AntennaRotor(portname);
            obj.openPort();
            
            obj.defaultSetup();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setDegreesPerStep(degrees);
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setCW();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.disableSafetyLimits();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.activateStepAndWait();
            
            obj.close();
        end
        function easyRotateCCW( portname, degrees)
            obj = AntennaRotor(portname);
            obj.openPort();
            
            obj.defaultSetup();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setDegreesPerStep(degrees);
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.setCCW();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.disableSafetyLimits();
            pause(AntennaRotor.COMMAND_DELAY)
            
            obj.activateStepAndWait();
            
            obj.close();
        end
    end
end

