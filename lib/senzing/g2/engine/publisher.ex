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
  > The publisher is only available if `gen_stage` was added as a dependency.

  > #### Async {:.warning}
  >
  > The events are applied asynchronously and possibly out of order.
  """
  use GenStage

  alias Senzing.G2.Engine

  @enforce_keys [:concurrency, :produce_change_events, :call_wrapper, :event_timeout, :load_id]
  defstruct @enforce_keys

  @typep t() :: %__MODULE__{
           produce_change_events: boolean(),
           concurrency: pos_integer(),
           call_wrapper: call_wrapper_function(term()) | nil,
           event_timeout: non_neg_integer(),
           load_id: String.t()
         }

  @type add_event() ::
          {:add,
           {Engine.data_source(), Engine.record()}
           | {Engine.data_source(), Engine.record_id(), Engine.record()}}
  @type replace_event() :: {:replace, {Engine.data_source(), Engine.record_id(), Engine.record()}}
  @type delete_event() :: {:delete, {Engine.data_source(), Engine.record_id()}}
  @type reevaluate_record_event() ::
          {:reevaluate_record, {Engine.data_source(), Engine.record_id()}}
  @type reevaluate_entity_event() :: {:reevaluate_entity, Engine.entity_id()}
  @type event() ::
          add_event()
          | replace_event()
          | delete_event()
          | reevaluate_record_event()
          | reevaluate_entity_event()

  @type out_event() :: Engine.mutation_info()

  @type call_wrapper_function(result) :: ((-> result) -> result)

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
  * `:load_id` - Load ID for the the change events
  """
  @type option() ::
          {:name, atom()}
          | {:produce_change_events, boolean()}
          | {:consumer_options, [GenStage.consumer_option()]}
          | {:producer_consumer_options, [GenStage.producer_and_producer_consumer_option()]}
          | {:call_wrapper, call_wrapper_function(term())}
          | {:event_timeout, non_neg_integer()}
          | {:load_id, String.t()}
  @type options() :: [option()]

  @typep init_options() :: %{
           produce_change_events: boolean(),
           concurrency: pos_integer(),
           consumer_options: [GenStage.consumer_option()],
           producer_consumer_options: [GenStage.producer_and_producer_consumer_option()],
           call_wrapper: call_wrapper_function(term()) | nil,
           event_timeout: non_neg_integer(),
           load_id: String.t()
         }

  @spec start_link(options :: options()) :: GenServer.on_start()
  def start_link(options) do
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
        &handle_event(&1, state),
        timeout: event_timeout,
        max_concurrency: concurrency,
        ordered: false
      )
      |> Stream.map(fn
        {:ok, result} -> result
        {:error, reason} -> raise reason
      end)
      |> Stream.map(fn
        # add
        {:ok, {nil, info}} -> info
        # replace / delete
        {:ok, info} -> info
      end)
      |> Enum.to_list()

    {:noreply, events, state}
  end

  @start_options [:name]
  @init_options [
    :produce_change_events,
    :concurrency,
    :consumer_options,
    :producer_consumer_options,
    :call_wrapper,
    :event_timeout,
    :load_id
  ]

  @spec extract_options(options :: options()) ::
          {init_options :: init_options(), start_options :: Keyword.t()}
  defp extract_options(options) do
    options =
      Keyword.validate!(options, [
        :start,
        produce_change_events: false,
        concurrency: System.schedulers(),
        consumer_options: [],
        producer_consumer_options: [],
        call_wrapper: nil,
        event_timeout: :timer.seconds(5),
        load_id: "#{inspect(__MODULE__)} pid: #{inspect(self())}, start: #{inspect(DateTime.utc_now())}"
      ])

    {options |> Keyword.take(@init_options) |> Map.new(), Keyword.take(options, @start_options)}
  end

  @spec build_state(options :: init_options()) :: t()
  defp build_state(%{
         produce_change_events: produce_change_events,
         concurrency: concurrency,
         call_wrapper: call_wrapper,
         event_timeout: event_timeout,
         load_id: load_id
       }) do
    %__MODULE__{
      produce_change_events: produce_change_events,
      concurrency: concurrency,
      call_wrapper: call_wrapper,
      event_timeout: event_timeout,
      load_id: load_id
    }
  end

  @spec handle_event(event :: event(), state :: t()) :: map()
  defp handle_event(event, state)

  defp handle_event(event, %__MODULE__{call_wrapper: call_wrapper} = state) when is_function(call_wrapper),
    do: call_wrapper.(fn -> handle_event(event, %__MODULE__{state | call_wrapper: nil}) end)

  defp handle_event({:add, {data_source, record}}, state),
    do: Engine.add_record(record, data_source, load_id: state.load_id, return_info: state.produce_change_events)

  defp handle_event({:add, {data_source, record_id, record}}, state),
    do:
      Engine.add_record(record, data_source,
        load_id: state.load_id,
        record_id: record_id,
        return_info: state.produce_change_events
      )

  defp handle_event({:replace, {data_source, record_id, record}}, state),
    do:
      Engine.replace_record(record, record_id, data_source,
        load_id: state.load_id,
        return_info: state.produce_change_events
      )

  defp handle_event({:delete, {data_source, record_id}}, state),
    do: Engine.delete_record(record_id, data_source, load_id: state.load_id, return_info: state.produce_change_events)

  defp handle_event({:reevaluate_record, {data_source, record_id}}, state),
    do: Engine.reevaluate_record(record_id, data_source, return_info: state.produce_change_events)

  defp handle_event({:reevaluate_entity, entity_id}, state),
    do: Engine.reevaluate_entity(entity_id, return_info: state.produce_change_events)
end
