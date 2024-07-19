defmodule Senzing.G2.EngineCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Senzing.G2.Engine
  alias Senzing.G2.Engine.Publisher
  alias Senzing.G2.ResourceInit

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  setup_all do
    start_supervised!({ResourceInit, mod: Engine})

    :ok
  end

  setup tags do
    if tags[:prime] do
      :ok = Engine.prime()
    end

    :ok = Engine.purge_repository()

    :ok
  end

  @spec load_sample_data(tags :: map()) :: :ok
  def load_sample_data(_tags) do
    {:ok, event_stage} =
      :senzing
      |> Application.app_dir("priv/test/gleif_record_sample.json")
      |> File.stream!()
      |> Stream.map(&:json.decode/1)
      |> Stream.map(&{:add, {"TEST", Map.put(&1, "DATA_SOURCE", "TEST")}})
      |> GenStage.from_enumerable()

    {:ok, publisher} =
      Publisher.start_link(
        produce_change_events: true,
        producer_consumer_options: [subscribe_to: [event_stage]]
      )

    _ =
      [{publisher, cancel: :transient}]
      |> GenStage.stream()
      |> Enum.take(100)

    :ok
  end
end
