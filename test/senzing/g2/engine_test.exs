defmodule Senzing.G2.EngineTest do
  use ExUnit.Case, async: false

  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine
  alias Senzing.G2.ResourceInit

  doctest Engine, except: [prime: 0]
  doctest Engine, only: [prime: 0], tags: [:slow]

  setup_all do
    start_supervised!({ResourceInit, mod: Config})
    start_supervised!({ResourceInit, mod: ConfigManager})
    start_supervised!({ResourceInit, mod: Engine})

    :ok
  end

  test "works" do
  end

  describe inspect(&Engine.prime/0) do
    @tag :slow
    test "works" do
      assert :ok = Engine.prime()
    end
  end

  describe inspect(&Engine.reinit/1) do
    test "works" do
      config_pid = start_supervised!(Config)
      {:ok, config} = Config.save(config_pid)

      {:ok, config_id} = ConfigManager.add_config(config)

      assert :ok = Engine.reinit(config_id)
    end
  end

  describe inspect(&Engine.get_active_config_id/0) do
    test "works" do
      assert {:ok, default_config_id} = ConfigManager.get_default_config_id()
      assert {:ok, ^default_config_id} = Engine.get_active_config_id()
    end
  end

  describe inspect(&Engine.export_config/0) do
    test "works" do
      assert {:ok, {config, config_id}} = Engine.export_config()
      assert is_binary(config)
      assert is_integer(config_id)
    end
  end

  describe inspect(&Engine.get_repository_last_modified/0) do
    test "works" do
      assert {:ok, %DateTime{}} = Engine.get_repository_last_modified()
    end
  end

  describe inspect(&Engine.add_record/4) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 record_id: id
               )

      assert :ok =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST", load_id: id)
    end

    test "returns info and id", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert {:ok, {^id, %{"RECORD_ID" => ^id}}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 record_id: id,
                 return_info: true,
                 return_record_id: true
               )

      assert {:ok, {^id, %{"RECORD_ID" => ^id}}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 return_info: true,
                 return_record_id: true
               )
    end

    test "returns info", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert {:ok, {nil, %{"RECORD_ID" => ^id}}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 record_id: id,
                 return_info: true
               )

      assert {:ok, {nil, %{"RECORD_ID" => ^id}}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 return_info: true
               )
    end

    test "returns id", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert {:ok, {^id, nil}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 record_id: id,
                 return_record_id: true
               )

      assert {:ok, {^id, nil}} =
               Engine.add_record(%{"RECORD_ID" => id}, "TEST",
                 load_id: id,
                 return_record_id: true
               )
    end
  end

  describe inspect(&Engine.replace_record/4) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.replace_record(%{"RECORD_ID" => id}, id, "TEST")
    end

    test "returns info", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert {:ok, %{"RECORD_ID" => ^id}} =
               Engine.replace_record(%{"RECORD_ID" => id}, id, "TEST",
                 load_id: id,
                 return_info: true
               )
    end
  end

  describe inspect(&Engine.reevaluate_record/3) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST", load_id: id)

      assert :ok = Engine.reevaluate_record(id, "TEST")
      assert {:ok, %{"RECORD_ID" => ^id}} = Engine.reevaluate_record(id, "TEST", return_info: true)
    end
  end

  describe inspect(&Engine.reevaluate_entity/2) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} = Engine.get_entity_by_record_id(id, "TEST")

      assert :ok = Engine.reevaluate_entity(entity_id)

      assert {:ok, %{"AFFECTED_ENTITIES" => [%{"ENTITY_ID" => ^entity_id}]}} =
               Engine.reevaluate_entity(entity_id, return_info: true)
    end
  end

  describe inspect(&Engine.count_redo_records/0) do
    test "works" do
      assert {:ok, count} = Engine.count_redo_records()
      assert is_integer(count)
      assert count >= 0
    end
  end

  describe inspect(&Engine.get_redo_record/0) do
    test "works" do
      assert {:ok, record} = Engine.get_redo_record()
      assert is_map(record) or is_nil(record)
      # TODO: How can I trigger a redo so that I can test this properly?
    end
  end

  describe inspect(&Engine.process_redo_record/2) do
    test "works" do
      # TODO: How to test?
    end
  end

  describe inspect(&Engine.process_next_redo_record/1) do
    test "works" do
      # TODO: How to test?
      assert {:ok, nil} = Engine.process_next_redo_record()
      assert {:ok, nil} = Engine.process_next_redo_record(return_info: true)
    end
  end

  describe inspect(&Engine.delete_record/2) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert :ok = Engine.delete_record(id, "TEST")

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert {:ok,
              %{
                "AFFECTED_ENTITIES" => _affected_entities,
                "DATA_SOURCE" => "TEST",
                "INTERESTING_ENTITIES" => %{"ENTITIES" => _entities},
                "RECORD_ID" => ^id
              }} = Engine.delete_record(id, "TEST", with_info: true)

      assert {:error, {33, _message}} = Engine.get_entity_by_record_id(id, "TEST")
    end
  end

  describe inspect(&Engine.get_record/3) do
    # TODO: Implement Flags
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert {:ok, %{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id}} = Engine.get_record(id, "TEST")
    end
  end

  describe inspect(&Engine.get_entity_by_record_id/3) do
    # TODO: Implement Flags
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => _entity_id}}} = Engine.get_entity_by_record_id(id, "TEST")
    end
  end

  describe inspect(&Engine.get_entity/2) do
    # TODO: Implement Flags
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")
      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} = Engine.get_entity_by_record_id(id, "TEST")
      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}} = Engine.get_entity(entity_id)
    end
  end

  describe inspect(&Engine.get_virtual_entity/2) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{"RECORD_ID" => id_one, "RECORD_TYPE" => "ORGANIZATION", "PRIMARY_NAME_ORG" => "Apple"},
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{"RECORD_ID" => id_two, "RECORD_TYPE" => "ORGANIZATION", "PRIMARY_NAME_ORG" => "Apple Inc."},
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => _entity_id, "ENTITY_NAME" => "Apple" <> _}}} =
               Engine.get_virtual_entity([{id_one, "TEST"}, {id_two, "TEST"}])
    end
  end
end
