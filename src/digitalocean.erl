-module(digitalocean).
-author({ "David J Goehrig", "dave@dloh.org" }).
-copyright(<<"© 2017 David J Goehrig"/utf8>>).
-behavior(gen_server).
-export([ start_link/1, droplets/0, create_droplet/6, delete_droplet/1 ]).
-export([ init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3 ]).

-record(digitalocean, { token, droplets = [] }).

start_link(Token) ->
	{ ok, _ } =application:ensure_all_started(ssl),
	ok = application:ensure_started(inets),
	gen_server:start_link({local,?MODULE},?MODULE,[Token],[]).

droplets() ->
	proplists:get_value(<<"droplets">>,gen_server:call(?MODULE,droplets)).

create_droplet(Name,Region,Size,Image,Keys,Tags) ->
	proplists:get_value(<<"droplet">>,gen_server:call(?MODULE,{ 
		create_droplet,Name,Region,Size,Image,Keys,Tags
	})).

delete_droplet(Id) ->
	gen_server:call(?MODULE, {delete_droplet, Id }).

init([Token]) ->
	{ ok, #digitalocean{ token = Token } }.	

handle_call(droplets,_From,DigitalOcean = #digitalocean{ token = Token }) ->
	Droplets = get_request("droplets",Token),
	{ reply, Droplets, DigitalOcean#digitalocean { droplets = Droplets } };

handle_call({ create_droplet,Name,Region,Size,Image,Keys,Tags},_From,DigitalOcean = #digitalocean{ token = Token }) ->
	Droplet = post_request("droplets",Token, json:encode([
		{ <<"name">>, Name },
		{ <<"region">>, Region },
		{ <<"size">>, Size },
		{ <<"image">>, Image },
		{ <<"ssh_keys">>, Keys },
		{ <<"backups">>, false },
		{ <<"ipv6">>, false },
		{ <<"private_networking">>, null },
		{ <<"user_data">>, null },
		{ <<"monitoring">>, false },
		{ <<"volumes">>, null },
		{ <<"tags">>, Tags }
	])),
	{ reply, Droplet, DigitalOcean };

handle_call({ delete_droplet, Id }, _From, DigitalOcean = #digitalocean{ token = Token }) ->
	delete_request("droplets/" ++ Id,Token),
	{ reply, ok, DigitalOcean };

handle_call(Message,_From,DigitalOcean) ->
	error_logger:error_msg("Unknown message ~p~n", [ Message ]),
	{ reply, ok, DigitalOcean }.

handle_cast(Message,DigitalOcean) ->
	error_logger:error_msg("Unknown message ~p~n", [ Message ]),
	{ noreply, DigitalOcean }.

handle_info(Message,DigitalOcean) ->
	error_logger:error_msg("Unknown message ~p~n", [ Message ]),
	{ noreply, DigitalOcean }.


terminate(Reason,_DigialOcean) ->
	error_logger:info_msg("digital ocean shutting down ~p~n", [ Reason ]),
	ok.

code_change(_Old,_Extra,DigitalOcean ) ->
	{ ok, DigitalOcean }.


get_request(Path,Token) ->
	{ok, { _Status, _Headers, Body }} = httpc:request(get,{"https://api.digitalocean.com/v2/" ++ Path,[{"Authorization","Bearer " ++ Token }]},[],[]),
	json:decode(list_to_binary(Body)).

post_request(Path,Token,Data) ->
	{ok, { _Status, _Headers, Body }} = httpc:request(post,{"https://api.digitalocean.com/v2/" ++ Path,[{"Authorization","Bearer " ++ Token }],"application/json",Data},[],[]),
	json:decode(list_to_binary(Body)).

delete_request(Path,Token) ->
	{ok, { _Status, _Headers, _Body }} = httpc:request(delete,{"https://api.digitalocean.com/v2/" ++ Path,[{"Authorization","Bearer " ++ Token }]},[],[]).
