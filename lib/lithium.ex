defmodule Lithium do
  use Application

  @moduledoc """
  Lithium is a mail authentication daemon.
  """

  @impl true
  def start(_start_type, _start_args) do
    children = [
      {Lithium.Util.PublicSuffix, []}
    ]

    opts = [strategy: :one_for_one, name: Lithium.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
