defmodule Senzing.G2 do
  @moduledoc """
  Shared functionality for Senzing G2
  """

  @type error() :: {code :: integer(), message :: String.t()}
  @type result() :: :ok | {:error, reason :: error()}
  @type result(t) :: {:ok, t} | {:error, reason :: error()}

  @doc false
  @spec locate_sdk_path() :: Path.t()
  def locate_sdk_path, do: locate_g2_path("sdk/c")

  @doc false
  @spec locate_lib_path() :: Path.t()
  def locate_lib_path, do: locate_g2_path("lib")

  @spec locate_g2_path(subpath :: Path.t()) :: Path.t()
  defp locate_g2_path(subpath) do
    root_path = Senzing.locate_root_path()

    cond do
      File.exists?(Path.join([root_path, "g2", subpath])) ->
        Path.join([root_path, "g2", subpath])

      File.exists?(Path.join(root_path, subpath)) ->
        Path.join(root_path, subpath)

      true ->
        raise """
        Could not locate #{subpath} in #{root_path}
        """
    end
  end
end
