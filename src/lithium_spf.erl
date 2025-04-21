% SPDX-FileCopyrightText: 2025 Johannes Christ
% SPDX-License-Identifier: AGPL-3.0-or-later
-module(lithium_spf).

-feature(maybe_expr, enable).

-export([check_host/3]).
-export_type([check_result/0]).


% 2.3 RECOMMENDED not only to check MAIL FROM but also HELO as "sender" param.
% 2.3 RECOMMENDED to check HELO before MAIL FROM.
% 2.4 MUST check "MAIL FROM" if: 1. "HELO" has not been checked, or 2. did not reach a definitive policy result
% 2.4 if reverse-path is null, "MAIL FROM" shoudl be the mailbox of the local-part postmaster & the HELO identity
% 2.5 SHOULD be checked during processing. reason: backscatter with forged senders (non-delivery notification)
% 2.6 POSSIBLE RESULTS.
% 2.6.1 "none": no valid DNS domain name was extracted, or no SPF records were retrieved
% 2.6.2 "neutral": ADMD has explicitly stated it is not asserting whether the IP is authorized
% 2.6.3 "pass": client is authorized
% 2.6.4 "fail": explicit statement that the client is not authorized
% 2.6.5 "softfail": weak statement, probably not authorized
% 2.6.6: "temperror": temporary error
% 2.6.7: "permerror": bad records of the domain
% 3. multiple records are NOT permitted
% 3. take care only to use SPF records for SPF processing
% 3.1: MUST be published as TXT RR. no other RR types.
% LOL: "SPF's use of the TXT RR type for structured data should in no way be taken as precedent for future protocol designers."
% 3.2: MUST NOT have multiple records, see 4.5
% 3.3: MUST concatenate records composed of more than one string
% 3.4: (SHOULD have < 450 octets in a record)
% 3.5: wildcard TXTs MUST be repeated for any host that has any RR records at all
% 4.1 "domain" argument may not be well-formed
% 4.1: if EHLO/HELO domain is used since reverse-path is null, "none" should be returned
% 4.6.4: MUST return permerror after 10 DNS queries
% 4.6.4: MUST return permerror for > 10 A or AAAA records on MX
% 4.6.4: MUST ignore more than the first 10 records for > 10 A or AAAA records on PTR (ptr mechanism or %{p} macro)
% 4.6.4: SHOULD impose limit for check_host of at least 20 seconds, otherwise temperror
% 4.7: return "neutral" if no mechanisms match and no "redirect" modifier exists
% 4.8: if domain argument is used, and domain is not specified, use domain from argument
% 5: with a sender mechanism, if no CIDR prefix length is given in the directive, then the IP in the DNS record and the IP in check_host are compared for equality
% 5.1: stop processing at "all"
% 5.1: MUST ignore any "redirect" modifier when there is "all" in the record, regardless of order
% 5.2: `include` must call `check_host` with resulting domain as `domain`. see 5.2 for return results

-type spf_result() :: none | neutral | pass | fail | softfail | temperror | permerror.
-type reason() :: {invalid_domain, not_multi_label | label_empty | label_too_long}
                  | {dns_error, nxdomain | formerr | servfail | timeout}
                  | {bad_spf, no_spf_records | {more_than_one_spf_record, nonempty_list(string())}}.
-type check_result() :: {spf_result(), nonempty_list(reason())}.

-spec check_host(inet:ip_address(), binary(), binary()) -> check_result().
check_host(IP, Domain, Sender) ->
    maybe
        {valid_domain, true} ?= {valid_domain, is_valid_domain(Domain)},
        {txt_records, [_ | _] = TXTRecords} ?= {txt_records, txt_records(Domain)},
        {spf_records, [_] = SPFRecords} ?= {spf_records, find_spf_records(TXTRecords)},
        [SPFRecord] = SPFRecords,
        begin
            pass
        end
    else
        % 4.3: If the <domain> is malformed (...) immediately returns the result "none"
        {valid_domain, {false, Why}} ->
            {none, [{invalid_domain, Why}]};
        % 4.3: , or if the DNS lookup returns "Name Error"
        {txt_records, {error, nxdomain = Reason}} ->
            {none, [{dns_error, Reason}]};
        % 4.4: if the DNS lookup returns a server failure (RCODE 2) or some
        % other error (RCODE other than 0 or 3), or if the lookup times out,
        % then check_host terminates immediately with the result "temperror".
        {txt_records, {error, Reason}} when Reason == formerr;
                                            Reason == servfail;
                                            Reason == timeout ->
            {temperror, [{dns_error, Reason}]};
        % 4.5: If the resultant record set includes no records, check_host()
        % produces the "none" result.
        {spf_records, []} ->
            {none, [{bad_spf, no_spf_records}]};
        % 4.5: If the resultant record set includes more than one record,
        % check_host() produces the "permerror" result.
        {spf_records, [_, _ | _] = Records} ->
            {none, [{bad_spf, {more_than_one_spf_record, Records}}]}
    end.


% see 4.3
is_valid_domain(Domain) ->
    % XXX: internationalized domain names? needs plenty of testing.
    maybe
        {parts, [_, _ | _] = Parts} ?= {parts, string:split(Domain, ".")},
        Label = hd(Parts),
        {label_empty, false} ?= {label_empty, Label == ""},
        Length = length(Label),
        {label_too_long, false} ?= {label_too_long, Length > 63},
        begin
            true
        end
    else
        {parts, [_]} ->
            {false, not_multi_label};
        {Condition, true} ->
            {false, Condition}
    end.

txt_records(Domain) ->
    % supply a default timeout so we don't hang forever in case of problems
    Opts = [{timeout, timer:seconds(10)}],
    inet_res:lookup(Domain, _Class = in, _Type = txt, [], Opts).

find_spf_records(TXTRecords) ->
    % 4.5: discard records that do not begin with a version section of exactly "v=spf1".
    % Note that the version section is terminated by either an SP character or
    % the end of the record.
    lists:filter(fun("v=spf1") -> true;
                    ("v=spf1 " ++ _) -> true end, TXTRecords).
