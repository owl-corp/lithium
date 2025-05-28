defmodule Lithium.DMARC.Policy do
  @moduledoc """
  Represents a DMARC policy record as per RFC 7489 section 6.

  Default values are filled in the validation methods if not provided.

  Values are translated from raw DMARC options to human-readable atoms at this point.

  Most errors in policy formatting soft-fail to the default values as specified
  in the RFC document. Processing only halts under certain unrecoverable conditions
  (e.g. invalid version, invalid policy with no RUA, etc.).
  """
  defstruct [
    :v,
    :p,
    :adkim,
    :aspf,
    :fo,
    :pct,
    :rf,
    :ri,
    :rua,
    :ruf,
    :sp
  ]

  @alignment_default :relaxed
  @fo_default [:all_failure]
  @pct_default 100
  @ri_default 86400
  @rf_default :afrf

  require Logger

  @typedoc """
  The DMARC version (currently always "DMARC1").
  """
  @type v :: :dmarc1

  @typedoc """
  The DMARC requested mail received policy.
  """
  @type p :: :none | :quarantine | :reject

  @typedoc """
  DKIM identity alignment mode.
  """
  @type adkim :: :relaxed | :strict

  @typedoc """
  SPF identity alignment mode.
  """
  @type aspf :: :relaxed | :strict

  @typedoc """
  All possible DMARC failure reporting options.
  """
  @type fo_modes :: :all_failure | :any_failure | :dkim_failure | :spf_failure

  @typedoc """
  The selected DMARC failure reporting options.
  """
  @type fo :: [fo_modes()]

  @typedoc """
  The percentage of messages subjected to the DMARC policy.
  """
  @type pct :: integer()

  @typedoc """
  The supported reporting formats for aggregate reports.
  """
  @type rf_formats :: :afrf

  @typedoc """
  Selected reporting formats for aggregate reports.
  """
  @type rf :: [rf_formats()]

  @typedoc """
  The interval in seconds between DMARC aggregate reports.
  """
  @type ri :: integer()

  @typedoc """
  The mailto URI for aggregate reports.
  """
  @type rua :: String.t()

  @typedoc """
  The mailto URI for forensic reports.
  """
  @type ruf :: String.t()

  @typedoc """
  The mailto URI for the subdomain policy.
  """
  @type sp :: p()

  @typedoc """
  The DMARC policy record.
  """
  @type t :: %__MODULE__{
          v: v(),
          p: p(),
          adkim: adkim(),
          aspf: aspf(),
          fo: fo(),
          pct: pct(),
          rf: rf(),
          ri: ri(),
          rua: [rua()],
          ruf: [ruf()],
          sp: sp()
        }

  @spec parse_version(version :: String.t()) :: {:ok, v()} | {:error, :invalid_version}
  defp parse_version(version) do
    case String.downcase(version) do
      "dmarc1" ->
        {:ok, :DMARC1}

      _ ->
        Logger.error("Invalid DMARC version: #{inspect(version)}")
        {:error, :invalid_version}
    end
  end

  # As per RFC 7489, when we parse p= strictness if we find an
  # invalid value but have a valid RUA, we continue as if we have
  # found a :none policy.
  @spec parse_policy(
          location :: :p | :sp,
          strictness :: String.t(),
          has_rua :: boolean()
        ) :: {:ok, p() | nil} | {:error, :invalid_policy}
  defp parse_policy(location, policy, has_rua) do
    case policy do
      "none" ->
        {:ok, :none}

      "quarantine" ->
        {:ok, :quarantine}

      "reject" ->
        {:ok, :reject}

      _ ->
        cond do
          location == :p and has_rua ->
            {:ok, :none}

          location == :sp ->
            {:ok, nil}

          true ->
            Logger.error("Invalid DMARC policy: #{inspect(policy)}")
            {:error, :invalid_policy}
        end
    end
  end

  @spec parse_alignment_strictness(strictness :: String.t() | nil) ::
          adkim() | aspf()
  defp parse_alignment_strictness(strictness) do
    case strictness do
      "r" ->
        :relaxed

      "s" ->
        :strict

      _ ->
        # Default to relaxed if not specified
        @alignment_default
    end
  end

  @spec parse_fo(fo :: [String.t()] | nil) :: fo()
  defp parse_fo(nil), do: @fo_default

  defp parse_fo(fo) do
    parsed_modes =
      Enum.map(fo, fn mode ->
        case mode do
          "0" -> :all_failure
          "1" -> :any_failure
          "d" -> :dkim_failure
          "s" -> :spf_failure
          _ -> nil
        end
      end)

    parsed_modes = Enum.reject(parsed_modes, &is_nil/1) |> Enum.sort() |> Enum.uniq()

    if parsed_modes == [] do
      @fo_default
    else
      parsed_modes
    end
  end

  @spec parse_pct(pct :: String.t() | nil) :: pct()
  defp parse_pct(nil), do: @pct_default

  defp parse_pct(pct) do
    case Integer.parse(pct) do
      {pct, ""} when pct >= 0 and pct <= 100 ->
        pct

      _ ->
        @pct_default
    end
  end

  @spec parse_rf(rf :: [String.t()]) :: rf()
  defp parse_rf(nil), do: [@rf_default]
  defp parse_rf([]), do: [@rf_default]

  defp parse_rf(rf) do
    parsed_formats =
      Enum.map(rf, fn format ->
        case format do
          "afrf" -> :afrf
          _ -> nil
        end
      end)

    parsed_formats = Enum.reject(parsed_formats, &is_nil/1) |> Enum.sort() |> Enum.uniq()

    if parsed_formats == [] do
      [@rf_default]
    else
      parsed_formats
    end
  end

  @spec parse_ri(ri :: String.t() | nil) :: ri()
  defp parse_ri(nil), do: @ri_default

  defp parse_ri(ri) do
    case Integer.parse(ri) do
      {ri, ""} when ri >= 3600 and ri <= 86400 ->
        # We have to handle daily interval reports, we should handle hourly interval.
        # We do not *have* to handle anything else.
        ri

      _ ->
        @ri_default
    end
  end

  @spec parse_addresses(addresses :: String.t() | nil) ::
          [rua() | ruf()]
  defp parse_addresses(nil), do: []

  defp parse_addresses(addresses) do
    addresses
    |> Enum.map(&parse_address/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec parse_address(address :: String.t()) ::
          rua() | ruf()
  defp parse_address(address) do
    uri = URI.parse(address)

    if uri.scheme == "mailto" do
      uri.path
    else
      nil
    end
  end

  def from_raw_map(raw_map) do
    with {:ok, version} <- parse_version(raw_map[:v]),
         rua <- parse_addresses(raw_map[:rua]),
         ruf <- parse_addresses(raw_map[:ruf]),
         {:ok, p} <- parse_policy(:p, raw_map[:p], length(rua) > 0) do
      adkim = parse_alignment_strictness(raw_map[:adkim])
      aspf = parse_alignment_strictness(raw_map[:aspf])
      fo = parse_fo(raw_map[:fo])
      pct = parse_pct(raw_map[:pct])
      rf = parse_rf(raw_map[:rf])
      ri = parse_ri(raw_map[:ri])

      sp =
        case parse_policy(:sp, raw_map[:sp], length(rua) > 0) |> elem(1) do
          nil -> p
          sp -> sp
        end

      {:ok,
       %__MODULE__{
         p: p,
         v: version,
         adkim: adkim,
         aspf: aspf,
         fo: fo,
         pct: pct,
         rf: rf,
         ri: ri,
         rua: rua,
         ruf: ruf,
         sp: sp
       }}
    else
      error -> error
    end
  end
end
