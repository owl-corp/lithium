defmodule Lithium.DNS do
  @moduledoc """
  DNS query module.

  Some query magic is performed to do things like joining TXT records together.
  """

  @spec fetch_txt(String.t()) :: {:ok, [String.t()]} | {:error, any()}
  def fetch_txt(name) do
    case :inet_res.getbyname(String.to_charlist(name), :txt) do
      {:ok, {:hostent, _domain, _aliases, :txt, _length, records}} ->
        records
        |> Enum.map(&List.to_string/1)
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end
end
