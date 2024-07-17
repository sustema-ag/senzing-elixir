readme_path = Path.join([Path.dirname(__ENV__.file), "..", "README.md"])

defmodule Senzing do
  @moduledoc readme_path |> File.read!() |> String.split("<!-- MDOC -->") |> Enum.fetch!(1)

  @external_resource readme_path
end
