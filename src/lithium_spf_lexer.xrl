% SPDX-FileCopyrightText: 2025 Johannes Christ
% SPDX-License-Identifier: AGPL-3.0-or-later

Definitions.

ALPHA = [a-zA-Z]
WHITESPACE = \s
% 4.6.1
QUALIFIER = \+|-|\?|~
% TODO: technically macro spec
DOMAIN_SPEC = [^\s]+

QNUM = ([0-9]|([1-9][0-9])|(1[0-9][0-9])|(2[0-4][0-9])|(25[0-5]))
IP4_NETWORK = {QNUM}\.{QNUM}\.{QNUM}\.{QNUM}
IP4_CIDR_LENGTH = /([0-9]|([1-2][0-9])|(3[0-2]))
% XXX: the following causes "cannot match because a previous clause always matches"
% maybe consider unifying these two cidr lengths
IP6_CIDR_LENGTH = /[0-9]|([1-9][0-9])|(1[0-1][0-9])|(12[0-8])
% parsing is done by erlang, I'm not writing a regex for that
IP6_NETWORK = [a-zA-Z0-9:]+
MECHANISM_WITH_IP4_NET = ip4:{IP4_NETWORK}({IP4_CIDR_LENGTH})?
MECHANISM_WITH_IP6_NET = ip6:{IP6_NETWORK}({IP6_CIDR_LENGTH})?
MECHANISM_NETWORK = {MECHANISM_WITH_IP4_NET}|{MECHANISM_WITH_IP6_NET}
MECHANISM_WITH_OPTIONAL_DOMAIN = ptr(:{DOMAIN_SPEC})?
MECHANISM_WITH_MANDATORY_DOMAIN = (exists|redirect|include):{DOMAIN_SPEC}
MECHANISM_WITH_DOMAIN_AND_CIDR = (a|mx)(:{DOMAIN_SPEC}({DUAL_CIDR_LENGTH})?)?
MECHANISM_DOMAIN = {MECHANISM_WITH_MANDATORY_DOMAIN}|{MECHANISM_WITH_OPTIONAL_DOMAIN}|{MECHANISM_WITH_DOMAIN_AND_CIDR}
MECHANISM = (all|{MECHANISM_NETWORK}|{MECHANISM_DOMAIN})
MECHANISM_TRAILER = :|/
NAME = [a-zA-Z][a-zA-Z0-9_.-]*
KNOWN_MODIFIER = (exp|redirect)={DOMAIN_SPEC}
UNKNOWN_MODIFIER = {NAME}={DOMAIN_SPEC}
MACRO_STRING = {DOMAIN_SPEC}

% TODO: 4.6.1: mechanism and modifier names are case-insensitive - WHAT THE FUCK!

Rules.

({QUALIFIER})?{MECHANISM} : {token, {directive, mechanism(TokenChars)}}.
% {QUALIFIER}?{MECHANISM} : {token, {directive, mechanism(TokenChars)}}.
{KNOWN_MODIFIER} : {token, {modifier, modifier(TokenChars)}}.
% {MECHANISM} : {token, {mechanism, TokenChars}}.
% {NAME} : {token, {name, TokenChars}}.
% = : {token, equal}.
{WHITESPACE}+ : skip_token.
% where "name" is not any known modifier
{UNKNOWN_MODIFIER} : {token, {unknown_modifier, modifier(TokenChars)}}.


Erlang code.

split_by(Value, Char) ->
    [Head | Tail] = string:split(Value, Char),
    case Tail of
        "" -> {Head, ""};
        Rest -> {Head, lists:flatten(lists:join(Char, Rest))}
    end.

split_name(Value) -> split_by(Value, ":").

split_domain_spec(Value) ->
    [Head | Tail] = string:split(Value, ":"),
    {Head, lists:join(Tail, ":")}.

parse_ip_maybe_cidr(Value) ->
    case string:split(Value, "/") of
        [IP, RawMask] ->
            {ok, Address} = inet:parse_address(IP),
            {Mask, []} = string:to_integer(RawMask),
            {Address, Mask};
        [IP] ->
            {ok, Address} = inet:parse_address(IP),
            Address
    end.

parse_mechanism("ip4:" ++ Ip4MaybeCidr) -> parse_ip_maybe_cidr(Ip4MaybeCidr);
parse_mechanism("ip6:" ++ Ip6MaybeCidr) -> parse_ip_maybe_cidr(Ip6MaybeCidr);
parse_mechanism(Value) -> split_by(Value, ":").

% 4.6.2
mechanism("+" ++ Value) -> {pass, parse_mechanism(Value)};
mechanism("-" ++ Value) -> {fail, parse_mechanism(Value)};
mechanism("~" ++ Value) -> {softfail, parse_mechanism(Value)};
mechanism("?" ++ Value) -> {neutral, parse_mechanism(Value)};
mechanism(Value) -> {pass, parse_mechanism(Value)}.

modifier(Value) -> split_by(Value, "=").


% vim: ft=erlang:
