defmodule Senzing.G2 do
  @moduledoc """
  Shared functionality for Senzing G2
  """

  @type error() :: {code :: integer(), message :: String.t()}
  @type result() :: :ok | {:error, reason :: error()}
  @type result(t) :: {:ok, t} | {:error, reason :: error()}
end
