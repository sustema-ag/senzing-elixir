defmodule Senzing.G2.ConfigUpdater do
  @moduledoc """
  Worker to update config from file. Can be added to your supervision tree.

  ## Example

  ```elixir
  Supervisor.start_link([
    {Senzing.G2.ConfigUpdater, [config_path: "path/to/g2config.json"]}
  ])
  ```
  """

  use GenServer

  alias Senzing.G2.ConfigManager
  alias Senzing.G2.ResourceInit

  @type option() :: {:config_path, Path.t()}
  @type options() :: [option()]

  @doc false
  @spec start_link(options :: options()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @doc false
  @impl GenServer
  def init(options) do
    with {:ok, config_path} <- Keyword.fetch(options, :config_path),
         :ok <- update(config_path),
         do: :ignore
  end

  @doc """
  Update the config and set it as the new default configuration.

  ## Options

  * `config_path` - Path to the new config file.
  * `resource_init_options` - Options to pass to the
    `ResourceInit.ConfigManager` worker.

  ## Examples

      iex> Senzing.G2.ConfigUpdater.update("path/to/g2config.json")
      :ok

  """
  @spec update(config_path :: Path.t(), resource_init_options :: ResourceInit.options()) ::
          Senzing.G2.result()
  def update(config_path, resource_init_options \\ []) do
    resource_init_options = Keyword.put(resource_init_options, :mod, ConfigManager)

    with {:ok, config} <- File.read(config_path),
         {:ok, maybe_resource_init_pid} <- start_resource_init(resource_init_options),
         {:ok, config_id} <- ConfigManager.add_config(config),
         :ok <- ConfigManager.set_default_config_id(config_id) do
      stop_resource_init(maybe_resource_init_pid)
    end
  end

  @spec start_resource_init(options :: ResourceInit.options()) ::
          {:ok, pid() | nil} | {:error, reason :: term()}
  defp start_resource_init(options) do
    case ResourceInit.start_link(options) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop_resource_init(maybe_resource_init_pid :: pid() | nil) :: :ok
  defp stop_resource_init(maybe_resource_init_pid)
  defp stop_resource_init(nil), do: :ok
  defp stop_resource_init(pid), do: GenServer.stop(pid)
end
