# SPDX-FileCopyrightText: 2025 Johannes Christ
# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule :lithium_spf_lexer_test do
  use ExUnit.Case, async: true

  test "parses simple record" do
    record = ~c"v=spf1 include:_spf.google.com ~all"

    assert {:ok,
            [
              unknown_modifier: {~c"v", ~c"spf1"},
              directive: {:pass, {~c"include", ~c"_spf.google.com"}},
              directive: {:softfail, {~c"all", []}}
            ], 1} = :lithium_spf_lexer.string(record)
  end

  test "parses ip4 record" do
    record = ~c"v=spf1 ip4:193.57.144.0/24 ip6:2a0f:85c0::/4 -all"

    assert {:ok,
            [
              unknown_modifier: {~c"v", ~c"spf1"},
              directive: {:pass, {{193, 57, 144, 0}, 24}},
              directive: {:pass, {{10767, 34240, 0, 0, 0, 0, 0, 0}, 4}},
              directive: {:fail, {~c"all", []}}
            ], 1} = :lithium_spf_lexer.string(record)
  end

  test "parses awful record" do
    record = ~c"v=spf1 exists:%{ir}.%{v}.arpa.%{o}._spf.lmax.com include:%{o}._spf.lmax.com -all"

    assert {:ok,
            [
              unknown_modifier: {~c"v", ~c"spf1"},
              directive: {:pass, {~c"exists", ~c"%{ir}.%{v}.arpa.%{o}._spf.lmax.com"}},
              directive: {:pass, {~c"include", ~c"%{o}._spf.lmax.com"}},
              directive: {:fail, {~c"all", []}}
            ], 1} = :lithium_spf_lexer.string(record)
  end
end
