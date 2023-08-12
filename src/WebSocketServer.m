classdef WebSocketServer < handle
    %WEBSOCKETSERVER WebSocketServer is an ABSTRACT class that allows 
    %MATLAB to start a java-websocket server instance. It then becomes 
    %possible to send messages to any client that connect to it.
    %
    %   In order to make a valid implementation of the class, some methods
    %   must be defined in the superclass:
    %    onOpen(obj,conn,message)
    %    onTextMessage(obj,conn,message)
    %    onBinaryMessage(obj,conn,bytearray)
    %    onError(obj,conn,message)
    %    onClose((obj,conn,message)
    %   The "callback" behaviour of the server can be defined there. If
    %   the server needs to perform actions that are not responses to a
    %   client-caused event, these actions must be performed outside of
    %   these callback methods.
    
    properties (SetAccess = private)
        Hostname = 'localhost' % Address of the WebSocket server
        Port % Server port
        Secure = false % True if the server is a secure websocket server
        Status = false % Server status
        Connections % Stores active connections' hash and address as well as their java websocket object
        ServerObj % Java-WebSocket server object
    end
    
    properties (Access = private)
        KeyStore % Location of the keystore
        StorePassword % Keystore password
        KeyPassword % Key password
    end
    
    methods
        function obj = WebSocketServer(varargin)
        % WEBSOCKETSERVER object
        %
        %   Creates a new WebSocketServer object.
        %
        %   Syntax:
        %       obj = WebSocketServer(varargin)
        %
        %   WebSocketServer(port)
        %   WebSocketServer(hostname,port)
        %   WebSocketServer(hostname,port,keyStore,storePassword,keyPassword)
            
            % Constructor
            if nargin == 1
                obj.Port = varargin{1};
            elseif nargin == 2
                obj.Hostname = varargin{1};
                obj.Port = varargin{2};
            elseif nargin == 5
                obj.Hostname = varargin{1};
                obj.Port = varargin{2};
                obj.Secure = true;
                obj.KeyStore = varargin{3};
                obj.StorePassword = varargin{4};
                obj.KeyPassword = varargin{5};
            else
                error('Invalid number of arguments!');
            end

            % Start server
            obj.start();
        end
        
        function start(obj)
            % Start the WebSocket server
            if obj.Status; error('The server is already running'); end
            import io.github.jebej.matlabwebsocket.*
            % Create the java server object in with specified port
            if obj.Secure
                obj.ServerObj = handle(MatlabWebSocketSSLServer(obj.Port,...
                    obj.KeyStore,obj.StorePassword,obj.KeyPassword),'CallbackProperties');
            else
                switch obj.Hostname
                    case {'localhost', 'LOCALHOST', '127.0.0.1'}
                        obj.ServerObj = handle(MatlabWebSocketServer(obj.Port),'CallbackProperties');
                    otherwise
                        obj.ServerObj = handle(MatlabWebSocketServer(obj.Hostname, obj.Port),'CallbackProperties');
                end        
            end
            % Set callbacks
            set(obj.ServerObj,'OpenCallback',@obj.openCallback);
            set(obj.ServerObj,'TextMessageCallback',@obj.textMessageCallback);
            set(obj.ServerObj,'BinaryMessageCallback',@obj.binaryMessageCallback);
            set(obj.ServerObj,'ErrorCallback',@obj.errorCallback);
            set(obj.ServerObj,'CloseCallback',@obj.closeCallback);
            % Start the server
            obj.ServerObj.start();
            obj.Status = true;
        end
        
        function stop(obj,timeout)
            % Stop the server with a timeout to close connections
            if ~obj.Status; error('The server is not running!'); end
            if nargin<2; timeout=5000; end
            obj.ServerObj.stop(int32(timeout));
            % Explicitely delete the server object
            delete(obj.ServerObj); obj.ServerObj=[];
            obj.Status = false;
        end
        
        function delete(obj)
            % Destructor
            if obj.Status
                % Stop the server if it is running
                obj.stop();
            end
        end
        
        function conns = get.Connections(obj)
            % Get current connections as a struct, listing HashCode, 
            % Address and Port, use the struct2table method on the returned
            % struct for a better display
            connArr = obj.ServerObj.connections.toArray;
            N = size(connArr,1);
            conns = cell(N,3);
            for n = 1:N
                conns{n,1} = int32(connArr(n).hashCode());
                conns{n,2} = char(connArr(n).getRemoteSocketAddress.getHostName());
                conns{n,3} = int32(connArr(n).getRemoteSocketAddress.getPort());
            end
            conns = cell2struct(conns,{'HashCode','Address','Port'},2);
        end
        
        function conn = getConnection(obj,hashCode)
            % Get a WebSocketConnection to the client identified by the
            % HashCode
            if ~obj.Status; error('The server is not running!'); end
            try
                conn = WebSocketConnection(obj.ServerObj.getConnection(hashCode));
            catch err
                error(char(err.ExceptionObject.getMessage));
            end
        end
        
        function sendTo(obj,hashCode,message)
            % Directly send a message to a particular client, as identified
            % by its HashCode
            if ~obj.Status; error('The server is not running!'); end
            if ~ischar(message) && ~isa(message,'int8') && ~isa(message,'uint8')
                error('You can only send character arrays or byte arrays!');
            end
            try
                obj.ServerObj.sendTo(hashCode,message);
            catch err
                error(char(err.ExceptionObject.getMessage));
            end
        end
        
        function sendToAll(obj,message)
            % Send a message to all connected clients
            if ~obj.Status; error('The server is not running!'); end
            if ~ischar(message) && ~isa(message,'int8') && ~isa(message,'uint8')
                error('You can only send character arrays or byte arrays!');
            end
            obj.ServerObj.sendToAll(message);
        end
        
        function close(obj,hashCode)
            % Directly close connection to a particular client, as 
            % identified by its HashCode
            if ~obj.Status; error('The server is not running!'); end
            try
                obj.ServerObj.close(hashCode);
            catch err
                error(char(err.ExceptionObject.getMessage));
            end
        end
        
        function closeAll(obj)
            % Close connection to all connected clients
            if ~obj.Status; error('The server is not running!'); end
            obj.ServerObj.closeAll();
        end
    end
    
    % Implement these methods in a subclass.
    methods (Abstract, Access = protected)
        onOpen(obj,conn,message)
        onTextMessage(obj,conn,message)
        onBinaryMessage(obj,conn,bytearray)
        onError(obj,conn,message)
        onClose(obj,conn,message)
    end
    
    % Private methods triggered by the callbacks defined above. This is
    % where the reactive behaviour of the server is defined.
    methods (Access = private)
        function openCallback(obj,~,e)
            % Define behavior in an onOpen method of a subclass
            obj.onOpen(WebSocketConnection(e.conn),char(e.message));
        end
        
        function textMessageCallback(obj,~,e)
            % Define behavior in an onTextMessage method of a subclass
            obj.onTextMessage(WebSocketConnection(e.conn),char(e.message));
        end
        
        function binaryMessageCallback(obj,~,e)
            % Define behavior in an onBinaryMessage method of a subclass
            obj.onBinaryMessage(WebSocketConnection(e.conn),e.blob.array);
        end
        
        function errorCallback(obj,~,e)
            % Define behavior in an onError method of a subclass
            obj.onError(WebSocketConnection(e.conn),char(e.message));
        end
        
        function closeCallback(obj,~,e)
            % Define behavior in an onClose method of a subclass
            obj.onClose(WebSocketConnection(e.conn),char(e.message));
        end
    end
end
