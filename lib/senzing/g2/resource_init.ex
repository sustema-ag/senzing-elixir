defmodule Senzing.G2.ResourceInit do
  @moduledoc """
  Senzing Context Worker

  Starts and cleans up resources needed by the Senzing Engine.

  ## Contexts

  * `Senzing.G2.Config`
  * `Senzing.G2.ConfigManager`
  * `Senzing.G2.Engine`

  ## Usage

  Via GenServer:

  ```elixir
  {:ok, pid} = Senzing.G2.ResourceInit.start_link(
    mod: Senzing.G2.Engine
  )
  ```

  The resource can also be automatically started by setting `mod` in the
  `senzing` dependency configuration.

  """
  use GenServer

  alias Senzing.G2
  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine

  require Logger

  @type ini_params() :: map()

  @type option() ::
          {:mod, Config | Engine}
          | {:name, String.t()}
          | {:ini_params, ini_params()}
          | Engine.resource_init_option()
          | Config.resource_init_option()
          | ConfigManager.resource_init_option()
  @type options() :: [option()]

  @doc false
  @spec start_link(opts :: options()) :: GenServer.on_start()
  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: Module.concat(__MODULE__, Keyword.fetch!(opts, :mod)))

  @doc false
  @impl GenServer
  def init(options) do
    options = Keyword.put_new_lazy(options, :ini_params, &default_ini_params/0)

    {mod, options} = Keyword.pop!(options, :mod)
    {name, options} = Keyword.pop(options, :name, "Senzing Engine")
    {ini_params, options} = Keyword.pop!(options, :ini_params)

    Process.flag(:trap_exit, true)

    Logger.info("Starting #{inspect(mod)} with name #{inspect(name)}")

    case mod.resource_init(name, ini_params, options) do
      :ok -> {:ok, mod}
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc false
  @spec child_spec(init_arg :: options()) :: Supervisor.child_spec()
  def child_spec(init_arg), do: Map.put(super(init_arg), :id, Module.concat(__MODULE__, Keyword.fetch!(init_arg, :mod)))

  @doc false
  @impl GenServer
  def terminate(_reason, mod) do
    Logger.info("Stopping #{inspect(mod)}")

    mod.resource_destroy()
  end

  @doc false
  @callback resource_init(name :: String.t(), ini_params :: ini_params(), options :: Keyword.t()) ::
              G2.result()
  @doc false
  @callback resource_destroy() :: G2.result()

  defp default_ini_params do
    root_path =
      System.get_env("SENZING_ROOT", Application.get_env(:senzing, :root_path, "/opt/senzing"))

    config_path = Application.get_env(:senzing, :config_path, Path.join(root_path, "etc"))

    resource_path =
      Application.get_env(:senzing, :resource_path, Path.join(root_path, "resources"))

    support_path = Application.get_env(:senzing, :support_path, Path.join(root_path, "data"))

    db_connection =
      Application.get_env(
        :senzing,
        :db_connection,
        "sqlite3://#{Path.join(root_path, "var/sqlite/G2C.db")}"
      )

    %{
      PIPELINE: %{
        CONFIGPATH: config_path,
        RESOURCEPATH: resource_path,
        SUPPORTPATH: support_path
      },
      SQL: %{CONNECTION: db_connection}
    }
  end
end
