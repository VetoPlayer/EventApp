-module(evsrv).
-compile(export_all).

%% The server needs to keep track of a list of clients and a list of events.
-record(state, {events, %% List of events
                clients}). %% List of clients (Pids)

-record(events,{name="",
                description="",
                pid,
                timeout}).


init() ->
    loop(#state{events=orddict:new(),
                clients=orddict:new()}).

%% Interface To the client

start() ->
    register(?MODULE,Pid=spawn(?MODULE,init,[])), %% Spawns the server and register it as evrsrv
    Pid. %% That's how you return things.

start_link() ->
    register(?MODULE, Pid = spawn_link(?MODULE,init,[])),
    Pid.

terminate() ->
    ?MODULE ! shutdown.

subscribe(Pid) ->
    Ref = monitor(process,whereis(?MODULE)),
    ?MODULE ! {self(), Ref, {subscribe,Pid}},
    receive
        {Ref,ok} -> 
            {ok,Ref};
        {'DOWN',Ref, process,_Pid,Reason} ->
            {error, Reason}
    after 5000 ->
        {error,timeout}
    end.



cancel(Name) ->
    Ref = make_ref(), %% Make a reference so that you'll be contacted next time.
    ?MODULE ! {self(),Ref,{cancel, Name}},
    receive %% Remember: you always filter out possible messages with Ref
        {Ref, ok} -> ok
    after 5000 ->
        {error,timeout}
    end.

add_event(Name, Description, Timeout) ->
    Ref = make_ref(),
    ?MODULE ! {self(), Ref, {add, Name, Description, Timeout}},
    receive
        {Ref, {error, Reason}} -> erlang:error(Reason);
        {Ref, Msg} -> Msg
    after 5000 ->
        {error, timeout}
    end.




loop(S= #state{}) ->
    receive
        {Pid, MsgRef, {subscribe, Client}} ->
            Ref = erlang:monitor(process,Client),
            NewClients = orddict:store(Ref,Client,S#state.clients), %%We store the client undern the key ref because when it dies that's how we remove it.
            Pid ! {MsgRef, ok},
            loop(S#state{clients=NewClients});
        {Pid, MsgRef, {add, Name, Description, Timeout}} ->
            %%Adds an event
            EventPid = event:start(Name,Timeout),
            NewEvents = orddict:store(Name,
                                    #events{name=Name,
                                    description=Description,
                                    pid=EventPid,
                                    timeout=Timeout},
                                S#state.events),
            Pid ! {MsgRef,ok},
            loop(S#state{events=NewEvents});
        {Pid, MsgRef, {cancel, Name}} ->
           Events = case orddict:find(Name,S#state.events) of
                            {ok,E} ->
                                event:cancel(E#events.pid),
                                orddict:erase(Name,S#state.events); 
                            error ->
                                S#state.events
                    end,
            Pid ! {MsgRef,ok},
            loop(S#state{events=Events});
        {done, Name} ->
            case orddict:find(Name,S#state.events) of
                {ok, E} ->
                    send_to_clients({done, E#events.name, E#events.description},
                                    S#state.clients),
                    NewEvents = orddict:erase(Name, S#state.events),
                    loop(S#state{events=NewEvents});
                error ->
                    loop(S)
                end;
        shutdown ->
            exit(shutdown);
       {'DOWN', Ref, process, _Pid, _Reason} ->
            loop(S#state{clients=orddict:erase(Ref, S#state.clients)});
%       code_change ->
%            ...
        Unknown ->
            io:format("Unknown message: ~p~n",[Unknown]),
            loop(S)
    end. 

send_to_clients(Msg, ClientDict) ->
    lists:map(fun(_Ref,Pid) -> Pid ! Msg end, ClientDict).
   
