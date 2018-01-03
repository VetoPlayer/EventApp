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



loop(S= #state{}) ->
    receive
        {Pid, MsgRef, {subscribe, Client}} ->
            Ref = erlang:monitor(process,Client),
            NewClients = orddict:store(Ref,Client,S#state.clients), %%We store the client undern the key ref because when it dies that's how we remove it.
            Pid ! {MsgRef, ok},
            loop(S#state={clients=NewClients});
        {Pid, MsgRef, {add, Name, Description, Timeout}} ->
            ...
        {Pid, MsgRef, {cancel, Name}} ->
            ...
        {done, Name} ->
            ...
        shutdown ->
            ...
        {'DOWN', Ref, process, _Pid, _Reason} ->
            ...
        code_change ->
            ...
        Unknown ->
            io:format("Unknown message: ~p~n",[Unknown]),
            loop(State)
    end. 

   
