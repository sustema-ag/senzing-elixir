defmodule Senzing.G2.Engine do
  @moduledoc """
  G2 Engine NIF Functionality
  """

  @behaviour Senzing.G2.ResourceInit

  import Senzing.Bang
  import Senzing.G2.Error, only: [transform_result: 2]

  alias Senzing.G2
  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine.Flags
  alias Senzing.G2.Engine.Nif
  alias Senzing.G2.ResourceInit

  @type resource_init_option() ::
          {:verbose_logging, boolean()} | {:prime, boolean()} | {:config_id, integer()}
  @type resource_init_options() :: [resource_init_option()]

  flags_typespec =
    Flags.all()
    |> Enum.flat_map(fn flag -> [flag, :"no_#{flag}"] end)
    |> then(
      &[
        quote do
          integer()
        end
        | &1
      ]
    )
    |> Enum.reduce(&{:|, [], [&1, &2]})

  @typedoc """
  Flags to modify behaviour of function allowing the `flags` option.

  You can pass a list of flags or integers. All flags are then or'ed together.
  You can also pass a flag prefixed with `no_` to disable it.

  See https://docs.senzing.com/flags/
  """
  @type flag :: unquote(flags_typespec)

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

  @type entity() :: map()
  @type entity_id() :: pos_integer()

  @typedoc """
  Redo Record Specification

  ## Example

  ```elixir
  %{
    "DATA_SOURCE" => "TEST",
    "DSRC_ACTION" => "X",
    "ENTITY_TYPE" => "GENERIC",
    "REASON" => "LIB_FEAT_ID[132] of FTYPE_ID[75] went generic for CANDIDATES",
    "RECORD_ID" => "Z2YHHGKOZKXQ72CBID66"
  }
  ```
  """
  @type redo_record() :: map()

  @type data_source() :: String.t()

  @typedoc """
  Info from add / replace / delete record

  ## Example

  ```elixir
  %{
    "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
    "DATA_SOURCE" => "TEST",
    "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
    "RECORD_ID" => "one"
  }
  ```
  """
  @type mutation_info() :: map()

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
           name
           |> init.(
             IO.iodata_to_binary(:json.encode(config)),
             options[:verbose_logging] || false
           )
           |> transform_result(__MODULE__) do
      if options[:prime], do: prime(), else: :ok
    end
  end

  @doc """
  This method will re-initialize the G2 processing object.

  See https://docs.senzing.com/python/3/g2engine/init/#reinit

  ## Examples

      iex> {:ok, config} = Senzing.G2.Config.start_link([])
      ...> {:ok, config_json} = Senzing.G2.Config.save(config)
      ...> {:ok, config_id} = Senzing.G2.ConfigManager.add_config(config_json, comment: "comment")
      ...> Senzing.G2.Engine.reinit(config_id)
      :ok

  """
  @doc type: :initialization
  @spec reinit(config_id :: integer()) :: G2.result()
  def reinit(config_id), do: config_id |> Nif.reinit() |> transform_result(__MODULE__)

  @doc type: :initialization
  defbang reinit!(config_id)

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
  def prime, do: transform_result(Nif.prime(), __MODULE__)

  @doc type: :initialization
  defbang prime!()

  @doc """
  This method returns an identifier for the loaded G2 engine configuration.

  See https://docs.senzing.com/python/3/g2engine/init/#getactiveconfigid

  ## Examples

      iex> {:ok, id} = Senzing.G2.Engine.get_active_config_id()
      ...> is_integer(id)
      true

  """
  @doc type: :initialization
  @spec get_active_config_id() :: G2.result(ConfigManager.config_id())
  def get_active_config_id, do: transform_result(Nif.get_active_config_id(), __MODULE__)

  @doc type: :initialization
  defbang get_active_config_id!()

  @doc """
  This method will export the current configuration of the G2 engine.

  See https://docs.senzing.com/python/3/g2engine/init/#exportconfig

  ## Examples

      iex> {:ok, {config, config_id}} = Senzing.G2.Engine.export_config()
      ...> is_binary(config)
      true
      iex> is_integer(config_id)
      true

  """
  @doc type: :initialization
  @spec export_config() :: G2.result({Config.t(), ConfigManager.config_id()})
  def export_config, do: transform_result(Nif.export_config(), __MODULE__)

  @doc type: :initialization
  defbang export_config!()

  @doc """
  This method returns the date of when the entity datastore was last modified.

  See https://docs.senzing.com/python/3/g2engine/init/#getrepositorylastmodified

  ## Examples

      iex> {:ok, %DateTime{}} = Senzing.G2.Engine.get_repository_last_modified()
      ...> # {:ok, ~U[2024-04-02 11:23:14.613Z]}

  """
  @doc type: :initialization
  @spec get_repository_last_modified() :: G2.result(DateTime.t())
  def get_repository_last_modified do
    with {:ok, time} <- transform_result(Nif.get_repository_last_modified(), __MODULE__),
         do: DateTime.from_unix(time, :millisecond)
  end

  @doc type: :initialization
  defbang get_repository_last_modified!()

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

      iex> {:ok, {record_id, _info}} =
      ...>   Senzing.G2.Engine.add_record(
      ...>     %{"RECORD_ID" => "test id"},
      ...>     "TEST",
      ...>     load_id: "test load",
      ...>     record_id: "test id",
      ...>     return_info: true,
      ...>     return_record_id: true
      ...>   )
      ...> 
      ...> # info => %{
      ...> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      ...> #   "DATA_SOURCE" => "TEST",
      ...> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      ...> #   "RECORD_ID" => "test id"
      ...> # }
      ...> record_id
      "test id"
  """
  @doc type: :add_records
  @spec add_record(
          record :: record(),
          data_source :: data_source(),
          opts :: [
            load_id: String.t(),
            return_info: boolean(),
            return_record_id: boolean(),
            record_id: record_id()
          ]
        ) ::
          G2.result({record_id :: record_id() | nil, info :: mutation_info() | nil}) | G2.result()
  def add_record(record, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :add_record,
      data_source: data_source,
      record_id: opts[:record_id],
      load_id: opts[:load_id]
    }

    :telemetry.span([:telemetry, :g2, :engine, :write], telemetry_metadata, fn ->
      data_source
      |> Nif.add_record(
        opts[:record_id],
        IO.iodata_to_binary(:json.encode(record)),
        opts[:load_id],
        opts[:return_record_id] || false,
        opts[:return_info] || false
      )
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, {record_id, info}} ->
          {{:ok, {record_id, if(info, do: :json.decode(info))}},
           %{telemetry_metadata | record_id: record_id || opts[:record_id]}}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :add_records
  defbang add_record!(record, data_source, opts \\ [])

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

      iex> {:ok, _info} =
      ...>   Senzing.G2.Engine.replace_record(
      ...>     %{"RECORD_ID" => "test id"},
      ...>     "test id",
      ...>     "TEST",
      ...>     load_id: "test load",
      ...>     return_info: true
      ...>   )
      ...> 
      ...> # info => %{
      ...> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      ...> #   "DATA_SOURCE" => "TEST",
      ...> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      ...> #   "RECORD_ID" => "test id"
      ...> # }
  """
  @doc type: :replace_records
  @spec replace_record(
          record :: record(),
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [load_id: String.t(), return_info: boolean()]
        ) :: G2.result() | G2.result(mutation_info())
  def replace_record(record, record_id, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :replace_record,
      data_source: data_source,
      record_id: record_id,
      load_id: opts[:load_id]
    }

    :telemetry.span([:telemetry, :g2, :engine, :write], telemetry_metadata, fn ->
      data_source
      |> Nif.replace_record(
        record_id,
        IO.iodata_to_binary(:json.encode(record)),
        opts[:load_id],
        opts[:return_info] || false
      )
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, info} ->
          {{:ok, :json.decode(info)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :replace_records
  defbang replace_record!(record, record_id, data_source, opts \\ [])

  @doc """
  Reevaluate a record in the database.

  See https://docs.senzing.com/python/3/g2engine/reevaluating/index.html#reevaluaterecord

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> {:ok, _info} = Senzing.G2.Engine.reevaluate_record("test id", "TEST", return_info: true)
      ...> # info => %{
      ...> #   "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
      ...> #   "DATA_SOURCE" => "TEST",
      ...> #   "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
      ...> #   "RECORD_ID" => "test id"
      ...> # }

  """
  @doc type: :reevaluating
  @spec reevaluate_record(
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [return_info: boolean()]
        ) ::
          G2.result() | G2.result(mutation_info())
  def reevaluate_record(record_id, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :reevaluate_record,
      data_source: data_source,
      record_id: record_id
    }

    :telemetry.span([:telemetry, :g2, :engine, :reevaluate], telemetry_metadata, fn ->
      data_source
      |> Nif.reevaluate_record(record_id, opts[:return_info] || false)
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, info} ->
          {{:ok, :json.decode(info)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :reevaluating
  defbang reevaluate_record!(record_id, data_source, opts \\ [])

  @doc """
  Reevaluate an entity in the database.

  See https://docs.senzing.com/python/3/g2engine/reevaluating/index.html#reevaluateentity

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> 
      ...> {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
      ...>   Senzing.G2.Engine.get_entity_by_record_id("test id", "TEST")
      ...> 
      ...> :ok = Senzing.G2.Engine.reevaluate_entity(entity_id)
      ...> 
      ...> {:ok, %{"AFFECTED_ENTITIES" => [%{"ENTITY_ID" => ^entity_id}]}} =
      ...>   Senzing.G2.Engine.reevaluate_entity(entity_id, return_info: true)

  """
  @doc type: :reevaluating
  @spec reevaluate_entity(entity_id :: integer(), opts :: [return_info: boolean()]) ::
          G2.result() | G2.result(mutation_info())
  def reevaluate_entity(entity_id, opts \\ []) do
    telemetry_metadata = %{action: :reevaluate_entity, entity_id: entity_id}

    :telemetry.span([:telemetry, :g2, :engine, :reevaluate], telemetry_metadata, fn ->
      entity_id
      |> Nif.reevaluate_entity(opts[:return_info] || false)
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, info} ->
          {{:ok, :json.decode(info)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :reevaluating
  defbang reevaluate_entity!(entity_id, opts \\ [])

  @doc """
  Get the number of records contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#countredorecords

  ## Examples

      iex> {:ok, _count} = Senzing.G2.Engine.count_redo_records()
      ...> # count => 0
  """
  @doc type: :redo_processing
  @spec count_redo_records :: G2.result(integer())
  def count_redo_records, do: transform_result(Nif.count_redo_records(), __MODULE__)

  @doc type: :redo_processing
  defbang count_redo_records!()

  @doc """
  Retrieve a record contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#getredorecord

  ## Examples

      iex> {:ok, record} = Senzing.G2.Engine.get_redo_record()
      ...> is_map(record) or is_nil(record)
      true

  """
  @doc type: :redo_processing
  @spec get_redo_record :: G2.result(redo_record() | nil)
  def get_redo_record do
    Nif.get_redo_record()
    |> transform_result(__MODULE__)
    |> case do
      {:ok, ""} -> {:ok, nil}
      {:ok, record} -> {:ok, :json.decode(record)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc type: :redo_processing
  defbang get_redo_record!()

  @doc """
  This method will send a record for processing in g2.

  It is a synchronous call, i.e. it will wait until g2 actually processes the
  record, and then return any response message.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#process

  ## Examples

      iex> with {:ok, %{} = redo_record} <- Senzing.G2.Engine.get_redo_record(),
      ...>      {:ok, mutation_info} <- Senzing.G2.Engine.process_redo_record(redo_record) do
      ...>   # mutation_info => %{"AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}], ...}
      ...>   {:ok, mutation_info}
      ...> end

  """
  @doc type: :redo_processing
  @spec process_redo_record(record :: redo_record(), opts :: [return_info: boolean()]) ::
          G2.result(mutation_info())
  def process_redo_record(record, opts \\ []) do
    telemetry_metadata = %{action: :process_redo_record}

    :telemetry.span([:telemetry, :g2, :engine, :process_redo_record], telemetry_metadata, fn ->
      record
      |> :json.encode()
      |> IO.iodata_to_binary()
      |> Nif.process_redo_record(opts[:return_info] || false)
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, info} ->
          {{:ok, :json.decode(info)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :redo_processing
  defbang process_redo_record!(record, opts \\ [])

  @doc """
  Process a record contained in the internal redo-queue.

  See https://docs.senzing.com/python/3/g2engine/redo/index.html#processredorecord

  ## Examples

      iex> {:ok, _result} =
      ...>   Senzing.G2.Engine.process_next_redo_record(return_info: true)
      ...> 
      ...> # result => {
      ...> #   %{"DATA_SOURCE" => "TEST", ...}, # redo_record
      ...> #   %{"AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}], ...} # mutation_info
      ...> # }

  """
  @doc type: :redo_processing
  @spec process_next_redo_record(opts :: [return_info: boolean()]) ::
          G2.result({redo_record(), mutation_info()} | map() | nil)
  def process_next_redo_record(opts \\ []) do
    telemetry_metadata = %{action: :process_next_redo_record}

    :telemetry.span([:telemetry, :g2, :engine, :process_redo_record], telemetry_metadata, fn ->
      return_info = opts[:return_info] || false

      return_info
      |> Nif.process_next_redo_record()
      |> transform_result(__MODULE__)
      |> case do
        {:ok, {"", ""}} when return_info ->
          {{:ok, nil}, telemetry_metadata}

        {:ok, ""} when not return_info ->
          {{:ok, nil}, telemetry_metadata}

        {:ok, {response, info}} when return_info ->
          {{:ok, {:json.decode(response), :json.decode(info)}}, telemetry_metadata}

        {:ok, response} when not return_info ->
          {{:ok, :json.decode(response)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :redo_processing
  defbang process_next_redo_record!(opts \\ [])

  @doc """
  This method is used to delete observation data from the system.

  This removes a single entity observation record, by removing all of its
  feature data and the observation itself.

  See https://docs.senzing.com/python/3/g2engine/deleting/index.html#deleterecord

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> :ok = Senzing.G2.Engine.delete_record("test id", "TEST")

  """
  @doc type: :deleting_records
  @spec delete_record(
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [return_info: boolean(), load_id: String.t()]
        ) :: G2.result() | G2.result(mutation_info())
  def delete_record(record_id, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :delete_record,
      data_source: data_source,
      record_id: record_id,
      load_id: opts[:load_id]
    }

    :telemetry.span([:telemetry, :g2, :engine, :write], telemetry_metadata, fn ->
      data_source
      |> Nif.delete_record(record_id, opts[:load_id], opts[:return_info] || false)
      |> transform_result(__MODULE__)
      |> case do
        :ok ->
          {:ok, telemetry_metadata}

        {:ok, info} ->
          {{:ok, :json.decode(info)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :deleting_records
  defbang delete_record!(record_id, data_source, opts \\ [])

  @doc """
  This method is used to retrieve a stored record.

  See https://docs.senzing.com/python/3/g2engine/getting/index.html#getrecord

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> {:ok, _record} = Senzing.G2.Engine.get_record("test id", "TEST")
      ...> # record => %{"RECORD_ID" => "test id"}
  """
  @doc type: :getting_entities_and_records
  @spec get_record(
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [flags: flag() | [flag()]]
        ) ::
          G2.result(record())
  def get_record(record_id, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :get_record,
      data_source: data_source,
      record_id: record_id
    }

    flags = Flags.normalize(opts[:flags], :record_default_flags)

    :telemetry.span([:telemetry, :g2, :engine, :read], telemetry_metadata, fn ->
      data_source
      |> Nif.get_record(record_id, flags)
      |> transform_result(__MODULE__)
      |> case do
        {:ok, record} ->
          {{:ok, :json.decode(record)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :getting_entities_and_records
  defbang get_record!(record_id, data_source, opts \\ [])

  @doc """
  This method is used to retrieve information about a specific resolved entity.

  See https://docs.senzing.com/python/3/g2engine/getting/index.html#getentitybyrecordid

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> {:ok, _record} = Senzing.G2.Engine.get_entity_by_record_id("test id", "TEST")
      ...> # record => %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 1}}

  """
  @doc type: :getting_entities_and_records
  @spec get_entity_by_record_id(
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: []
        ) :: G2.result(entity())
  def get_entity_by_record_id(record_id, data_source, opts \\ []) do
    telemetry_metadata = %{
      action: :get_entity_by_record_id,
      data_source: data_source,
      record_id: record_id
    }

    flags = Flags.normalize(opts[:flags], :entity_default_flags)

    :telemetry.span([:telemetry, :g2, :engine, :read], telemetry_metadata, fn ->
      data_source
      |> Nif.get_entity_by_record_id(record_id, flags)
      |> transform_result(__MODULE__)
      |> case do
        {:ok, entity} ->
          {{:ok, :json.decode(entity)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :getting_entities_and_records
  defbang get_entity_by_record_id!(record_id, data_source, opts \\ [])

  @doc """
  This method is used to retrieve information about a specific resolved entity.

  See: https://docs.senzing.com/python/3/g2engine/getting/index.html#getentitybyentityid

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> 
      ...> {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
      ...>   Senzing.G2.Engine.get_entity_by_record_id("test id", "TEST")
      ...> 
      ...> {:ok, _record} = Senzing.G2.Engine.get_entity(entity_id)
      ...> # record => %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 7}}

  """
  @doc type: :getting_entities_and_records
  @spec get_entity(entity_id :: entity_id(), opts :: []) :: G2.result(entity())
  def get_entity(entity_id, opts \\ []) do
    telemetry_metadata = %{
      action: :get_entity,
      entity_id: entity_id
    }

    flags = Flags.normalize(opts[:flags], :entity_default_flags)

    :telemetry.span([:telemetry, :g2, :engine, :read], telemetry_metadata, fn ->
      entity_id
      |> Nif.get_entity(flags)
      |> transform_result(__MODULE__)
      |> case do
        {:ok, entity} ->
          {{:ok, :json.decode(entity)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :getting_entities_and_records
  defbang get_entity!(entity_id, opts \\ [])

  @doc """
  This method gives information on how an entity composed of a given set of records would look.

  See https://docs.senzing.com/python/3/g2engine/getting/index.html#getvirtualentitybyrecordid

  ## Examples

      iex> :ok = Senzing.G2.Engine.add_record(%{"RECORD_ID" => "test id"}, "TEST")
      ...> {:ok, _record} = Senzing.G2.Engine.get_virtual_entity([{"test id", "TEST"}])
      ...> # record => %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 1}}

  """
  @doc type: :getting_entities_and_records
  @spec get_virtual_entity(
          record_ids :: [{record_id(), data_source()}],
          opts :: [flags: flag() | [flag()]]
        ) ::
          G2.result(entity())
  def get_virtual_entity(record_ids, opts \\ []) do
    telemetry_metadata = %{action: :get_virtual_entity}

    flags = Flags.normalize(opts[:flags], :entity_default_flags)

    :telemetry.span([:telemetry, :g2, :engine, :read], telemetry_metadata, fn ->
      record_ids
      |> Enum.map(fn {id, data_source} -> %{"DATA_SOURCE" => data_source, "RECORD_ID" => id} end)
      |> then(&%{"RECORDS" => &1})
      |> :json.encode()
      |> IO.iodata_to_binary()
      |> Nif.get_virtual_entity(flags)
      |> transform_result(__MODULE__)
      |> case do
        {:ok, record} ->
          {{:ok, :json.decode(record)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :getting_entities_and_records
  defbang get_virtual_entity!(record_ids, opts \\ [])

  @doc """
  This method searches for entities that contain attribute information that are
  relevant to a set of input search attributes.

  See https://docs.senzing.com/python/3/g2engine/searching/index.html#searchbyattributesv3

  ## Examples

      iex> {:ok, _entities} = Senzing.G2.Engine.search_by_attributes(%{"NAME" => "APPLE"})
      ...> # entities => {:ok, %{"RESOLVED_ENTITIES" => [
      ...> #   %{"ENTITY" => %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}}
      ...> # ]}}

  """
  @doc type: :searching_for_entities
  @spec search_by_attributes(
          attributes :: map(),
          opts :: [flags: flag() | [flag()], search_profile: String.t()]
        ) :: G2.result(map())
  def search_by_attributes(attributes, opts \\ []) do
    search_profile = opts[:search_profile] || "SEARCH"
    flags = Flags.normalize(opts[:flags], :search_by_attributes_default_flags)

    telemetry_metadata = %{search_profile: search_profile}

    :telemetry.span([:telemetry, :g2, :engine, :search], telemetry_metadata, fn ->
      attributes
      |> :json.encode()
      |> IO.iodata_to_binary()
      |> Nif.search_by_attributes(search_profile, flags)
      |> transform_result(__MODULE__)
      |> case do
        {:ok, response} ->
          {{:ok, :json.decode(response)}, telemetry_metadata}

        {:error, reason} ->
          {{:error, reason}, telemetry_metadata}
      end
    end)
  end

  @doc type: :searching_for_entities
  defbang search_by_attributes!(attributes, opts \\ [])

  @doc """
  This method is used to find a relationship path between entities.

  See https://docs.senzing.com/python/3/g2engine/finding_paths/index.html#findpathbyentityid

  ## Examples

      iex> _result = Senzing.G2.Engine.find_path_by_entity_id(1, 2, 10)
      ...> # result => {:ok, %{"ENTITY_PATHS" => [%{"ENTITIES" => [1, 2]}]}}

  """
  @doc type: :finding_paths
  @spec find_path_by_entity_id(
          start_entity_id :: entity_id(),
          end_entity_id :: entity_id(),
          max_degree :: pos_integer(),
          opts :: [
            flags: flag() | [flag()],
            exclude: [entity_id],
            included_data_sources: [data_source()]
          ]
        ) :: G2.result(map())
  def find_path_by_entity_id(start_entity_id, end_entity_id, max_degree, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :find_path_default_flags)

    exclude =
      opts
      |> Keyword.fetch(:exclude)
      |> case do
        :error ->
          nil

        {:ok, exclude} ->
          exclude
          |> Enum.map(&%{"ENTITY_ID" => &1})
          |> then(&%{"ENTITIES" => &1})
          |> :json.encode()
          |> IO.iodata_to_binary()
      end

    included_data_sources =
      opts
      |> Keyword.fetch(:included_data_sources)
      |> case do
        :error ->
          nil

        {:ok, data_sources} ->
          data_sources
          |> then(&%{"DATA_SOURCES" => &1})
          |> :json.encode()
          |> IO.iodata_to_binary()
      end

    with {:ok, response} <-
           start_entity_id
           |> Nif.find_path_by_entity_id(
             end_entity_id,
             max_degree,
             flags,
             exclude,
             included_data_sources
           )
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :finding_paths
  defbang find_path_by_entity_id!(start_entity_id, end_entity_id, max_degree, opts \\ [])

  @doc """
  This method is used to find a relationship path between records.

  See https://docs.senzing.com/python/3/g2engine/finding_paths/index.html#findpathbyrecordid

  ## Examples

      iex> _result =
      ...>   Senzing.G2.Engine.find_path_by_record_id(
      ...>     {"test id 1", "TEST"},
      ...>     {"test id 2", "TEST"},
      ...>     10
      ...>   )
      ...> 
      ...> # result => {:ok, %{"ENTITY_PATHS" => [%{"ENTITIES" => [1, 2]}]}}

  """
  @doc type: :finding_paths
  @spec find_path_by_record_id(
          start_record :: {record_id(), data_source()},
          end_record :: {record_id(), data_source()},
          max_degree :: pos_integer(),
          opts :: [
            flags: flag() | [flag()],
            exclude: [{record_id(), data_source()}],
            included_data_sources: [data_source()]
          ]
        ) :: G2.result(map())
  def find_path_by_record_id(start_record, end_record, max_degree, opts \\ []) do
    {start_record_id, start_record_data_source} = start_record
    {end_record_id, end_record_data_source} = end_record

    flags = Flags.normalize(opts[:flags], :find_path_default_flags)

    exclude =
      opts
      |> Keyword.fetch(:exclude)
      |> case do
        :error ->
          nil

        {:ok, exclude} ->
          exclude
          |> Enum.map(fn {record_id, data_source} ->
            %{"DATA_SOURCE" => data_source, "RECORD_ID" => record_id}
          end)
          |> then(&%{"RECORDS" => &1})
          |> :json.encode()
          |> IO.iodata_to_binary()
      end

    included_data_sources =
      opts
      |> Keyword.fetch(:included_data_sources)
      |> case do
        :error ->
          nil

        {:ok, data_sources} ->
          data_sources
          |> then(&%{"DATA_SOURCES" => &1})
          |> :json.encode()
          |> IO.iodata_to_binary()
      end

    with {:ok, response} <-
           start_record_id
           |> Nif.find_path_by_record_id(
             start_record_data_source,
             end_record_id,
             end_record_data_source,
             max_degree,
             flags,
             exclude,
             included_data_sources
           )
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :finding_paths
  defbang find_path_by_record_id!(start_record, end_record, max_degree, opts \\ [])

  @doc """
  This method is used to find a network of entity relationships, surrounding the
  paths between a set of entities.

  See https://docs.senzing.com/python/3/g2engine/finding_networks/index.html#finding-networks

  ## Examples

      iex> _result = Senzing.G2.Engine.find_network_by_entity_id([1, 2, 3], max_degree: 3)
      ...> # result => {:ok, %{
      ...> #   "ENTITIES" => [
      ...> #     %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 1}},
      ...> #     %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 2}},
      ...> #     %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 3}}
      ...> #   ]
      ...> # }}

  """
  @doc type: :finding_networks
  @spec find_network_by_entity_id(
          entity_ids :: [entity_id()],
          opts :: [
            max_degree: pos_integer(),
            buildout_degree: pos_integer(),
            max_entities: pos_integer(),
            flags: flag() | [flag()]
          ]
        ) :: G2.result(map())
  def find_network_by_entity_id(entity_ids, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :find_path_default_flags)

    entity_ids =
      entity_ids
      |> Enum.map(&%{"ENTITY_ID" => &1})
      |> then(&%{"ENTITIES" => &1})
      |> :json.encode()
      |> IO.iodata_to_binary()

    with {:ok, response} <-
           entity_ids
           |> Nif.find_network_by_entity_id(
             opts[:max_degree] || 3,
             opts[:buildout_degree] || 10,
             opts[:max_entities] || 100,
             flags
           )
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :finding_networks
  defbang find_network_by_entity_id!(entity_ids, opts \\ [])

  @doc """
  This method is used to find a network of entity relationships, surrounding the
  paths between a set of records.

  See https://docs.senzing.com/python/3/g2engine/finding_networks/index.html#findnetworkbyrecordid

  ## Examples

      iex> _result =
      ...>   Senzing.G2.Engine.find_network_by_record_id(
      ...>     [{"test id 1", "TEST"}, {"test id 2", "TEST"}],
      ...>     max_degree: 3
      ...>   )
      ...> 
      ...> # result => {:ok, %{
      ...> #   "ENTITIES" => [
      ...> #     %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 1}},
      ...> #     %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => 2}}
      ...> #   ]
      ...> # }}

  """
  @doc type: :finding_networks
  @spec find_network_by_record_id(
          record_ids :: [{record_id(), data_source()}],
          opts :: [
            max_degree: pos_integer(),
            buildout_degree: pos_integer(),
            max_entities: pos_integer(),
            flags: flag() | [flag()]
          ]
        ) :: G2.result(map())
  def find_network_by_record_id(record_ids, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :find_path_default_flags)

    record_ids =
      record_ids
      |> Enum.map(fn {record_id, data_source} ->
        %{"DATA_SOURCE" => data_source, "RECORD_ID" => record_id}
      end)
      |> then(&%{"RECORDS" => &1})
      |> :json.encode()
      |> IO.iodata_to_binary()

    with {:ok, response} <-
           record_ids
           |> Nif.find_network_by_record_id(
             opts[:max_degree] || 3,
             opts[:buildout_degree] || 10,
             opts[:max_entities] || 100,
             flags
           )
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :finding_networks
  defbang find_network_by_record_id!(record_ids, opts \\ [])

  @doc """
  This method determines how records are related to each other.

  See https://docs.senzing.com/python/3/g2engine/why/index.html#whyrecords

  ## Examples

      iex> _result =
      ...>   Senzing.G2.Engine.why_records(
      ...>     {"test id 1", "TEST"},
      ...>     {"test id 2", "TEST"}
      ...>   )
      ...> 
      ...> # result => {
      ...> #   :ok,
      ...> #   %{
      ...> #     "WHY_RESULTS" => [
      ...> #       %{
      ...> #         "ENTITY_ID" => ^entity_id_one,
      ...> #         "ENTITY_ID_2" => ^entity_id_two,
      ...> #         "FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_one}],
      ...> #         "FOCUS_RECORDS_2" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_two}]
      ...> #       }
      ...> #     ]
      ...> #   }
      ...> # }

  """
  @doc type: :why
  @spec why_records(
          left_record :: {record_id(), data_source()},
          right_record :: {record_id(), data_source()},
          opts :: [flags: flag() | [flag()]]
        ) :: G2.result(map())
  def why_records(left_record, right_record, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :why_entity_default_flags)

    {left_record_id, left_data_source} = left_record
    {right_record_id, right_data_source} = right_record

    with {:ok, response} <-
           left_record_id
           |> Nif.why_records(
             left_data_source,
             right_record_id,
             right_data_source,
             flags
           )
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :why
  defbang why_records!(left_record, right_record, opts \\ [])

  @doc """
  This method determines why records are included in the resolved entity they belong to.

  See https://docs.senzing.com/python/3/g2engine/why/index.html#whyentitybyrecordid

  ## Examples

      iex> _result = Senzing.G2.Engine.why_entity_by_record_id("record one", "TEST")
      ...> # result => {:ok, %{"WHY_RESULTS" => [
      ...> #   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record one"}]},
      ...> #   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record two"}]}
      ...> # ]}}

  """
  @doc type: :why
  @spec why_entity_by_record_id(
          record_id :: record_id(),
          data_source :: data_source(),
          opts :: [flags: flag() | [flag()]]
        ) :: G2.result(map())
  def why_entity_by_record_id(record_id, data_source, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :why_entity_default_flags)

    with {:ok, response} <-
           record_id
           |> Nif.why_entity_by_record_id(data_source, flags)
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :why
  defbang why_entity_by_record_id!(record_id, data_source, opts \\ [])

  @doc """
  This method determines why records are included in the resolved entity they belong to.

  See https://docs.senzing.com/python/3/g2engine/why/index.html#whyentitybyentityid

  ## Examples

      iex> _result = Senzing.G2.Engine.why_entity_by_entity_id(1)
      ...> # result => {:ok, %{"WHY_RESULTS" => [
      ...> #   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record one"}]},
      ...> #   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record two"}]}
      ...> # ]}}

  """
  @doc type: :why
  @spec why_entity_by_entity_id(
          entity_id :: entity_id(),
          opts :: [flags: flag() | [flag()]]
        ) :: G2.result(map())
  def why_entity_by_entity_id(entity_id, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :why_entity_default_flags)

    with {:ok, response} <-
           entity_id |> Nif.why_entity_by_entity_id(flags) |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :why
  defbang why_entity_by_entity_id!(entity_id, opts \\ [])

  @doc """
  This method determines how entities are related to each other.

  See https://docs.senzing.com/python/3/g2engine/why/index.html#whyentities

  ## Examples

      iex> _result = Senzing.G2.Engine.why_entities(1, 2)
      ...> # result => {:ok, %{"WHY_RESULTS" => [
      ...> #   %{"ENTITY_ID" => 1, "ENTITY_ID_2" => 2}
      ...> # ]}}

  """
  @doc type: :why
  @spec why_entities(
          left_entity_id :: entity_id(),
          right_entity_id :: entity_id(),
          opts :: [flags: flag() | [flag()]]
        ) :: G2.result(map())
  def why_entities(left_entity_id, right_entity_id, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :why_entity_default_flags)

    with {:ok, response} <-
           left_entity_id
           |> Nif.why_entities(right_entity_id, flags)
           |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :why
  defbang why_entities!(left_entity_id, right_entity_id, opts \\ [])

  @doc """
  This method gives information on how entities were constructed from their base records.

  See https://docs.senzing.com/python/3/g2engine/how/index.html#howentitybyentityid

  ## Examples

      iex> _result = Senzing.G2.Engine.how_entity_by_entity_id(1)
      ...> # result => {
      ...> #   :ok,
      ...> #   %{
      ...> #     "HOW_RESULTS" => %{
      ...> #       "FINAL_STATE" => %{
      ...> #         "VIRTUAL_ENTITIES" => [
      ...> #           %{
      ...> #             "MEMBER_RECORDS" => [
      ...> #               %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record one"}]},
      ...> #               %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "record two}]}
      ...> #             ]
      ...> #           }
      ...> #         ]
      ...> #       },
      ...> #       "RESOLUTION_STEPS" => [%{"MATCH_INFO" => %{"MATCH_KEY" => "+NAME+TRUSTED_ID"}}]
      ...> #     }
      ...> #   }
      ...> # }

  """
  @doc type: :how
  @spec how_entity_by_entity_id(
          entity_id :: entity_id(),
          opts :: [flags: flag() | [flag()]]
        ) :: G2.result(map())
  def how_entity_by_entity_id(entity_id, opts \\ []) do
    flags = Flags.normalize(opts[:flags], :how_entity_default_flags)

    with {:ok, response} <-
           entity_id |> Nif.how_entity_by_entity_id(flags) |> transform_result(__MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :how
  defbang how_entity_by_entity_id!(entity_id, opts \\ [])

  @default_export_csv_entity_report_column_list [
    "RESOLVED_ENTITY_ID",
    "RESOLVED_ENTITY_NAME",
    "RELATED_ENTITY_ID",
    "MATCH_LEVEL",
    "MATCH_KEY",
    "IS_DISCLOSED",
    "IS_AMBIGUOUS",
    "DATA_SOURCE",
    "RECORD_ID",
    "JSON_DATA",
    "LAST_SEEN_DT",
    "NAME_DATA",
    "ATTRIBUTE_DATA",
    "IDENTIFIER_DATA",
    "ADDRESS_DATA",
    "PHONE_DATA",
    "RELATIONSHIP_DATA",
    "ENTITY_DATA",
    "OTHER_DATA"
  ]

  @doc """
  This is used to export entity data from known entities.

  This function returns an export-stream that can be read from to get the export
  data in CSV format.

  > #### Production Use {:.warning}
  >
  > This function is not recommended for large systems as it does not scale. It
  > is recommended larger systems implement real-time replication to a data
  > warehouse.

  See https://docs.senzing.com/python/3/g2engine/reporting/index.html#exportcsventityreport

  ## Example

      iex> stream = Senzing.G2.Engine.export_csv_entity_report(["RECORD_ID"])
      ...> Enum.take(stream, 5)
      ...> # ["RECORD_ID\\n",
      ...> #  "\\"one\\"\\n",
      ...> #  "\\"two\\"\\n",
      ...> #  "\\"three\\"\\n",
      ...> #  "\\"four\\"\\n"]

  """
  @doc type: :reporting
  @spec export_csv_entity_report(column_list :: [String.t()], opts :: [flags: flag() | [flag()]]) ::
          Enumerable.t(String.t())
  def export_csv_entity_report(column_list \\ @default_export_csv_entity_report_column_list, opts \\ []) do
    column_list = Enum.join(column_list, ",")

    flags = Flags.normalize(opts[:flags], :export_default_flags)

    Stream.resource(
      fn ->
        column_list
        |> Nif.export_csv_entity_report(flags)
        |> transform_result(__MODULE__)
        |> case do
          {:ok, handle} -> handle
          {:error, reason} -> raise reason
        end
      end,
      fn handle ->
        handle
        |> Nif.export_fetch_next()
        |> transform_result(__MODULE__)
        |> case do
          {:ok, :eof} -> {:halt, handle}
          {:ok, data} -> {[data], handle}
          {:error, reason} -> raise reason
        end
      end,
      fn handle ->
        handle
        |> Nif.export_close()
        |> transform_result(__MODULE__)
        |> case do
          :ok -> :ok
          {:error, reason} -> raise reason
        end
      end
    )
  end

  @doc """
  This is used to export entity data from known entities.

  This function returns an export-stream that can be read from to get the export
  data in JSON format.

  > #### Production Use {:.warning}
  >
  > This function is not recommended for large systems as it does not scale. It
  > is recommended larger systems implement real-time replication to a data
  > warehouse.

  See https://docs.senzing.com/python/3/g2engine/reporting/index.html#exportjsonentityreport

  ## Example

      iex> stream = Senzing.G2.Engine.export_json_entity_report()
      ...> Enum.into(stream, "")
      ...> # "{\\"RESOLVED_ENTITY\\":{\\"ENTITY_ID\\":1}}\\n"
  """
  @doc type: :reporting
  @spec export_json_entity_report(opts :: [flags: flag() | [flag()]]) :: Enumerable.t(map())
  def export_json_entity_report(opts \\ []) do
    flags = Flags.normalize(opts[:flags], :export_default_flags)

    Stream.resource(
      fn ->
        flags
        |> Nif.export_json_entity_report()
        |> transform_result(__MODULE__)
        |> case do
          {:ok, handle} -> handle
          {:error, reason} -> raise reason
        end
      end,
      fn handle ->
        handle
        |> Nif.export_fetch_next()
        |> transform_result(__MODULE__)
        |> case do
          {:ok, :eof} -> {:halt, handle}
          {:ok, data} -> {[data], handle}
          {:error, reason} -> raise reason
        end
      end,
      fn handle ->
        handle
        |> Nif.export_close()
        |> transform_result(__MODULE__)
        |> case do
          :ok -> :ok
          {:error, reason} -> raise reason
        end
      end
    )
  end

  @doc """
  This is used to purge all data from an existing repository

  See https://docs.senzing.com/python/3/g2engine/cleanup/index.html#purgerepository

  ## Examples

      iex> Senzing.G2.Engine.purge_repository()
      :ok

  """
  @doc type: :cleanup
  @spec purge_repository() :: G2.result()
  def purge_repository, do: transform_result(Nif.purge_repository(), __MODULE__)

  @doc type: :cleanup
  defbang purge_repository!()

  @doc """
  This method returns a JSON document that provides basic statistics on the requests made through the G2 object.

  It returns things such as the * number of records loaded, the duration of
  processing time, the number of retries made, etc.

  See https://docs.senzing.com/python/3/g2engine/stats/index.html#stats

  ## Examples

      iex> Senzing.G2.Engine.stats()
      ...> # {:ok, %{"workload" => %{"addedRecords" => 1, ...}, ...}}

  """
  @doc type: :statistics
  @spec stats() :: G2.result(map())
  def stats do
    with {:ok, response} <- transform_result(Nif.stats(), __MODULE__),
         do: {:ok, :json.decode(response)}
  end

  @doc type: :statistics
  defbang stats!()

  # This method will destroy and perform cleanup for the G2 processing object.
  #
  # It should be called after all other calls are complete.
  @doc false
  @impl ResourceInit
  @spec resource_destroy() :: G2.result()
  def resource_destroy, do: transform_result(Nif.destroy(), __MODULE__)
end
