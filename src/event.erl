-module(event).
-compile(export_all).
%% Event with a state, describing how much time the function has to wait,
                              %% the event name that will trigger and
                              %% the server pid to send notifications to
-record(state, {server, %% Server PID
                name ="", %% Server Name
                to_go=0}). %% Specifies how much you do want to wait. It should be initialized > 0

%% Start Function
start(EventName,Delay) ->
    spawn(?MODULE,init,[self(),EventName,Delay]).
    
start_link() ->
    spawn_link(?MODULE,init,[self(),EventName,Delay]).

%%Internal initialization function
init(Server,EventName,Delay) ->
    loop(#state{server=Server,name=EventName,to_go=Delay}).

%% Cancel message user API
cancel(Pid) ->
    %% Monitor in case the process is already dead
    Pid ! {self(),Ref, cancel},
    receive
        {Ref,ok} ->
            erlang:demonitor(ref,[flush]),
            ok;
        {'DOWN',Ref,process,Pid,_Reason} ->
            ok
    end.


%% Loop function with State. This is the function keeping track of the time
loop(S=#state{server=Server}) ->
    receive
        {Server,Ref, cancel} -> %%Cancel Message
            Server ! {Ref,ok}
    after S#state.to_go*1000 ->
        Server ! {done, S#state.name}
    end.
