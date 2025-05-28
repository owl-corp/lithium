Nonterminals
    record property_list property optional_semicolon value.

Terminals
    key equals semicolon string comma colon mailto.

Rootsymbol record.

record -> property_list optional_semicolon : '$1'.

optional_semicolon -> semicolon : [].
optional_semicolon -> '$empty' : [].

property_list -> property : ['$1'].
property_list -> property property_list : ['$1' | '$2'].

property -> key equals value semicolon : {value('$1'), process_value(value('$1'), value_to_list('$3'))}.
property -> key equals value : {value('$1'), process_value(value('$1'), value_to_list('$3'))}.

value -> mailto : '$1'.
value -> mailto comma value : join_values('$1', '$3').

value -> string : '$1'.
value -> string colon value : join_values('$1', '$3').

Expect 1.

Erlang code.

value({_, _, Value}) -> Value.

value_to_list(Value) when is_tuple(Value) ->
    [Value];
value_to_list(Values) when is_list(Values) ->
    Values.

join_values(First, Rest) when is_tuple(Rest) ->
    [First, Rest];
join_values(First, RestList) when is_list(RestList) ->
    [First | RestList].

process_value(Key, Values) when Key =:= rua; Key =:= ruf; Key =:= fo; Key =:= rf ->
    lists:map(fun value/1, Values);
process_value(_Key, [Value]) ->
    value(Value);
process_value(_Key, Values) ->
    [value(V) || V <- Values].
