defmodule Senzing.G2.ConfigManagerTest do
  use ExUnit.Case, async: false

  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.ResourceInit

  doctest Config

  setup_all do
    start_supervised!({ResourceInit, mod: Config})
    start_supervised!({ResourceInit, mod: ConfigManager})

    config = start_supervised!(Config)
    {:ok, config_json} = Config.save(config)

    {:ok, config: config_json}
  end

  describe inspect(&ConfigManager.add_config/0) do
    test "works", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config, comment: "foo")
      assert is_integer(config_id)
    end
  end

  describe inspect(&ConfigManager.get_config/1) do
    test "works", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)
      assert {:ok, config_json} = ConfigManager.get_config(config_id)
      assert is_binary(config_json)
    end
  end

  describe inspect(&ConfigManager.list_configs/0) do
    test "works", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)
      assert {:ok, configs} = ConfigManager.list_configs()
      assert Enum.any?(configs, &match?(%{"CONFIG_ID" => ^config_id}, &1))
    end
  end

  describe inspect(&ConfigManager.get_default_config_id/0) do
    test "works" do
      assert {:ok, default_config_id} = ConfigManager.get_default_config_id()
      assert is_integer(default_config_id)
    end
  end

  describe inspect(&ConfigManager.set_default_config_id/1) do
    test "works", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)

      assert :ok = ConfigManager.set_default_config_id(config_id)
      assert {:ok, ^config_id} = ConfigManager.get_default_config_id()
    end

    test "errors with invalid id" do
      assert {:error, {7221, "7221E|No engine configuration registered with data ID [7]."}} =
               ConfigManager.set_default_config_id(7)
    end
  end

  describe inspect(&ConfigManager.replace_default_config_id/2) do
    test "works", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)
      assert :ok = ConfigManager.set_default_config_id(config_id)

      assert :ok = ConfigManager.replace_default_config_id(config_id, config_id)
    end

    test "errors with invalid old id", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)

      assert {:error, {7245, "7245E|Current configuration ID does not match specified data ID [7]."}} =
               ConfigManager.replace_default_config_id(config_id, 7)
    end

    test "errors with invalid new id", %{config: config} do
      assert {:ok, config_id} = ConfigManager.add_config(config)
      assert :ok = ConfigManager.set_default_config_id(config_id)

      assert {:error, {7221, "7221E|No engine configuration registered with data ID [7]."}} =
               ConfigManager.replace_default_config_id(7, config_id)
    end
  end
end
