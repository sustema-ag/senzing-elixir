defmodule Mix.Tasks.Senzing.UpdateConfig do
  @shortdoc "Update Senzing G2 config"
  @moduledoc """
  Update Senzing G2 Config

  ## Arguments

  * `config_path` - Path to the senzing config.json

  """

  use Mix.Task

  alias Senzing.G2.ConfigUpdater

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args)

  def run([config_path]) do
    case ConfigUpdater.update(config_path) do
      :ok ->
        Mix.shell().info("Config Updated")

      {:error, reason} ->
        Mix.shell().error("""
        Config Update Failed. Reason:
        #{inspect(reason, pretty: true)}
        """)
    end
  end

  def run(_args), do: Mix.shell().error("Run with single argument containing the path to the config.json")
end
