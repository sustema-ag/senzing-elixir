defmodule Senzing.G2.ConfigTest do
  use ExUnit.Case, async: false

  alias Senzing.G2.Config
  alias Senzing.G2.ResourceInit

  doctest Config

  setup_all do
    start_supervised!({ResourceInit, mod: Config})

    :ok
  end

  describe inspect(&Config.create/0) do
    test "works" do
      config = start_supervised!(Config)

      assert {:ok, data_sources} = Config.list_data_sources(config)

      assert ~w[TEST SEARCH] == Enum.map(data_sources, & &1["DSRC_CODE"])
    end
  end

  describe inspect(&Config.load/1) do
    test "works" do
      {:ok, config} = Config.start_link([])
      assert {:ok, json} = Config.save(config)
      GenServer.stop(config, :normal)

      new_config = start_supervised!({Config, load: json})
      assert {:ok, ^json} = Config.save(new_config)
    end
  end

  describe inspect(&Config.list_data_sources/1) do
    test "works" do
      config = start_supervised!(Config)

      assert {:ok, data_sources} = Config.list_data_sources(config)

      assert ~w[TEST SEARCH] == Enum.map(data_sources, & &1["DSRC_CODE"])
    end
  end

  describe inspect(&Config.add_data_source/2) do
    test "works" do
      config = start_supervised!(Config)

      assert {:ok, %{"DSRC_ID" => ds_id}} =
               Config.add_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})

      assert {:ok,
              [
                %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
                %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2},
                %{"DSRC_CODE" => "NAME_OF_DATASOURCE", "DSRC_ID" => ^ds_id}
              ]} = Config.list_data_sources(config)
    end
  end

  describe inspect(&Config.delete_data_source/2) do
    test "works" do
      config = start_supervised!(Config)

      assert {:ok, %{"DSRC_ID" => ds_id}} =
               Config.add_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})

      assert {:ok,
              [
                %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
                %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2},
                %{"DSRC_CODE" => "NAME_OF_DATASOURCE", "DSRC_ID" => ^ds_id}
              ]} = Config.list_data_sources(config)

      assert :ok = Config.delete_data_source(config, %{"DSRC_CODE" => "NAME_OF_DATASOURCE"})

      assert {:ok,
              [
                %{"DSRC_CODE" => "TEST", "DSRC_ID" => 1},
                %{"DSRC_CODE" => "SEARCH", "DSRC_ID" => 2}
              ]} = Config.list_data_sources(config)
    end
  end
end
