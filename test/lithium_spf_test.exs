# SPDX-FileCopyrightText: 2025 Johannes Christ
# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule :lithium_spf_test do
  use ExUnit.Case

  @ip {127, 0, 0, 127}
  @sender ~c"mike@localhost"

  defp check_domain(domain) do
    :lithium_spf.check_host(@ip, domain, @sender)
  end

  describe "domain validation" do
    test "rejects empty domain" do
      assert {:none, [invalid_domain: :not_multi_label]} = check_domain(~c"")
    end

    test "rejects empty label" do
      assert {:none, [invalid_domain: :label_empty]} = check_domain(~c".host")
    end

    test "rejects non-multi label domain name" do
      assert {:none, [invalid_domain: :not_multi_label]} = check_domain(~c"host")
    end

    test "rejects too long label" do
      over_sixty_three_chars =
        ~c"hellojoehellomikesystemworkingseemstobeokayfineletrytrathatagainbutintroduceabug.localhost"

      assert {:none, [invalid_domain: :label_too_long]} = check_domain(over_sixty_three_chars)
    end
  end
end
