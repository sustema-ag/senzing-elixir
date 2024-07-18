defmodule Senzing.G2.Engine do
  @moduledoc """
  G2 Engine NIF Functionality
  """

  @behaviour Senzing.G2.ResourceInit

  alias Senzing.G2
  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine.Nif
  alias Senzing.G2.ResourceInit

  @type resource_init_option() ::
          {:verbose_logging, boolean()} | {:prime, boolean()} | {:config_id, integer()}
  @type resource_init_options() :: [resource_init_option()]

  @typedoc """
  Record as a map

  See https://senzing.zendesk.com/hc/en-us/articles/231925448-Generic-Entity-Specification-Data-Mapping

  ## Example

  ```json
  {
    "DATA_SOURCE": "COMPANIES",
    "RECORD_ID": 2001,
    "RECORD_TYPE": "ORGANIZATION",
    "NAME_LIST": [
      {
        "NAME_TYPE": "PRIMARY",
        "NAME_ORG": "Presto Company"
      }
    ],
    "TAX_ID_NUMBER": "11111",
    "TAX_ID_COUNTRY": "US",
    "ADDRESS_LIST": [
      {
        "ADDR_TYPE": "PRIMARY",
        "ADDR_LINE1": "Presto Plaza - 2001 Eastern Ave",
        "ADDR_CITY": "Las Vegas",
        "ADDR_STATE": "NV",
        "ADDR_POSTAL_CODE": "89111",
        "ADDR_COUNTRY": "US"
      },
      {
        "ADDR_TYPE": "MAIL",
        "ADDR_LINE1": "Po Box 111",
        "ADDR_CITY": "Las Vegas",
        "ADDR_STATE": "NV",
        "ADDR_POSTAL_CODE": "89111",
        "ADDR_COUNTRY": "US"
      }
    ],
    "PHONE_LIST": [
      {
        "PHONE_TYPE": "PRIMARY",
        "PHONE_NUMBER": "800-201-2001"
      }
    ],
    "WEBSITE_ADDRESS": "Prestofabrics.com",
    "SOCIAL_HANDLE": "@prestofabrics",
    "SOCIAL_NETWORK": "twitter"
  }
  ```
  """
  @type record() :: map()
  @type record_id() :: String.t()

  @type redo_record() :: map()

  @type data_source() :: String.t()

  # This method will initialize the G2 processing object.
  #
  # It must be called once per process, prior to any other calls.
  #
  # Usually you will want to start the engine by starting the `senzing`
  # application or by starting `Senzing.G2.Init` module as a worker.
  @doc false
  @impl ResourceInit
  @spec resource_init(
          name :: String.t(),
          ini_params :: ResourceInit.ini_params(),
          options :: resource_init_options()
        ) :: G2.result()
  def resource_init(name, config, options \\ []) when is_binary(name) and is_map(config) do
    init =
      case Keyword.fetch(options, :config_id) do
        :error -> &Nif.init/3
        {:ok, config_id} -> &Nif.init_with_config_id(&1, &2, config_id, &3)
      end

    with :ok <-
           init.(
             name,
             IO.iodata_to_binary(:json.encode(config)),
             options[:verbose_logging] || false
           ) do
      if options[:prime], do: prime(), else: :ok
    end
  end

  @doc """
  This method will re-initialize the G2 processing object.

  See https://docs.senzing.com/python/3/g2engine/init/#reinit

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      iex> {:ok, config_json} = Senzing.G2.Config.save(config)
      iex> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      iex> Senzing.G2.Engine.reinit(config_id)
      :ok

  """
  @doc type: :initialization
  @spec reinit(config_id :: integer()) :: G2.result()
  defdelegate reinit(config_ig), to: Nif

  @doc """
  This method may optionally be called to pre-initialize some of the heavier
  weight internal resources of the G2 engine.

  See https://docs.senzing.com/python/3/g2engine/init/#primeengine

  ## Examples

      iex> Senzing.G2.Engine.prime()
      :ok

  """
  @doc type: :initialization
  @spec prime() :: G2.result()
  defdelegate prime(), to: Nif

  @doc """
  This method returns an identifier for the loaded G2 engine configuration.

  See https://docs.senzing.com/python/3/g2engine/init/#getactiveconfigid

  ## Examples

      iex> {:ok, id} = Senzing.G2.Engine.get_active_config_id()
      iex> is_integer(id)
      true

  """
  @doc type: :initialization
  @spec get_active_config_id() :: G2.result(ConfigManager.config_id())
  defdelegate get_active_config_id(), to: Nif

  @doc """
  This method will export the current configuration of the G2 engine.

  See https://docs.senzing.com/python/3/g2engine/init/#exportconfig

  ## Examples

      iex> {:ok, {config, config_id}} = Senzing.G2.Engine.export_config()
      iex> is_binary(config)
      true
      iex> is_integer(config_id)
      true

  """
  @doc type: :initialization
  @spec export_config() :: G2.result({Config.t(), ConfigManager.config_id()})
  defdelegate export_config(), to: Nif

  @doc """
  This method returns the date of when the entity datastore was last modified.

  See https://docs.senzing.com/python/3/g2engine/init/#getrepositorylastmodified

  ## Examples

      iex> {:ok, %DateTime{}} = Senzing.G2.Engine.get_repository_last_modified()
      iex> # {:ok, ~U[2024-04-02 11:23:14.613Z]}

  """
  @doc type: :initialization
  @spec get_repository_last_modified() :: G2.result(DateTime.t())
  def get_repository_last_modified do
    with {:ok, time} <- Nif.get_repository_last_modified(),
         do: DateTime.from_unix(time, :millisecond)
  end

  @doc """
  This method is used to add entity data into the system.

  This adds or updates a single entity observation record, by adding features
  for the observation.

  See https://docs.senzing.com/python/3/g2engine/adding/

  ## Options

  * `:load_id` - The load ID for the record.
  * `:record_id` - The record ID for the record. Can be left out and will
    automatically be detected based on record definition.
  * `:return_info` - If `true`, the response will include information about the
    changes made. `nil` in response otherwise.
  * `:return_record_id` - If `true`, the response will include the record ID.

  ## Examples

      iex> {:ok, {record_id, _info}} = Senzing.G2.Engine.add_record(
      ...>   %{"RECORD_ID" => "test id"},
      ...>   "TEST",
      ...>   load_id: "test load",
      ...>   record_id: "test id",
      ...>   return_info: true,
      ...>   return_record_id: true
      ...> )
      iex> # info => %{
      ...> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      ...> #   "DATA_SOURCE" => "TEST",
      ...> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      ...> #   "RECORD_ID" => "test id"
      ...> # }
      iex> record_id
      "test id"
  """
  @doc type: :add_records
  @spec add_record(
          record :: record(),
          data_source :: data_source(),
          opts :: [load_id: String.t(), return_info: boolean(), return_record_id: boolean(), record_id: record_id()]
        ) :: G2.result({record_id :: record_id() | nil, info :: record() | nil}) | G2.result()
  def add_record(record, data_source, opts \\ []) do
    with {:ok, {record_id, info}} <-
           Nif.add_record(
             data_source,
             opts[:record_id],
             IO.iodata_to_binary(:json.encode(record)),
             opts[:load_id],
             opts[:return_record_id] || false,
             opts[:return_info] || false
           ) do
      {:ok, {record_id, if(info, do: :json.decode(info))}}
    end
  end

  @doc """
  This method is used to replace entity data in the system.

  This replaces a single entity observation record, by replacing features for
  the observation.

  See https://docs.senzing.com/python/3/g2engine/adding/

  ## Options

  * `:load_id` - The load ID for the record.
  * `:return_info` - If `true`, the response will include information about the
    changes made. `nil` in response otherwise.

  ## Examples

      iex> {:ok, _info} = Senzing.G2.Engine.replace_record(
      ...>   %{"RECORD_ID" => "test id"},
      ...>   "test id",
      ...>   "TEST",
      ...>   load_id: "test load",
      ...>   return_info: true
      ...> )
      iex> # info => %{
      ...> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      ...> #   "DATA_SOURCE" => "TEST",
      ...> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      ...> #   "RECORD_ID" => "test id"
      ...> # }
  """
  @doc type: :add_records
  @spec replace_record(
          record :: record(),
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [load_id: String.t(), return_info: boolean()]
        ) :: G2.result()
  def replace_record(record, record_id, data_source, opts \\ []) do
    with {:ok, info} <-
           Nif.replace_record(
             data_source,
             record_id,
             IO.iodata_to_binary(:json.encode(record)),
             opts[:load_id],
             opts[:return_info] || false
           ) do
      {:ok, :json.decode(info)}
    end
  end

  @doc """
  Reevaluate a record in the database.

  See https://docs.senzing.com/python/3/g2engine/reevaluating/index.html#reevaluaterecord

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      iex> {:ok, _info} = Senzing.G2.Engine.reevaluate_record("test id", "TEST", return_info: true)
      iex> # info => %{
      iex> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      iex> #   "DATA_SOURCE" => "TEST",
      iex> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      iex> #   "RECORD_ID" => "test id"
      iex> # }

  """
  @doc type: :reevaluating
  @spec reevaluate_record(record_id :: record_id(), data_source :: data_source(), opts :: [return_info: boolean()]) ::
          G2.result() | G2.result(map())
  def reevaluate_record(record_id, data_source, opts \\ []) do
    with {:ok, response} <- Nif.reevaluate_record(data_source, record_id, opts[:return_info] || false),
         do: {:ok, :json.decode(response)}
  end

  @doc """
  Reevaluate an entity in the database.

  See https://docs.senzing.com/python/3/g2engine/reevaluating/index.html#reevaluateentity

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      iex> # TODO: Use finished fn
      iex> {:ok, json} = Senzing.G2.Engine.Nif.get_entity_by_record_id("TEST", "test id")
      iex> %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}} = :json.decode(json)
      iex> :ok = Senzing.G2.Engine.reevaluate_entity(entity_id)
      iex> {:ok, %{"AFFECTED_ENTITIES" => [%{"ENTITY_ID" => ^entity_id}]}} =
      ...>   Senzing.G2.Engine.reevaluate_entity(entity_id, return_info: true)

  """
  @doc type: :reevaluating
  @spec reevaluate_entity(entity_id :: integer(), opts :: [return_info: boolean()]) :: G2.result() | G2.result(map())
  def reevaluate_entity(entity_id, opts \\ []) do
    with {:ok, response} <- Nif.reevaluate_entity(entity_id, opts[:return_info] || false),
         do: {:ok, :json.decode(response)}
  end

  @doc """
  Get the number of records contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#countredorecords

  ## Examples

      iex> {:ok, _count} = Senzing.G2.Engine.count_redo_records()
      iex> # count => 0
  """
  @doc type: :redo_processing
  @spec count_redo_records :: G2.result(integer())
  defdelegate count_redo_records, to: Nif

  @doc """
  Retrieve a record contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#getredorecord

  ## Examples

      iex> {:ok, record} = Senzing.G2.Engine.get_redo_record()
      iex> is_map(record) or is_nil(record)
      true

  """
  @doc type: :redo_processing
  @spec get_redo_record :: G2.result(redo_record() | nil)
  def get_redo_record do
    case Nif.get_redo_record() do
      {:ok, ""} -> {:ok, nil}
      {:ok, record} -> {:ok, :json.decode(record)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  This method will send a record for processing in g2.

  It is a synchronous call, i.e. it will wait until g2 actually processes the
  record, and then return any response message.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#process

  ## Examples

      iex> # TODO

  """
  @doc type: :redo_processing
  @spec process_redo_record(record :: redo_record(), opts :: [return_info: boolean()]) :: G2.result(map() | nil)
  def process_redo_record(record, opts \\ []) do
    with {:ok, info} <- Nif.process_redo_record(IO.iodata_to_binary(:json.encode(record)), opts[:return_info] || false),
         do: {:ok, :json.decode(info)}
  end

  @doc """
  Process a record contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#processredorecord

  ## Examples

      iex> {:ok, nil} = Senzing.G2.Engine.process_next_redo_record(return_info: true)

  """
  @doc type: :redo_processing
  @spec process_next_redo_record(opts :: [return_info: boolean()]) :: G2.result({map(), map()} | map() | nil)
  def process_next_redo_record(opts \\ []) do
    return_info = opts[:return_info] || false

    case Nif.process_next_redo_record(return_info) do
      {:ok, {"", ""}} when return_info -> {:ok, nil}
      {:ok, ""} when not return_info -> {:ok, nil}
      {:ok, {response, info}} when return_info -> {:ok, {:json.decode(response), :json.decode(info)}}
      {:ok, response} when not return_info -> {:ok, :json.decode(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  # This method will destroy and perform cleanup for the G2 processing object.
  #
  # It should be called after all other calls are complete.
  @doc false
  @impl ResourceInit
  @spec resource_destroy() :: G2.result()
  defdelegate resource_destroy, to: Nif, as: :destroy
end
