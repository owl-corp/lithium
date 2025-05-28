defmodule Lithium.DMARC do
  require Logger

  defp select_record(records) do
    filtered =
      records
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn found_record ->
        # As per Section 7.1, DMARC report authorisations also use a format of "v=DMARC1"
        # We should check when we find a tag that it is not *just* a version record.
        trimmed = String.replace(found_record, " ", "")
        String.starts_with?(trimmed, "v=DMARC1;") and trimmed != "v=DMARC1;"
      end)

    case filtered do
      [] ->
        {:error, :nxdomain}
      [record] ->
        {:ok, record}
      _ ->
        {:error, :multiple_records}
    end
  end

  def get_dmarc_policy(domain) do
    with od <- Lithium.Util.PublicSuffix.get_domain(domain),
         {:ok, records} <- Lithium.DNS.fetch_txt("_dmarc." <> od),
         {:ok, record } <- select_record(records),
         {:ok, policy} <- Lithium.DMARC.Parser.parse_policy(record)
        do
          {:ok, policy}
    else
      error ->
        error
    end
  end
end
