readme_path = Path.join([Path.dirname(__ENV__.file), "..", "README.md"])

defmodule Senzing do
  @moduledoc readme_path |> File.read!() |> String.split("<!-- MDOC -->") |> Enum.fetch!(1)

  @external_resource readme_path

  @doc false
  @spec locate_root_path() :: Path.t()
  def locate_root_path do
    path = System.get_env("SENZING_ROOT", Application.get_env(:senzing, :root_path, "/opt/senzing"))

    unless File.exists?(Path.join(path, "data")) do
      raise """
      Invalid Senzing Root Path: #{path}
      """
    end

    path
  end
end
