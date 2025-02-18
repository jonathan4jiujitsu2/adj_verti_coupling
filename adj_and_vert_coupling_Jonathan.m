%%          CALIFORNIA STATE UNIVERSITY, LOS ANGELES
%       DEPARTMENT OF ELECTRICAL ENGINEERING MASTER'S PROGRAM
% by Jonathan Martinez with the help of Cris 
%   This program fully opens the dampers to 90 degrees and continuously 
%   monitors and **plots in real-time**:
%   - Room temperatures (8 rooms)
%   - Duct temperatures (8 ducts)
%   - AC duct and ambient temperature
%   - Air velocity (8 locations)
%
%   Data updates dynamically instead of waiting for 90 minutes.

% this experinment is to primarily see adj, and vertical coupling

close all; clear all; clc;

%% Initialization
rho = 1.225; % Air density (kg/m^3)
vs = 5; % Reference velocity

% Connect to Arduino
a_servo = arduino('COM3', 'Mega2560'); % Arduino for servo control
a_vel = arduino('COM7', 'Mega2560');   % Arduino for velocity data

% Clear previous serial port connections
delete(instrfind({'Port'},{'COM5'}));

% Open serial port for LabVIEW data
se = serialport('COM5', 9600);
flush(se);

%% closed damper
open_angle = 0; % 90 degrees (fully open)
servos = [servo(a_servo, 'D11'), servo(a_servo, 'D10'), servo(a_servo, 'D9'), servo(a_servo, 'D8'), ...
          servo(a_servo, 'D14'), servo(a_servo, 'D15'), servo(a_servo, 'D16'), servo(a_servo, 'D17')];

for i = 1:8
    writePosition(servos(i), open_angle);
end

% Display servo positions
for i = 1:8
    current_pos = readPosition(servos(i)) * 180;
    fprintf('Current motor position %d is %d degrees (should be 90)\n', i, current_pos);
end

pause(1);

%% Initialize Real-Time Plots
figure;

% Room Temperatures
subplot(3,1,1);
hold on; grid on;
h1 = gobjects(1,8); % Preallocate an array of plot handles
for j = 1:8
    h1(j) = plot(nan, nan); % Create empty plots
end
title('Room Temperatures (Real-Time)'); xlabel('Time (min)'); ylabel('Temperature (°F)');
legend('TR1', 'TR2', 'TR3', 'TR4', 'BR1', 'BR2', 'BR3', 'BR4', 'Ambient', 'ACDUCT');

% Duct Temperatures
subplot(3,1,2);
hold on; grid on;
h2 = gobjects(1,8); % Preallocate an array of plot handles
for j = 1:8
    h2(j) = plot(nan, nan, 'b'); % Create empty plots
end
title('Duct Temperatures (Real-Time)'); xlabel('Time (min)'); ylabel('Temperature (°F)');
legend('TRD1', 'TRD2', 'TRD3', 'TRD4', 'BRD1', 'BRD2', 'BRD3', 'BRD4');

% Air Velocity
subplot(3,1,3);
hold on; grid on;
h3 = gobjects(1,8); % Preallocate an array of plot handles
for j = 1:8
    h3(j) = plot(nan, nan, 'r'); % Create empty plots
end
title('Air Velocity (Real-Time)'); xlabel('Time (min)'); ylabel('Velocity (m/s)');
legend('vel_TR1', 'vel_TR2', 'vel_TR3', 'vel_TR4', 'vel_BR1', 'vel_BR2', 'vel_BR3', 'vel_BR4');

%% Start Real-Time Monitoring
tic; i = 1;
templist = [];
velocity = [];

while toc <= 5400  % Run for 90 minutes
    rawData = readline(se); % Read from serial port
    data = str2num(rawData); % Convert to numeric values

    if length(data) >= 18
        elapsedTime(i) = toc / 60; % Convert time to minutes

        % Extract room and duct temperatures
        roomTemps = data(1:8);
        ductTemps = data(9:16);
        ACDUCT(i) = data(17);
        Ambient(i) = data(18);
        TR1(i) = data(1);
        TR2(i) = data(2);
        TR3(i) = data(3);
        TR4(i) = data(4);
        BR1(i) = data(5);
        BR2(i) = data(6);
        BR3(i) = data(7);
        BR4(i) = data(8);



        % Read velocity sensor data
        v_data = [readVoltage(a_vel, 'A1'), readVoltage(a_vel, 'A7'), readVoltage(a_vel, 'A9'), readVoltage(a_vel, 'A15'), ...
                  readVoltage(a_vel, 'A3'), readVoltage(a_vel, 'A5'), readVoltage(a_vel, 'A11'), readVoltage(a_vel, 'A12')];

        % Convert voltages to pressure & velocity
        P_data = 190 * v_data / vs - 38;

        % 🔹 **Prevent Negative Pressure for Velocity Calculation**
        vel_data = sqrt(max(0, (2 * P_data) / rho)); % **Fix applied here**

        % Store data
        templist = [templist; elapsedTime(i), roomTemps, ductTemps, ACDUCT(i), Ambient(i), TR1(i),TR2(i),TR3(i),TR4(i),BR1(i),BR2(i),BR3(i),BR4(i)];
        velocity = [velocity; elapsedTime(i), vel_data];

        % Update Room Temperatures Plot
        subplot(3,1,1);
        for j = 1:8
            set(h1(j), 'XData', templist(:,1), 'YData', templist(:, j+1));
        end
        title('Room Temperatures (Real-Time)');

        % Update Duct Temperatures Plot
        subplot(3,1,2);
        for j = 1:8
            set(h2(j), 'XData', templist(:,1), 'YData', templist(:, j+9));
        end
        title('Duct Temperatures (Real-Time)');

        % Update Air Velocity Plot
        subplot(3,1,3);
        for j = 1:8
            set(h3(j), 'XData', velocity(:,1), 'YData', velocity(:, j+1));
        end
        title('Air Velocity (Real-Time)');

        drawnow; % Refresh plots immediately
        i = i + 1;
    end

    pause(1);
end

%% Cleanup
clear a_servo a_vel servos;
