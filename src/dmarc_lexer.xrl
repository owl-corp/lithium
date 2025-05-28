Definitions.

WHITESPACE = [\s\t\n\r]
KEY = (adkim|aspf|fo|pct|p|sp|rua|ruf|v|ri|rf)
VALUE = [^=;:,\s\t\n\r]+
MAILTO_EMAIL = (mailto:[^\s\t\n\r,;]+)
LOST_MAILTO = mailto

Rules.

{KEY}            : {token, {key, TokenLine, list_to_atom(TokenChars)}}.
{MAILTO_EMAIL}   : {token, {mailto, TokenLine, TokenChars}}.
=                : {token, {equals, TokenLine}}.
:                : {token, {colon, TokenLine}}.
;                : {token, {semicolon, TokenLine}}.
,                : {token, {comma, TokenLine}}.
{LOST_MAILTO}    : {error, invalid_mailto}.
{VALUE}          : {token, {string, TokenLine, TokenChars}}.
{WHITESPACE}+    : skip_token.

Erlang code.
