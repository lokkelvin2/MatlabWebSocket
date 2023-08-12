% __________________________________________________________________
% Description: Tests for websocketserver constructors
%
% Author: lokkelvin2
% Created: 2023-08-11,    using Matlab 9.13.0.2166757 (R2022b) Update 4
% __________________________________________________________________
function morewstests()
    %MOREWSTESTS 
    %
    % Tests for websocketserver constructors
try
    PORT = 49158;
    s1 = EchoServer(PORT);
    PORT = 49159;
    s2 = EchoServer('localhost', PORT);
    PORT = 49160;
    s3 = EchoServer('LOCALHOST', PORT);
    PORT = 49161;
    s4 = EchoServer('0.0.0.0', PORT);

    s1.stop(); pause(0.1);
    s1.start(); pause(0.1);
    delete(s1);

    s2.stop(); pause(0.1);
    s2.start(); pause(0.1);
    delete(s2);

    s3.stop(); pause(0.1);
    s3.start(); pause(0.1);
    delete(s3);

    s4.stop(); pause(0.1);
    s4.start(); pause(0.1);
    delete(s4);
catch err
    delete(s1);
    delete(s2);
    delete(s3);
    delete(s4);
    rethrow(err);
end
end