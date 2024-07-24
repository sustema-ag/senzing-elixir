with {:module, GenStage} <- Code.ensure_loaded(GenStage) do
  defmodule Senzing.G2.Engine.RedoProcessor do
    @moduledoc """
    Applies open redo processing jobs

    > #### Availability {:.info}
    >
    > The RedoProcessor is only available if `gen_stage` was added as a
    > dependency.
    """

    use GenStage

    alias Senzing.G2.Engine

    @enforce_keys [:concurrency, :call_wrapper, :event_timeout]
    defstruct @enforce_keys ++ [remaining_demand: 0]

    @typep t() :: %__MODULE__{
             concurrency: pos_integer(),
             call_wrapper: call_wrapper_function(term()) | nil,
             event_timeout: non_neg_integer(),
             remaining_demand: non_neg_integer()
           }

    @type call_wrapper_function(result) :: ((-> result) -> result)

    @typedoc """
    Configuration Options for the RedoProcessor

    ## Options

    * `:name` - `GenStage` name
    * `:producer_options` - `GenStage` producer options
    * `:call_wrapper` - A function that wraps the call to the engine. This can be
      useful to execute the engine call in a different context. For example
      through [`flame`](https://hex.pm/packages/flame)
    * `:event_timeout` - Timeout for each event
    * `:check_timeout` - Timeout for each event
    """
    @type option() ::
            {:name, atom()}
            | {:producer_options, [GenStage.producer_option()]}
            | {:call_wrapper, call_wrapper_function(term())}
            | {:event_timeout, non_neg_integer()}
            | {:check_timeout, non_neg_integer()}

    @type options() :: [option()]

    @typep init_options() :: %{
             concurrency: pos_integer(),
             producer_options: [GenStage.producer_option()],
             call_wrapper: call_wrapper_function(term()) | nil,
             event_timeout: non_neg_integer(),
             check_timeout: non_neg_integer()
           }

    @type out_event :: %{redo_record: Engine.redo_record(), mutation: Engine.mutation_info()}

    @spec start_link(options :: options()) :: GenServer.on_start()
    def start_link(options \\ []) do
      {init_options, start_options} = extract_options(options)

      GenStage.start_link(__MODULE__, init_options, start_options)
    end

    @impl GenStage
    def init(%{producer_options: producer_options, check_timeout: check_timeout} = options) do
      state = build_state(options)

      :timer.send_interval(check_timeout, self(), :check)

      {:producer, state, producer_options}
    end

    @impl GenStage
    def handle_demand(demand, state) do
      state = %__MODULE__{state | remaining_demand: state.remaining_demand + demand}

      {events, state} = process(state)

      {:noreply, events, state}
    end

    @impl GenStage
    def handle_info(:check, %__MODULE__{remaining_demand: 0} = state) do
      {events, state} = process(state)

      {:noreply, events, state}
    end

    @start_options [:name]
    @init_options [
      :concurrency,
      :producer_options,
      :call_wrapper,
      :event_timeout,
      :check_timeout
    ]

    @spec extract_options(options :: options()) ::
            {init_options :: init_options(), start_options :: Keyword.t()}
    defp extract_options(options) do
      options =
        Keyword.validate!(options, [
          :start,
          concurrency: System.schedulers(),
          producer_options: [],
          call_wrapper: nil,
          event_timeout: :timer.seconds(5),
          check_timeout: :timer.seconds(5)
        ])

      {options |> Keyword.take(@init_options) |> Map.new(), Keyword.take(options, @start_options)}
    end

    @spec build_state(options :: init_options()) :: t()
    defp build_state(%{concurrency: concurrency, call_wrapper: call_wrapper, event_timeout: event_timeout}) do
      %__MODULE__{
        concurrency: concurrency,
        call_wrapper: call_wrapper,
        event_timeout: event_timeout
      }
    end

    @spec process(state :: t()) :: {[map()], t()}
    defp process(state)
    defp process(%__MODULE__{remaining_demand: 0} = state), do: {[], state}

    defp process(%__MODULE__{remaining_demand: demand} = state) do
      task =
        case state.call_wrapper do
          nil ->
            fn _i -> Engine.process_next_redo_record(return_info: true) end

          call_wrapper ->
            fn _i ->
              call_wrapper.(fn -> Engine.process_next_redo_record(return_info: true) end)
            end
        end

      events =
        block_processing(fn ->
          1..demand
          |> Task.async_stream(task,
            timeout: state.event_timeout,
            max_concurrency: state.concurrency,
            ordered: false
          )
          |> Stream.map(fn
            {:ok, {:ok, {redo_record, mutation}}} ->
              %{redo_record: redo_record, mutation: mutation}

            {:ok, {:ok, nil}} ->
              nil

            {:ok, {:error, reason}} ->
              raise reason

            {:error, reason} ->
              raise reason
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.to_list()
        end)

      state = %__MODULE__{state | remaining_demand: demand - length(events)}

      {events, state}
    end

    @doc """
    Block redo processing until the given function is executed.

    This can be helpful when you want to block the redo processing until a batch
    import is finished.
    """
    @spec block_processing(fun :: (-> result)) :: result when result: term()
    def block_processing(fun), do: :global.trans({__MODULE__, :block_processing}, fun)
  end
end
