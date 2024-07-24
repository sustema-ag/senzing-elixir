with {:module, GenStage} <- Code.ensure_loaded(GenStage) do
  defmodule Senzing.G2.Engine.Publisher do
    @moduledoc """
    Record Publisher

    The record publisher will consume events and publish them to the Senzing G2
    Engine.

    See `t:event/0` for the types of events that can be consumed.

    If the `produce_change_events` option is set to `true`, the publisher will
    re-emit the results of each applied event. This is especially useful if you
    want to keep track of the changes of entities that are applied by the engine.

    > #### Availability {:.info}
    >
    > The Publisher is only available if `gen_stage` was added as a dependency.

    > #### Async {:.warning}
    >
    > The events are applied asynchronously and possibly out of order.
    """
    use GenStage

    alias Senzing.G2
    alias Senzing.G2.Engine

    @enforce_keys [:concurrency, :produce_change_events, :call_wrapper, :event_timeout]
    defstruct @enforce_keys

    @typep t() :: %__MODULE__{
             produce_change_events: boolean(),
             concurrency: pos_integer(),
             call_wrapper: call_wrapper_function(term()) | nil,
             event_timeout: non_neg_integer()
           }

    @type add_event(correlation) :: %{
            required(:action) => :add,
            required(:data_source) => Engine.data_source(),
            required(:record) => Engine.record(),
            optional(:record_id) => Engine.record_id(),
            optional(:load_id) => String.t(),
            optional(:correlation) => correlation
          }
    @type replace_event(correlation) :: %{
            required(:action) => :replace,
            required(:data_source) => Engine.data_source(),
            required(:record_id) => Engine.record_id(),
            required(:record) => Engine.record(),
            optional(:load_id) => String.t(),
            optional(:correlation) => correlation
          }
    @type delete_event(correlation) :: %{
            required(:action) => :delete,
            required(:data_source) => Engine.data_source(),
            required(:record_id) => Engine.record_id(),
            optional(:load_id) => String.t(),
            optional(:correlation) => correlation
          }
    @type reevaluate_record_event(correlation) :: %{
            required(:action) => :reevaluate_record,
            required(:data_source) => Engine.data_source(),
            required(:record_id) => Engine.record_id(),
            optional(:correlation) => correlation
          }
    @type reevaluate_entity_event(correlation) :: %{
            required(:action) => :reevaluate_entity,
            required(:entity_id) => Engine.entity_id(),
            optional(:correlation) => correlation
          }
    @type event(correlation) ::
            add_event(correlation)
            | replace_event(correlation)
            | delete_event(correlation)
            | reevaluate_record_event(correlation)
            | reevaluate_entity_event(correlation)
    @type event() :: event(term())

    @type out_event(correlation) :: %{
            required(:mutation) => Engine.mutation_info(),
            optional(:correlation) => correlation
          }
    @type out_event() :: out_event(term())

    @opaque wrapper_result() :: G2.result() | G2.result(term())
    @type call_wrapper_function(result) :: ((-> result) -> result)
    @type call_wrapper_function() :: call_wrapper_function(wrapper_result())

    @typedoc """
    Configuration Options for the publisher

    ## Options

    * `:name` - `GenStage` name
    * `:produce_change_events` - If `true`, the publisher will re-emit the results
      of each applied event
    * `:consumer_options` - `GenStage` consumer options
      (if `produce_change_events` is `false`)
    * `:producer_consumer_options` - `GenStage` producer and producer consumer
      options (if `produce_change_events` is `true`)
    * `:call_wrapper` - A function that wraps the call to the engine. This can be
      useful to execute the engine call in a different context. For example
      through [`flame`](https://hex.pm/packages/flame)
    * `:event_timeout` - Timeout for each event
    """
    @type option() ::
            {:produce_change_events, boolean()}
            | {:consumer_options, [GenStage.consumer_option()]}
            | {:producer_consumer_options, [GenStage.producer_and_producer_consumer_option()]}
            | {:call_wrapper, call_wrapper_function()}
            | {:event_timeout, non_neg_integer()}
            | GenServer.option()
    @type options() :: [option()]

    @typep init_options() :: %{
             produce_change_events: boolean(),
             concurrency: pos_integer(),
             consumer_options: [GenStage.consumer_option()],
             producer_consumer_options: [GenStage.producer_and_producer_consumer_option()],
             call_wrapper: call_wrapper_function() | nil,
             event_timeout: non_neg_integer()
           }

    @spec start_link(options :: options()) :: GenServer.on_start()
    def start_link(options \\ []) do
      {init_options, start_options} = extract_options(options)

      GenStage.start_link(__MODULE__, init_options, start_options)
    end

    @impl GenStage
    def init(%{producer_consumer_options: producer_consumer_options, consumer_options: consumer_options} = options) do
      state = build_state(options)

      if state.produce_change_events,
        do: {:producer_consumer, state, producer_consumer_options},
        else: {:consumer, state, consumer_options}
    end

    @impl GenStage
    def handle_events(
          events,
          _from,
          %__MODULE__{concurrency: concurrency, produce_change_events: false, event_timeout: event_timeout} = state
        ) do
      events
      |> Task.async_stream(
        &handle_event(&1, state),
        timeout: event_timeout,
        max_concurrency: concurrency,
        ordered: false
      )
      |> Stream.run()

      {:noreply, [], state}
    end

    def handle_events(
          events,
          _from,
          %__MODULE__{concurrency: concurrency, produce_change_events: true, event_timeout: event_timeout} = state
        ) do
      events =
        events
        |> Task.async_stream(
          fn event ->
            case handle_event(event, state) do
              # add
              {:ok, {nil, mutation}} ->
                {:ok, %{mutation: mutation, correlation: event[:correlation]}}

              # replace / delete
              {:ok, mutation} ->
                {:ok, %{mutation: mutation, correlation: event[:correlation]}}

              {:error, reason} ->
                {:error, reason}
            end
          end,
          timeout: event_timeout,
          max_concurrency: concurrency,
          ordered: false
        )
        |> Stream.map(fn
          {:ok, {:ok, result}} -> result
          {:ok, {:error, reason}} -> raise reason
          {:error, reason} -> raise reason
        end)
        |> Enum.to_list()

      {:noreply, events, state}
    end

    @start_options [
      :name,
      :debug,
      :timeout,
      :spawn_opt,
      :hibernate_after
    ]
    @init_options [
      :produce_change_events,
      :concurrency,
      :consumer_options,
      :producer_consumer_options,
      :call_wrapper,
      :event_timeout
    ]

    @spec extract_options(options :: options()) ::
            {init_options :: init_options(), start_options :: Keyword.t()}
    defp extract_options(options) do
      options =
        Keyword.validate!(
          options,
          @start_options ++
            [
              produce_change_events: false,
              concurrency: System.schedulers(),
              consumer_options: [],
              producer_consumer_options: [],
              call_wrapper: nil,
              event_timeout: :timer.seconds(5)
            ]
        )

      {options |> Keyword.take(@init_options) |> Map.new(), Keyword.take(options, @start_options)}
    end

    @spec build_state(options :: init_options()) :: t()
    defp build_state(%{
           produce_change_events: produce_change_events,
           concurrency: concurrency,
           call_wrapper: call_wrapper,
           event_timeout: event_timeout
         }) do
      %__MODULE__{
        produce_change_events: produce_change_events,
        concurrency: concurrency,
        call_wrapper: call_wrapper,
        event_timeout: event_timeout
      }
    end

    @spec handle_event(event :: event(), state :: t()) :: wrapper_result()
    defp handle_event(event, state)

    defp handle_event(event, %__MODULE__{call_wrapper: call_wrapper} = state) when is_function(call_wrapper),
      do: call_wrapper.(fn -> handle_event(event, %__MODULE__{state | call_wrapper: nil}) end)

    defp handle_event(%{action: :add, data_source: data_source, record: record} = event, state) do
      options = [return_info: state.produce_change_events]

      options =
        case Map.fetch(event, :load_id) do
          {:ok, load_id} -> Keyword.put_new(options, :load_id, load_id)
          :error -> options
        end

      options =
        case Map.fetch(event, :record_id) do
          {:ok, record_id} -> Keyword.put_new(options, :record_id, record_id)
          :error -> options
        end

      Engine.add_record(record, data_source, options)
    end

    defp handle_event(%{action: :replace, data_source: data_source, record_id: record_id, record: record} = event, state) do
      options = [return_info: state.produce_change_events]

      options =
        case Map.fetch(event, :load_id) do
          {:ok, load_id} -> Keyword.put_new(options, :load_id, load_id)
          :error -> options
        end

      Engine.replace_record(record, record_id, data_source, options)
    end

    defp handle_event(%{action: :delete, data_source: data_source, record_id: record_id} = event, state) do
      options = [return_info: state.produce_change_events]

      options =
        case Map.fetch(event, :load_id) do
          {:ok, load_id} -> Keyword.put_new(options, :load_id, load_id)
          :error -> options
        end

      Engine.delete_record(record_id, data_source, options)
    end

    defp handle_event(%{action: :reevaluate_record, data_source: data_source, record_id: record_id}, state),
      do: Engine.reevaluate_record(record_id, data_source, return_info: state.produce_change_events)

    defp handle_event(%{action: :reevaluate_entity, entity_id: entity_id}, state),
      do: Engine.reevaluate_entity(entity_id, return_info: state.produce_change_events)
  end
end
