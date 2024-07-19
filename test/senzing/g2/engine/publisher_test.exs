defmodule Senzing.G2.Engine.PublisherTest do
  use Senzing.G2.EngineCase, async: false

  alias Senzing.G2.Engine
  alias Senzing.G2.Engine.Publisher

  doctest Publisher

  test "can act as producer and consumer" do
    :ok = Engine.add_record(%{"RECORD_ID" => "preexisting"}, "TEST")

    assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => preexisting_entity_id}}} =
             Engine.get_entity_by_record_id("preexisting", "TEST")

    events = [
      {:add, {"TEST", %{"RECORD_ID" => "one"}}},
      {:add, {"TEST", "two", %{"RECORD_TYPE" => "ORGANISATION"}}},
      {:replace, {"TEST", "one", %{"RECORD_TYPE" => "ORGANISATION"}}},
      {:delete, {"TEST", "two"}},
      {:reevaluate_record, {"TEST", "one"}},
      {:reevaluate_entity, preexisting_entity_id}
    ]

    {:ok, producer} = GenStage.from_enumerable(events)

    {:ok, publisher} =
      Publisher.start_link(
        producer_consumer_options: [subscribe_to: [producer]],
        produce_change_events: true
      )

    out_events =
      [{publisher, cancel: :transient}]
      |> GenStage.stream()
      |> Enum.take(length(events))

    assert {:ok, %{"RESOLVED_ENTITY" => %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "one"}]}}} =
             Engine.get_entity_by_record_id("one", "TEST")

    assert {:error, {33, "0033E|Unknown record: dsrc[TEST], record[two]"}} =
             Engine.get_entity_by_record_id("two", "TEST")

    assert [
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_one}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "one"
             },
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_two}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "two"
             },
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_one}, %{"ENTITY_ID" => entity_id_two}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "one"
             },
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_two}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "two"
             },
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 2}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "one"
             },
             %{
               "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => 1}],
               "DATA_SOURCE" => "TEST",
               "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
               "RECORD_ID" => "preexisting"
             }
           ] = out_events
  end

  test "can act as only consumer" do
    events = [
      {:add, {"TEST", %{"RECORD_ID" => "one"}}},
      {:add, {"TEST", "two", %{"RECORD_TYPE" => "ORGANISATION"}}},
      {:replace, {"TEST", "one", %{"RECORD_TYPE" => "ORGANISATION"}}},
      {:delete, {"TEST", "two"}}
    ]

    pid = self()

    {:ok, producer} = GenStage.from_enumerable(events)

    {:ok, _publisher} =
      Publisher.start_link(
        consumer_options: [subscribe_to: [producer]],
        call_wrapper: fn call ->
          send(pid, :exec)
          call.()
        end
      )

    for _event <- events do
      assert_receive :exec
    end

    assert {:ok, %{"RESOLVED_ENTITY" => %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "one"}]}}} =
             Engine.get_entity_by_record_id("one", "TEST")

    assert {:error, {33, "0033E|Unknown record: dsrc[TEST], record[two]"}} =
             Engine.get_entity_by_record_id("two", "TEST")
  end
end
