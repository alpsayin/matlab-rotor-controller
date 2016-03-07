classdef AntennaRotor < handle
%     AntennaRotor a handle class for controlling the antenna rotator
% 
%       Author:     Alp Sayin
%       Date:       11.03.2014
% 
%       type ' help AntennaRotor.`function_name` ' for detailed function docs
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
		NUM_POLLS_PER_SECOND = 10;
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
		gearboxratio = 1;
        connected = 0;
    end
    methods
        function obj = AntennaRotor(portName, baudrate)
        %   AntennaRotor(portName, baudrate)    
        %   class constructor
        %	params: 
        %       portname: 'COM4', '/dev/ttyUSB0'
        %       baudrate: 9600
            if nargin > 0
                obj.portname = portName;
            end
            if nargin > 1
                obj.baudrate = baudrate;
            end
        end
        function delete(obj)
        % class destructor
        % makes sure port is closed
            try
                obj.close();
            catch err
                disp(err)
            end
        end
        function defaultSetup(obj)
        %   defaultSetup()
        %       setups some default parameters to controller
        %           velocity: 10
        %           acceleration: 10
        %           degrees_per_step: 10
        %           direction: clockwise
            obj.setVelocity(10);
            obj.setAcceleration(10);
            obj.setDegreesPerStep(10);
            obj.setCW();
        end
        function disableSafetyLimits(obj)
        %   disableSafetyLimits()
        %       disables the safety limits of controller
            obj.safetylimits = 0;
            obj.println('%dLD3', obj.controlleraddress);
        end
        function enableSafetyLimits(obj)
        %   enableSafetyLimits()
        %      enables the safety limits of controller
            obj.println('%dLD0', obj.controlleraddress);
            obj.safetylimits = 1;
        end
        function posnum = getAbsolutePosition(obj)
        %   getAbsolutePosition()
        %       returns the absolute position of rotator
        %       absolute position is not necessarily the home position
        %       it is just the encoder count
            flushinput(obj.comportObj);
            obj.println('%dPR', obj.controlleraddress);
			obj.requestLineFeed();
            pos = obj.scanf();
            posnum = str2double(pos(2:end))/(obj.DEGREES_PER_MOTOR_REV*obj.gearboxratio);
        end
        function resetPosition(obj)
        %   resetPosition()
        %       sets the current encoder position as zero
            obj.println('%dPZ', obj.controlleraddress);
        end
        function resetSystem(obj)
        %   resetSystem()
        %       resets all the setup to controller defaults
        %       doesn't really help with anything
            obj.println('%dZ', obj.controlleraddress);
            pause(AntennaRotor.RESET_DELAY);
        end
        function setDegreesPerStep(obj, degrees_per_step)
        %   setDegreesPerStep(degrees_per_step)
        %       sets how much degrees should antenna rotate when
        %       stepper is activated.
            obj.degrees_per_step = degrees_per_step;
            obj.println('D%d', obj.degrees_per_step*(obj.DEGREES_PER_MOTOR_REV*obj.gearboxratio));
        end
        function setDirection(obj, direction)
        %   setDirection(direction)
        %       sets the direction to either 'cw' for clockwise
        %       or 'ccw' for counter-clockwise
            if strcmpi(direction,'cw')
                obj.setCW();
            else
                obj.setCCW();
            end
        end
        function setCW(obj)
        %   setCW()
        %       short-hand function for setting the direction to clockwise
            obj.direction = 'cw';
            obj.println('H+');
        end
        function setCCW(obj)
        %   setCCW()
        %       short-hand function for setting the direction to
        %       counter-clockwise
            obj.direction = 'ccw';
            obj.println('H-');
        end
        function activateStep(obj)
        %   activateStep()
        %       probably the most important function; activates and therefore
        %       moves the rotator for one step. Note that this function
        %       immediately returns after sending the command
            obj.println('G');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
            end
        end
        function activateStepAndWaitEstimatedTime(obj)
        %   activateStepAndWait()
        %       activates and therefore moves the rotator for one step. 
        %       Note that this function immediately returns after sending 
        %       the command
            obj.println('G');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
            end
            delay = obj.degrees_per_step/obj.velocity;
            pause(delay)
        end
        function activateStepAndWaitUntil(obj)
        %   activateStepAndWait()
        %       activates and therefore moves the rotator for one step. 
        %       Note that this function immediately returns after sending 
        %       the command
			initialAddress = obj.getAbsolutePosition();
            obj.println('G');
            if strcmpi(obj.direction, 'cw')
                obj.current_angle = obj.current_angle + obj.degrees_per_step;
				nextAddress = initialAddress + obj.degrees_per_step
            else
                obj.current_angle = obj.current_angle - obj.degrees_per_step;
				nextAddress = initialAddress - obj.degrees_per_step
            end
			while obj.getAbsolutePosition() ~= nextAddress
				pause(1.0/obj.NUM_POLLS_PER_SECOND)
        end
        function goToHome(obj)
        %   goToHome()
        %       sends a command to controller to go to 'home', wherever that is
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
        %   emergencyStop()
        %       sends an immediate emergency kill command to controller
        %       DON'T USE IT UNLESS ALL ELSE FAILS
            obj.println('MN')
            obj.println('K')
        end
        function stop(obj)
        %   stop()
        %       sends a stop command to controller which causes the motor
        %       to stop gracefully
            obj.println('MN')
            obj.println('S')
        end
        function setControllerAddress(obj, address)
        %   setControllerAddress(address)
        %       sets the current controller address for sending commands
        %       only useful if there are more than one motors to control
            obj.controlleraddress = address;
        end
        function setGearboxRatio(obj, gear_box_ratio)
        %   setGearboxRatio(gear_box_ratio)
        %       sets the gear_box_ratio of the stepper, the parameter is a
		% 		ratio between 0 and 1.0. The default value is 1.0, but if 
		%		this class is to be used with different gearboxes, it can
		%		be changed to numbers like 0.5;
			if(gear_box_ratio > 0 && gear_box_ratio <= 1.0)
				obj.gearboxratio = gear_box_ratio;
        end
        function setVelocity(obj, revs_per_sec)
        %   setVelocity(revs_per_sec)
        %       sets the velocity of the stepper, the parameter is revolutions
        %       per second. Degrees per revolution is defined as a constant in
        %       this class as: 
        %           AntennaRotor.DEGREES_PER_MOTOR_REV
            obj.velocity = revs_per_sec;
            obj.println('V%d', obj.velocity);
        end
        function setAcceleration(obj, revs_per_sec_sq)
        %   setAcceleration(revs_per_sec_sq)
        %       sets the acceleration of the stepper, the parameter is
        %       revolutions per second squared. Degrees per revolution is
        %       defined as a constant in this class as 
        %           AntennaRotor.DEGREES_PER_MOTOR_REV
            obj.acceleration = revs_per_sec_sq;
            obj.println('A%d', obj.acceleration);
        end
		function setEchoMode(echo_mode_on)
		%   setEchoMode()
        %       Sets the echo mode of the controller. This class is not designed
        %       to handle echoes from issued commands, therefore If echo mode is
        %       to be turned on, it should be turned off after debugging.
			if echo_mode_on
				obj.println('%dSSA0', obj.controlleraddress);
			else
				obj.println('%dSSA1', obj.controlleraddress);
		end
		function requestLineFeed()
		%   requestLineFeed()
        %       Sets the echo mode of the controller. This class is not designed
        %       to handle echoes from issued commands, therefore If echo mode is
        %       to be turned on, it should be turned off after debugging.
			obj.println('%dLF', obj.controlleraddress);
		end
        function openFile(obj)
        %   openFile()
        %       debug method to test the protocol with files, shouldn't be used
        %       for production. AGAIN, DO NOT USE!
            obj.comportObj = fopen(obj.portname,'a');
        end
        function openPort(obj)
        %   openPort()
        %       opens the communications channel with the controller box. any
        %       other commands (functions) will NOT work if you do not open the
        %       port first. And most importantly, do not ever forget to close
        %       the port after you are done with it. See close() function.
            obj.comportObj = serial(obj.portname,'BaudRate',obj.baudrate,'DataBits',8);
            fopen(obj.comportObj);
            obj.connected = 1;
        end
        function close(obj)
        %   close()
        %       closes the communications channel with the controller box. It
        %       releases the system's handle to it so that other applications
        %       or other AntenntaRotor objects can open it and use it.
            fclose(obj.comportObj);
            obj.connected = 0;
        end
        function response = query(obj, queryStr)
        %   response = query(queryStr)
        %       a simple debug function to query the controller box with a
        %       query string and get a response. The function also asks for
		%		a line feed from the controller, so scanf can be triggered.
			obj.println(queryStr);
			obj.println('%dLF', obj.controlleraddress);
            response = obj.scanf();
        end
        function response = rawquery(obj, queryStr)
        %   response = rawquery(queryStr)
        %       a simple debug function to query the controller box with a
        %       raw query string and get a response. Note that this function
		%		does not ask for a line feed from controller, so the response
		% 		might arrive due to a read timeout.
            response = query(obj.comportObj, queryStr);
        end
        function printf(varargin)
        %   printf(format_string, args)
        %       a simple printf function to send formatted strings to the comms
        %       channel
        %   see fprintf help for more information
            obj = varargin{1};
            fprintf(obj.comportObj, varargin{2:end});
        end
        function println(varargin)
        %   println(format_string, args)
        %       almost the same function as printf. this function sends the
        %       formatted strings with a carriage return and new line character
        %       in the end
        %       see fprintf help for more information
            obj = varargin{1};
            str = sprintf(varargin{2:end});
            fprintf(obj.comportObj, [str char(13) char(10)]);
            fprintf([str char(13) char(10)]);
        end
        function response = scanf(obj)
        %   response = scanf()
        %       a simple debug function to collect a response without sending
        %       anything from the comms channel
            response = fscanf(obj.comportObj);
        end
        function rotateCW(obj, degrees)
        %   rotateCW(degrees)
        %       easy shortcut member function to simply rotate antenna to a clockwise
        %       direction for specified number of degrees. the parameter is a
        %       number that defines degrees.
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
        %   rotateCCW(degrees)
        %       easy shortcut member function to simply rotate antenna to a 
        %       counter-clockwise direction for specified number of degrees.
        %       the parameter is a number that defines degrees.
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
        %   AntennaRotor.rotateCW(degrees)
        %       STATIC shortcut function to simply rotate antenna to a clockwise
        %       direction for specified number of degrees. the parameter is a
        %       number that defines degrees.
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
        %   AntennaRotor.rotateCW(degrees)
        %       STATIC shortcut function to simply rotate antenna to a 
        %       counter-clockwise direction for specified number of degrees.
        %       the parameter is a number that defines degrees.
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

