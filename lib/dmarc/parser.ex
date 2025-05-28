defmodule Lithium.DMARC.Parser do
  @moduledoc """
  A wrapper around the `:dmarc_parser` yecc and leex parser.

  This module is responsible for parsing DMARC records and returning a
  map of the parsed values. It is then up to the `Lithium.DMARC.Policy`
  module to validate and process these values.
  """

  require Logger

  def parse_policy(record) do
    case :dmarc_lexer.string(String.to_charlist(record)) do
      {:ok, tokens, _} ->
        case :dmarc_parser.parse(tokens) do
          {:ok, %{invalid: invalid_tokens, valid: parsed}} ->
            if Kernel.map_size(invalid_tokens) > 0 do
              Logger.warning("DMARC record contains invalid tokens: #{inspect(invalid_tokens)}")
            end
            {:ok, keyword_to_string_map(parsed)}

          {:error, reason} ->
            {:error, reason}

          {:error, reason, _} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}

      {:error, reason, _} ->
        {:error, reason}
    end
  end

  defp keyword_to_string_map(keyword_list) do
    keyword_list
    |> Enum.map(fn {k, v} ->
      {k, convert_value(v)}
    end)
    |> Map.new()
  end

  defp convert_value(value) when is_list(value) and is_integer(hd(value)) do
    to_string(value)
  end

  defp convert_value(value) when is_list(value) do
    Enum.map(value, &convert_value/1)
  end

  defp convert_value(value), do: value
end
