-module(event).
-compile(export_all).
%% Event with a state, describing how much time the function has to wait,
                              %% the event name that will trigger and
                              %% the server pid to send notifications to
-record(state, {server, %% Server PID
                name ="", %% Event Name
                to_go=0}). %% Event Time to wait

%% Start Function
start(EventName,Delay) ->
    spawn(?MODULE,init,[self(),EventName,Delay]).
    
start_link(EventName,Delay) ->
    spawn_link(?MODULE,init,[self(),EventName,Delay]).

%%Internal initialization function
init(ServerPid,EventName,Delay) ->
    loop(#state{server=ServerPid,name=EventName,to_go=Delay}).

%% Cancel message user API
cancel(Pid) ->
    %% Monitor in case the process is already dead
    Ref = erlang:monitor(process,Pid),
    Pid ! {self(), Ref, cancel},
    receive
        {Ref,ok} -> %%Expected case
            erlang:demonitor(Ref,[flush]),
            io:format("Canceled Successfully"),
            ok;
        {'DOWN',Ref,process,Pid,_Reason} -> %%The process is already dead
            ok
    end.


%% Loop function with State. This is the function keeping track of the time
loop(S=#state{server=ServerPid}) ->
    receive
        {ServerPid, Ref, cancel} -> %%Cancel Message
            ServerPid ! {Ref,ok}
    after S#state.to_go*1000 -> %% Wait feature, after this the server is notified with a done message
        io:format("Finished ~n"),
        ServerPid ! {done, S#state.name}
    end.
