defmodule Senzing.G2.Engine.RedoProcessorTest do
  use Senzing.G2.EngineCase, async: false

  alias Senzing.G2.Engine
  alias Senzing.G2.Engine.RedoProcessor

  doctest RedoProcessor

  @moduletag :slow
  @moduletag prime: true

  setup :load_sample_data

  test "applied redo processing" do
    assert {:ok, redo_count} = Engine.count_redo_records()
    assert redo_count > 0

    {:ok, redo_processor} = RedoProcessor.start_link()

    assert [%{redo_record: %{"DATA_SOURCE" => "TEST", "DSRC_ACTION" => "X"}, mutation: %{"AFFECTED_ENTITIES" => _}} | _] =
             [{redo_processor, cancel: :transient}]
             |> GenStage.stream()
             |> Enum.take(redo_count)

    assert {:ok, redo_count} = Engine.count_redo_records()
    assert redo_count == 0
  end
end
