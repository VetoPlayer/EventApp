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
init(Server,EventName,Delay) ->
    loop(#state{server=Server,name=EventName,to_go=Delay}).

%% Cancel message user API
cancel(Pid) ->
    %% Monitor in case the process is already dead
    Ref = erlang:monitor(process,Pid),
    Pid ! {self(), Ref, cancel},
    receive
        {Ref,ok} ->
            erlang:demonitor(Ref,[flush]),
            ok;
        {'DOWN',Ref,process,Pid,_Reason} ->
            ok
    end.


%% Loop function with State. This is the function keeping track of the time
loop(S=#state{server=Server}) ->
    receive
        {Server, Ref, cancel} -> %%Cancel Message
            Server ! {Ref,ok}
    after S#state.to_go*1000 -> %% Wait feature, after this the server is notified with a done message
        Server ! {done, S#state.name}
    end.
