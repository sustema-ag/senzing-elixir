defmodule Senzing.G2.ConfigUpdaterTest do
  use ExUnit.Case, async: false

  alias Senzing.G2.ConfigUpdater

  doctest Senzing.G2.ConfigUpdater, except: [update: 2]

  describe inspect(&ConfigUpdater.update/2) do
    test "updates the config" do
      assert :ok =
               :senzing
               |> Application.app_dir("priv/test/config_sample.json")
               |> ConfigUpdater.update()
    end
  end

  describe inspect(&ConfigUpdater.start_link/1) do
    test "updates the config" do
      assert :ignore =
               ConfigUpdater.start_link(config_path: Application.app_dir(:senzing, "priv/test/config_sample.json"))
    end
  end
end
