defmodule Lithium.DMARC do
  require Logger
  
  def get_dmarc_record(domain) do
    with {:ok, records} <- Lithium.DNS.fetch_txt("_dmarc." <> domain) do
      filtered =
        records
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn found_record ->
          # As per Section 7.1, DMARC report authorisations also use a format of "v=DMARC1"
          # We should check when we find a tag that it is not *just* a version record.

          # It would technically be invalid to serve this DMARC report authorisation from
          # _dmarc.domain.com, however from testing some people do peculiar deployments
          # using wildcards and it ends up showing there.

          # For now, we should probably be lenient and just ignore the report authorisation
          # instead of tossing the entire DMARC validation process.
          trimmed =
            found_record
            |> String.replace(" ", "")

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
    else
      error ->
        error
    end
  end
end
