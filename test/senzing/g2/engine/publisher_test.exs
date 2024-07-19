defmodule Senzing.G2.Engine.PublisherTest do
  use Senzing.G2.EngineCase, async: false

  alias Senzing.G2.Engine
  alias Senzing.G2.Engine.Publisher
  alias Senzing.G2.Error

  @moduletag prime: true

  doctest Publisher

  test "can act as producer and consumer" do
    :ok = Engine.add_record(%{"RECORD_ID" => "preexisting", "PRIMARY_NAME_ORG" => "Apple Inc"}, "TEST")

    assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => preexisting_entity_id}}} =
             Engine.get_entity_by_record_id("preexisting", "TEST")

    events = [
      %{
        action: :add,
        data_source: "TEST",
        record: %{"RECORD_ID" => "one", "PRIMARY_NAME_ORG" => "Microsoft Inc"},
        correlation: :test
      },
      %{
        action: :add,
        data_source: "TEST",
        record_id: "two",
        record: %{"RECORD_TYPE" => "ORGANISATION", "PRIMARY_NAME_ORG" => "Uber Inc"}
      },
      %{
        action: :replace,
        data_source: "TEST",
        record_id: "one",
        record: %{"RECORD_TYPE" => "ORGANISATION", "PRIMARY_NAME_ORG" => "Microsoft, Inc."}
      },
      %{action: :delete, data_source: "TEST", record_id: "two"},
      %{action: :reevaluate_record, data_source: "TEST", record_id: "one"},
      %{action: :reevaluate_entity, entity_id: preexisting_entity_id}
    ]

    {:ok, producer} = GenStage.from_enumerable(events)

    {:ok, publisher} =
      Publisher.start_link(
        producer_consumer_options: [subscribe_to: [producer]],
        produce_change_events: true,
        # Make sure the events arrive in order
        concurrency: 1,
        ordered: true
      )

    out_events =
      [{publisher, cancel: :transient}]
      |> GenStage.stream()
      |> Enum.take(length(events))

    assert {:ok, %{"RESOLVED_ENTITY" => %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "one"}]}}} =
             Engine.get_entity_by_record_id("one", "TEST")

    assert {:error, %Error{code: 33, message: "Unknown record: dsrc[TEST], record[two]"}} =
             Engine.get_entity_by_record_id("two", "TEST")

    assert [
             %{
               correlation: :test,
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_one}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "one"
               }
             },
             %{
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_two}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "two"
               }
             },
             %{
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_one}, %{"ENTITY_ID" => entity_id_one_new}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "one"
               }
             },
             %{
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_two}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "two"
               }
             },
             %{
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => entity_id_one_new}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "one"
               }
             },
             %{
               mutation: %{
                 "AFFECTED_ENTITIES" => [%{"ENTITY_ID" => ^preexisting_entity_id}],
                 "DATA_SOURCE" => "TEST",
                 "INTERESTING_ENTITIES" => %{"ENTITIES" => []},
                 "RECORD_ID" => "preexisting"
               }
             }
           ] = out_events
  end

  test "can act as only consumer" do
    events = [
      %{action: :add, data_source: "TEST", record: %{"RECORD_ID" => "one", "PRIMARY_NAME_ORG" => "Microsoft Inc"}},
      %{
        action: :add,
        data_source: "TEST",
        record_id: "two",
        record: %{"RECORD_TYPE" => "ORGANISATION", "PRIMARY_NAME_ORG" => "Apple Inc"}
      },
      %{
        action: :replace,
        data_source: "TEST",
        record_id: "one",
        record: %{"RECORD_TYPE" => "ORGANISATION", "PRIMARY_NAME_ORG" => "Microsoft, Inc."}
      },
      %{action: :delete, data_source: "TEST", record_id: "two"}
    ]

    pid = self()

    {:ok, producer} = GenStage.from_enumerable(events)

    {:ok, _publisher} =
      Publisher.start_link(
        consumer_options: [subscribe_to: [producer]],
        call_wrapper: fn call ->
          send(pid, :exec)
          call.()
        end,
        # Make sure the events arrive in order
        concurrency: 1,
        ordered: true
      )

    for _event <- events do
      assert_receive :exec
    end

    assert {:ok, %{"RESOLVED_ENTITY" => %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => "one"}]}}} =
             Engine.get_entity_by_record_id("one", "TEST")

    assert {:error, %Error{code: 33, message: "Unknown record: dsrc[TEST], record[two]"}} =
             Engine.get_entity_by_record_id("two", "TEST")
  end
end
