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
end
