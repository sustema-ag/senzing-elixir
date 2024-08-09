defmodule Senzing.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [Senzing.Telemetry],
      strategy: :one_for_one,
      name: Senzing.Supervisor
    )
  end
end
