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

  setup do
    :ok = Engine.purge_repository()

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
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok =
               Engine.add_record(
                 %{"RECORD_ID" => id, "RECORD_TYPE" => "ORGANIZATION", "PRIMARY_NAME_ORG" => "Apple"},
                 "TEST"
               )

      assert {:ok, %{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id} = short_response} =
               Engine.get_record(id, "TEST", flags: [:no_record_default_flags])

      refute Map.has_key?(short_response, "JSON_DATA")

      assert {:ok,
              %{
                "DATA_SOURCE" => "TEST",
                "RECORD_ID" => ^id,
                "JSON_DATA" => %{
                  "PRIMARY_NAME_ORG" => "Apple"
                }
              }} = Engine.get_record(id, "TEST", flags: [:record_default_flags])
    end
  end

  describe inspect(&Engine.get_entity_by_record_id/3) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok =
               Engine.add_record(
                 %{"RECORD_ID" => id, "RECORD_TYPE" => "ORGANIZATION", "PRIMARY_NAME_ORG" => "Apple"},
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => _entity_id} = short_response}} =
               Engine.get_entity_by_record_id(id, "TEST", flags: :no_entity_default_flags)

      refute Map.has_key?(short_response, "ENTITY_NAME")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => _entity_id, "ENTITY_NAME" => "Apple"}}} =
               Engine.get_entity_by_record_id(id, "TEST", flags: [:entity_default_flags])
    end
  end

  describe inspect(&Engine.get_entity/2) do
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

  describe inspect(&Engine.search_by_attributes/2) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok =
               Engine.add_record(
                 %{"RECORD_ID" => id, "RECORD_TYPE" => "ORGANIZATION", "PRIMARY_NAME_ORG" => id},
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
               Engine.get_entity_by_record_id(id, "TEST")

      assert {:ok, %{"RESOLVED_ENTITIES" => [%{"ENTITY" => %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}}]}} =
               Engine.search_by_attributes(%{"PRIMARY_NAME_ORG" => id})
    end
  end

  describe inspect(&Engine.find_path_by_entity_id/4) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"
      id_three = "#{inspect(__MODULE__)}.#{inspect(test)}_three"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "one",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "two",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_two,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "two",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "three",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_three,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Germany",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_three,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "three"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_three}}} =
               Engine.get_entity_by_record_id(id_three, "TEST")

      assert {:ok,
              %{
                "ENTITY_PATHS" => [
                  %{
                    "END_ENTITY_ID" => ^entity_id_three,
                    "ENTITIES" => [^entity_id_one, ^entity_id_two, ^entity_id_three],
                    "START_ENTITY_ID" => ^entity_id_one
                  }
                ]
              }} = Engine.find_path_by_entity_id(entity_id_one, entity_id_three, 3)

      assert {:ok, %{"ENTITY_PATHS" => [%{"ENTITIES" => []}]}} =
               Engine.find_path_by_entity_id(entity_id_one, entity_id_three, 3,
                 exclude: [entity_id_two],
                 included_data_sources: ["TEST"]
               )
    end
  end

  describe inspect(&Engine.find_path_by_record_id/4) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"
      id_three = "#{inspect(__MODULE__)}.#{inspect(test)}_three"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "one",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "two",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_two,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "two",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "three",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_three,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Germany",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_three,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "three"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_three}}} =
               Engine.get_entity_by_record_id(id_three, "TEST")

      assert {:ok,
              %{
                "ENTITY_PATHS" => [
                  %{
                    "END_ENTITY_ID" => ^entity_id_three,
                    "ENTITIES" => [^entity_id_one, ^entity_id_two, ^entity_id_three],
                    "START_ENTITY_ID" => ^entity_id_one
                  }
                ]
              }} = Engine.find_path_by_record_id({id_one, "TEST"}, {id_three, "TEST"}, 3)

      assert {:ok, %{"ENTITY_PATHS" => [%{"ENTITIES" => []}]}} =
               Engine.find_path_by_record_id({id_one, "TEST"}, {id_three, "TEST"}, 3,
                 exclude: [{id_two, "TEST"}],
                 included_data_sources: ["TEST"]
               )
    end
  end

  describe inspect(&Engine.find_network_by_entity_id/2) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"
      id_three = "#{inspect(__MODULE__)}.#{inspect(test)}_three"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "one",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "two",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_two,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "two",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "three",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_three,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Germany",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_three,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "three"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_three}}} =
               Engine.get_entity_by_record_id(id_three, "TEST")

      assert {:ok,
              %{
                "ENTITIES" => [
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_one}},
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_two}},
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_three}}
                ]
              }} = Engine.find_network_by_entity_id([entity_id_one])
    end
  end

  describe inspect(&Engine.find_network_by_record_id/2) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"
      id_three = "#{inspect(__MODULE__)}.#{inspect(test)}_three"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "one",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "two",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_two,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "two",
                   "REL_POINTER_DOMAIN" => "TEST",
                   "REL_POINTER_KEY" => "three",
                   "REL_POINTER_ROLE" => "subsidiary"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_three,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Germany",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_three,
                   "REL_ANCHOR_DOMAIN" => "TEST",
                   "REL_ANCHOR_KEY" => "three"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_three}}} =
               Engine.get_entity_by_record_id(id_three, "TEST")

      assert {:ok,
              %{
                "ENTITIES" => [
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_one}},
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_two}},
                  %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id_three}}
                ]
              }} = Engine.find_network_by_record_id([{id_one, "TEST"}])
    end
  end

  describe inspect(&Engine.why_records/3) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {
               :ok,
               %{
                 "WHY_RESULTS" => [
                   %{
                     "ENTITY_ID" => ^entity_id_one,
                     "ENTITY_ID_2" => ^entity_id_two,
                     "FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_one}],
                     "FOCUS_RECORDS_2" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_two}]
                   }
                 ]
               }
             } = Engine.why_records({id_one, "TEST"}, {id_two, "TEST"})
    end
  end

  describe inspect(&Engine.why_entity_by_record_id/3) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Inc.",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {
               :ok,
               %{
                 "WHY_RESULTS" => [
                   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_one}]},
                   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_two}]}
                 ]
               }
             } = Engine.why_entity_by_record_id(id_one, "TEST")
    end
  end

  describe inspect(&Engine.why_entity_by_entity_id/2) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Inc.",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {
               :ok,
               %{
                 "WHY_RESULTS" => [
                   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_one}]},
                   %{"FOCUS_RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_two}]}
                 ]
               }
             } = Engine.why_entity_by_entity_id(entity_id)
    end
  end

  describe inspect(&Egnine.why_entities/3) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple"
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Europe"
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_one}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id_two}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {:ok, %{"WHY_RESULTS" => [%{"ENTITY_ID" => ^entity_id_one, "ENTITY_ID_2" => ^entity_id_two}]}} =
               Engine.why_entities(entity_id_one, entity_id_two)
    end
  end

  describe inspect(&Engine.how_entity_by_entity_id/2) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one"
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two"

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Inc.",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => entity_id}}} =
               Engine.get_entity_by_record_id(id_one, "TEST")

      assert {:ok, %{"RESOLVED_ENTITY" => %{"ENTITY_ID" => ^entity_id}}} =
               Engine.get_entity_by_record_id(id_two, "TEST")

      assert {
               :ok,
               %{
                 "HOW_RESULTS" => %{
                   "FINAL_STATE" => %{
                     "VIRTUAL_ENTITIES" => [
                       %{
                         "MEMBER_RECORDS" => [
                           %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_one}]},
                           %{"RECORDS" => [%{"DATA_SOURCE" => "TEST", "RECORD_ID" => ^id_two}]}
                         ]
                       }
                     ]
                   },
                   "RESOLUTION_STEPS" => [%{"MATCH_INFO" => %{"MATCH_KEY" => "+NAME+TRUSTED_ID"}}]
                 }
               }
             } = Engine.how_entity_by_entity_id(entity_id)
    end
  end

  describe inspect(&Engine.export_csv_entity_report/1) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one" |> :erlang.crc32() |> Integer.to_string()
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two" |> :erlang.crc32() |> Integer.to_string()

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Inc.",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert csv_stream = Engine.export_csv_entity_report(["RECORD_ID"])

      assert Enum.into(csv_stream, "") == """
             RECORD_ID
             #{inspect(id_one)}
             #{inspect(id_two)}
             """
    end
  end

  describe inspect(&Engine.export_json_entity_report/1) do
    test "works", %{test: test} do
      id_one = "#{inspect(__MODULE__)}.#{inspect(test)}_one" |> :erlang.crc32() |> Integer.to_string()
      id_two = "#{inspect(__MODULE__)}.#{inspect(test)}_two" |> :erlang.crc32() |> Integer.to_string()

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_one,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert :ok =
               Engine.add_record(
                 %{
                   "RECORD_ID" => id_two,
                   "RECORD_TYPE" => "ORGANIZATION",
                   "PRIMARY_NAME_ORG" => "Apple Inc.",
                   "TRUSTED_ID_TYPE" => "TEST",
                   "TRUSTED_ID_NUMBER" => id_one
                 },
                 "TEST"
               )

      assert json_stream = Engine.export_json_entity_report(flags: [:export_include_all_entities])

      assert Enum.into(json_stream, "") == """
             {"RESOLVED_ENTITY":{"ENTITY_ID":1}}
             """
    end
  end

  describe inspect(&Engine.purge_repository/0) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")
      assert {:ok, _result} = Engine.get_entity_by_record_id(id, "TEST")

      assert :ok = Engine.purge_repository()

      assert {:error, {33, "0033E|Unknown record" <> _}} = Engine.get_entity_by_record_id(id, "TEST")
    end
  end

  describe inspect(&Engine.stats/0) do
    test "works", %{test: test} do
      id = "#{inspect(__MODULE__)}.#{inspect(test)}"

      assert :ok = Engine.add_record(%{"RECORD_ID" => id}, "TEST")

      assert {:ok, %{"workload" => %{"addedRecords" => 1}}} = Engine.stats()
    end
  end
end
