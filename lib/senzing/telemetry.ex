defmodule Senzing.Telemetry do
  @moduledoc false

  use TelemetryRegistry
  use Supervisor

  alias Senzing.G2.Engine

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :workload],
    description: "momentary Senzing workload",
    measurements: """
    %{
      added_records: non_neg_integer(),
      deleted_records: non_neg_integer(),
      reevaluations: non_neg_integer(),
      repaired_entities: non_neg_integer()
    }\
    """,
    metadata: "%{api_version: String.t()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :threads],
    description: "momentary Senzing workload",
    measurements: """
    %{
      active: non_neg_integer(),
      data_latch_contention: non_neg_integer(),
      idle: non_neg_integer(),
      loader: non_neg_integer(),
      obs_ent_contention: non_neg_integer(),
      res_ent_contention: non_neg_integer(),
      resolver: non_neg_integer(),
      scoring: non_neg_integer(),
      sql_executing: non_neg_integer()
    }\
    """,
    metadata: "%{api_version: String.t()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :redo_records],
    description: "momentary Senzing redo backlog",
    measurements: "%{count: non_neg_integer()}",
    metadata: "%{}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :config],
    description: "momentary Senzing redo backlog",
    measurements: "%{}",
    metadata: "%{config: Senzing.G2.ConfigManager.config_id()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :write, :start],
    description: "emitted when starting to write a record",
    measurements: "%{}",
    metadata:
      "%{action: :add_record | :replace_record | :delete_record, data_source: String.t(), load_id: String.t() | nil, record_id: String.t() | nil}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :write, :stop],
    description: "emitted when the writing of a record is finished",
    measurements: "%{duration: non_neg_integer()}",
    metadata:
      "%{action: :add_record | :replace_record | :delete_record, data_source: String.t(), load_id: String.t() | nil, record_id: String.t() | nil}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :reevaluate, :start],
    description: "emitted when starting to reevaluate a record or an entity",
    measurements: "%{}",
    metadata:
      "%{action: :reevaluate_record, data_source: String.t(), record_id: String.t()} | %{action: :reevaluate_entity, entity_id: integer()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :reevaluate, :stop],
    description: "emitted when the reevaluation of a record or an entity is finished",
    measurements: "%{duration: non_neg_integer()}",
    metadata:
      "%{action: :reevaluate_record, data_source: String.t(), record_id: String.t()} | %{action: :reevaluate_entity, entity_id: integer()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :process_redo_record, :start],
    description: "emitted when starting to process a redo record",
    measurements: "%{}",
    metadata: "%{action: :process_redo_record | :process_next_redo_record}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :process_redo_record, :stop],
    description: "emitted when the processing of a redo record finished",
    measurements: "%{duration: non_neg_integer()}",
    metadata: "%{action: :process_redo_record | :process_next_redo_record}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :read, :start],
    description: "emitted when starting to read a record or an entity",
    measurements: "%{}",
    metadata:
      "%{action: :get_record | :get_entity_by_record_id, data_source: String.t(), record_id: String.t()} | %{action: :get_entity, entity_id: integer()} | %{action: :get_virtual_entity}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :read, :stop],
    description: "emitted when the reading of a record or an entity finished",
    measurements: "%{duration: non_neg_integer()}",
    metadata:
      "%{action: :get_record | :get_entity_by_record_id, data_source: String.t(), record_id: String.t()} | %{action: :get_entity, entity_id: integer()} | %{action: :get_virtual_entity}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :search, :start],
    description: "emitted when starting to search an entity",
    measurements: "%{}",
    metadata: "%{search_profile: String.t()}"
  })

  telemetry_event(%{
    event: [:senzing, :g2, :engine, :search, :stop],
    description: "emitted when the searching of an entity finished",
    measurements: "%{duration: non_neg_integer()}",
    metadata: "%{search_profile: String.t()}"
  })

  # Using function to avoid problem with `styler` reordering
  Module.put_attribute(
    __MODULE__,
    :moduledoc,
    {__ENV__.line,
     """
     Senzing Telemetry

     ## Events

     #{telemetry_docs()}
     """}
  )

  @doc false
  @spec start_link(args :: Keyword.t()) :: Supervisor.on_start()
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @doc false
  @impl Supervisor
  def init(_arg) do
    Supervisor.init(
      [
        {:telemetry_poller,
         measurements: [
           {__MODULE__, :workload, []},
           {__MODULE__, :redo_records, []},
           {__MODULE__, :config, []}
         ],
         name: __MODULE__.Poller}
      ],
      strategy: :one_for_one
    )
  end

  @doc false
  @spec workload() :: :ok
  def workload do
    with {:ok,
          %{
            "workload" => %{
              "addedRecords" => added_records,
              "reevaluations" => reevaluations,
              "deletedRecords" => deleted_records,
              "apiVersion" => api_version,
              "repairedEntities" => repaired_entities,
              "threadState" => %{
                "active" => threads_active,
                "dataLatchContention" => threads_data_latch_contention,
                "idle" => threads_idle,
                "loader" => threads_loader,
                "obsEntContention" => threads_obs_ent_contention,
                "resEntContention" => threads_res_ent_contention,
                "resolver" => threads_resolver,
                "scoring" => threads_scoring,
                "sqlExecuting" => threads_sql_executing
              }
            }
          }} <- Engine.stats() do
      :telemetry.execute(
        [:senzing, :g2, :engine, :workload],
        %{
          added_records: added_records,
          reevaluations: reevaluations,
          deleted_records: deleted_records,
          repaired_entities: repaired_entities
        },
        %{
          api_version: api_version
        }
      )

      :telemetry.execute(
        [:senzing, :g2, :engine, :threads],
        %{
          active: threads_active,
          data_latch_contention: threads_data_latch_contention,
          idle: threads_idle,
          loader: threads_loader,
          obs_ent_contention: threads_obs_ent_contention,
          res_ent_contention: threads_res_ent_contention,
          resolver: threads_resolver,
          scoring: threads_scoring,
          sql_executing: threads_sql_executing
        },
        %{
          api_version: api_version
        }
      )
    end
  end

  @doc false
  @spec redo_records :: :ok
  def redo_records do
    with {:ok, count} <- Engine.count_redo_records() do
      :telemetry.execute(
        [:senzing, :g2, :engine, :redo_records],
        %{count: count},
        %{}
      )
    end
  end

  @doc false
  @spec config :: :ok
  def config do
    with {:ok, id} <- Engine.get_active_config_id() do
      :telemetry.execute(
        [:senzing, :g2, :engine, :config],
        %{},
        %{config: id}
      )
    end
  end
end
