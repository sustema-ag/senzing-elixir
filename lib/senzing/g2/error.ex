defmodule Senzing.G2.Error do
  @moduledoc """
  Senzing Error

  See https://senzing.zendesk.com/hc/en-us/articles/360026678133-Engine-Error-codes
  """

  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine

  defexception [:context, :code, :message]

  @type context() :: Engine | Config | ConfigManager
  @type code() :: integer() | :unknown_error
  @type message() :: String.t()

  @type t() :: %__MODULE__{
          context: context(),
          code: code(),
          message: message()
        }

  @impl Exception
  def exception(opts) do
    case opts[:code] do
      :unknown_error ->
        %__MODULE__{
          context: opts[:context],
          code: :unknown_error,
          message: "Unknown Error"
        }

      _ ->
        %__MODULE__{
          context: opts[:context],
          code: opts[:code],
          message: remove_code_from_message(opts[:message])
        }
    end
  end

  @impl Exception
  def message(%__MODULE__{code: :unknown_error, message: message}), do: message
  def message(%__MODULE__{code: code, message: message}), do: "#{code}E|#{message}"

  @spec remove_code_from_message(message :: String.t()) :: String.t()
  defp remove_code_from_message(message), do: String.replace(message, ~r/^\d+E\|/, "")

  @doc false
  @spec transform_result(result :: :ok, context :: context()) :: :ok
  @spec transform_result(result :: {:ok, data}, context :: context()) :: {:ok, data}
        when data: term()
  @spec transform_result(result :: {:error, :unexpected_error}, context :: context()) ::
          {:error, t()}
  @spec transform_result(
          result :: {:error, {code :: integer(), message :: String.t()}},
          context :: context()
        ) ::
          {:error, t()}
  def transform_result(result, context)
  def transform_result(:ok, _context), do: :ok
  def transform_result({:ok, data}, _context), do: {:ok, data}

  def transform_result({:error, :unexpected_error}, context),
    do: {:error, exception(context: context, code: :unknown_error)}

  def transform_result({:error, {code, message}}, context),
    do: {:error, exception(context: context, code: code, message: message)}
end
