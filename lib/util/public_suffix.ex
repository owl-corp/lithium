defmodule Lithium.Util.PublicSuffix do
  use GenServer

  require Logger

  @moduledoc """
  A GenServer that loads the public suffix list from a file and provides
  functionality to find the organisational domain of a given domain name.
  """

  @public_suffix_list_path Application.app_dir(:lithium, "priv/public_suffix_list.dat")
  @public_suffix_list_url "https://publicsuffix.org/list/public_suffix_list.dat"
  @public_suffix_max_age div(:timer.hours(7 * 24), 1000) # 7 days in seconds

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    if File.exists?(@public_suffix_list_path) and psl_fresh?() do
      Logger.info("Loading public suffix list from disk cache.")
      Process.send_after(self(), :update_public_suffix_list,  psl_next_refresh() - :os.system_time(:seconds))
      {:ok, load_public_suffix_list()}
    else
      Logger.info("Public suffix list file not found or not fresh, fetching from remote.")
      case fetch_public_suffix_list() do
        {:ok, list} ->
          Process.send_after(self(), :update_public_suffix_list, @public_suffix_max_age)
          {:ok, list}

        {:error, reason} ->
          Logger.error("Failed to fetch public suffix list: #{reason}")
          {:stop, reason}
      end
    end
  end

  @impl true
  def handle_info(:update_public_suffix_list, state) do
    case fetch_public_suffix_list() do
      {:ok, new_list} ->
        Process.send_after(self(), :update_public_suffix_list, @public_suffix_max_age)
        {:noreply, new_list}

      {:error, reason} ->
        Logger.error("Failed to update public suffix list: #{reason}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:get_domain, domain}, _from, state) do
    {:reply, get_od_for_domain(domain, state), state}
  end

  def load_public_suffix_list do
    case File.read(@public_suffix_list_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "//"))
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.downcase/1)
        |> Enum.map(&String.replace(&1, "*.", ""))

      {:error, reason} ->
        Logger.error("Failed to load public suffix list: #{reason}")
        []
    end
  end

  def fetch_public_suffix_list do
    Logger.info("Fetching public suffix list from #{@public_suffix_list_url}")

    request = :httpc.request(:get, {@public_suffix_list_url, []}, [], [])

    case request do
      {:ok, {{_, 200, _}, _, body}} ->
        File.write(@public_suffix_list_path, body)
        {:ok, load_public_suffix_list()}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # XXX: Actually, doing this in a process is a silly idea because we will
  #      process bottleneck. No reason this can't just be called directly
  #      from the DMARC module. Note to myself to remove.

  defp get_od_for_domain(domain, public_suffix_list) do
    # x.y.z.jb3.dev -> jb3.dev

    # ["com", "jb3", "example"]
    domain_parts = String.split(domain, ".") |> Enum.reverse()

    # [["com", "public-suffix"], ...]
    suffix_parts =
      Enum.map(public_suffix_list, &String.split(&1, ".")) |> Enum.map(&Enum.reverse/1)

    # Add domain parts together until it is no longer in the suffix_parts list

    Enum.reduce_while(domain_parts, [], fn part, acc ->
      new_acc = acc ++ [part]

      if Enum.member?(suffix_parts, new_acc) do
        {:cont, new_acc}
      else
        {:halt, new_acc}
      end
    end)
    |> Enum.reverse()
    |> Enum.join(".")
    |> String.downcase()
    |> String.trim()
  end

  def get_domain(domain) do
    GenServer.call(__MODULE__, {:get_domain, domain})
  end

  defp psl_fresh?() do
    case File.stat(@public_suffix_list_path, time: :posix) do
      {:ok, stat} ->
        now = :os.system_time(:seconds)
        stat.mtime + @public_suffix_max_age > now

      {:error, _} ->
        false
    end
  end

  defp psl_next_refresh() do
    case File.stat(@public_suffix_list_path, time: :posix) do
      {:ok, stat} ->
        stat.mtime + @public_suffix_max_age

      {:error, _} ->
        nil
    end
  end
end
