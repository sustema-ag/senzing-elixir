defmodule Senzing.G2.Config do
  @moduledoc """
  G2 Config NIF Functionality

  See https://docs.senzing.com/python/3/g2config/index.html

  To use any of these functions, make sure to start `Senzing.G2.ResourceInit`
  with the `mod` option set to `#{__MODULE__}`.
  """

  @behaviour Senzing.G2.ResourceInit

  use GenServer

  alias Senzing.G2
  alias Senzing.G2.Config.Nif
  alias Senzing.G2.ResourceInit

  @typedoc """
  Serialized Config

  > #### Opaque Config {: .warning}
  >
  > This should only be serialized in files and not manipulated directly. Use the
  > functions of this module to alter the configuration.
  """
  @type t() :: String.t()

  @typedoc """
  Data Source Configuration

  See https://docs.senzing.com/python/3/g2config/
  """
  @type data_source() :: map()

  @type resource_init_option() ::
          {:verbose_logging, boolean()} | {:prime, boolean()} | {:config_id, integer()}
  @type resource_init_options() :: [resource_init_option()]

  @typedoc """
  Start Option

  * `name` - GenServer name
  * `load` - Load a `t:#{__MODULE__}.t/0`. See https://docs.senzing.com/python/3/g2config/#load
  """
  @type option() :: {:load, t()} | {:name, GenServer.name()}

  @typedoc """
  Start Options

  See `t:#{__MODULE__}.option/0`
  """
  @type options() :: [option()]

  ##############################################################################
  # GenServer Start / Callbacks
  ##############################################################################

  @doc """
  Start the configuration

  See `t:#{__MODULE__}.option/0` for available options.
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, Keyword.take(opts, [:load]), Keyword.take(opts, [:name]))

  @doc false
  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    opts
    |> Keyword.fetch(:load)
    |> case do
      {:ok, config} -> Nif.load_it(config)
      :error -> Nif.create()
    end
    |> case do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc false
  @impl GenServer
  def terminate(_reason, config), do: Nif.close(config)

  @doc false
  @impl GenServer
  def handle_call(:list_data_sources, _from, config) do
    {:reply,
     with(
       {:ok, response} <- Nif.list_data_sources(config),
       %{"DATA_SOURCES" => data_sources} <- :json.decode(response),
       do: {:ok, data_sources}
     ), config}
  end

  def handle_call({:add_data_source, data_source}, _from, config) do
    {:reply,
     with(
       {:ok, response} <- Nif.add_data_source(config, IO.iodata_to_binary(:json.encode(data_source))),
       do: {:ok, :json.decode(response)}
     ), config}
  end

  def handle_call({:delete_data_source, data_source}, _from, config),
    do: {:reply, Nif.delete_data_source(config, IO.iodata_to_binary(:json.encode(data_source))), config}

  def handle_call(:save, _from, config) do
    {:reply, Nif.save(config), config}
  end

  ##############################################################################
  # ResourceInit Callbacks
  ##############################################################################

  # This method will initialize the G2 Config object.
  #
  # It must be called prior to any other calls.
  #
  # Usually you will want to start the config by starting the `senzing`
  # application or by starting `Senzing.G2.Init` module as a worker.
  @doc false
  @impl ResourceInit
  @spec resource_init(
          name :: String.t(),
          ini_params :: ResourceInit.ini_params(),
          options :: resource_init_options()
        ) :: G2.result()
  def resource_init(name, config, options \\ []) when is_binary(name) and is_map(config),
    do: Nif.init(name, IO.iodata_to_binary(:json.encode(config)), options[:verbose_logging] || false)

  # This method will destroy and perform cleanup for the G2 Config object.
  #
  # It should be called after all other calls are complete.
  @doc false
  @impl ResourceInit
  @spec resource_destroy() :: G2.result()
  defdelegate resource_destroy, to: Nif, as: :destroy

  ##############################################################################
  # Exposed Functions
  ##############################################################################

  @doc """
  Exports an in-memory configuration as a JSON string.

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, _json} = Senzing.G2.Config.save(config)
      iex> # {:ok, "{\"G2_CONFIG\": \"...\"}"}

  """
  @doc type: :configuration_object_management
  @spec save(server :: GenServer.server()) :: G2.result(t())
  def save(server), do: GenServer.call(server, :save)

  @doc """
  Returns a list of data sources contained in an in-memory configuration.

  See https://docs.senzing.com/python/3/g2config/#listdatasources

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, _data_sources} = Senzing.G2.Config.list_data_sources(config)
      {:ok, [
        %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
        %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2}
      ]}

  """
  @doc type: :datasource_management
  @spec list_data_sources(server :: GenServer.server()) :: G2.result([data_source()])
  def list_data_sources(server), do: GenServer.call(server, :list_data_sources)

  @doc """
  Add Data Source

  See https://docs.senzing.com/python/3/g2config/#adddatasource

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, _data_source} = Senzing.G2.Config.add_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})
      iex> {:ok, _data_sources} = Senzing.G2.Config.list_data_sources(config)
      {:ok, [
        %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
        %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2},
        %{"DSRC_CODE" => "NAME_OF_DATASOURCE", "DSRC_ID" => 1001}
      ]}

  """
  @doc type: :datasource_management
  @spec add_data_source(server :: GenServer.server(), data_source :: data_source()) ::
          G2.result(data_source())
  def add_data_source(server, data_source), do: GenServer.call(server, {:add_data_source, data_source})

  @doc """
  Delete Data Source

  See https://docs.senzing.com/python/3/g2config/#deletedatasource

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, _data_source} = Senzing.G2.Config.add_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})
      iex> :ok = Senzing.G2.Config.delete_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})
      iex> {:ok, _data_sources} = Senzing.G2.Config.list_data_sources(config)
      {:ok, [
        %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
        %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2}
      ]}

  """
  @doc type: :datasource_management
  @spec delete_data_source(server :: GenServer.server(), data_source :: data_source()) :: G2.result()
  def delete_data_source(server, data_source), do: GenServer.call(server, {:delete_data_source, data_source})
end
