engine_codes_path = Path.join([Path.dirname(__ENV__.file), "error/engine_codes.tsv"])

engine_codes =
  Enum.reject(
    for line <- File.stream!(engine_codes_path, :line),
        fields = String.split(line, "\t", trim: true),
        fields = Enum.map(fields, &String.trim/1),
        [code, type, _description] = fields,
        String.starts_with?(type, "EAS_ERR_") do
      "EAS_ERR_" <> type = type

      case Integer.parse(code) do
        :error -> nil
        {code, "E"} -> {code, type |> String.downcase() |> String.to_atom()}
        {_code, _other_type} -> nil
      end
    end,
    &is_nil/1
  )

defmodule Senzing.G2.Error do
  @moduledoc """
  Senzing Error

  See https://senzing.zendesk.com/hc/en-us/articles/360026678133-Engine-Error-codes
  """

  alias Senzing.G2.Config
  alias Senzing.G2.ConfigManager
  alias Senzing.G2.Engine

  @external_resource engine_codes_path

  @enforce_keys [:context, :code, :message]
  defexception [:context, :code, :message, :type]

  @type t() :: %__MODULE__{
          context: context(),
          code: code(),
          message: message(),
          type: type() | nil
        }

  engine_code_types = Enum.map(engine_codes, &elem(&1, 1))

  @typedoc """
  Known Error Types for `#{inspect(Engine)}`

  ## Codes

  #{Enum.map_join(engine_codes, "\n", fn {code, type} -> "* #{code} - `:#{type}`" end)}
  """
  @type type() :: unquote(Enum.reduce(engine_code_types, &{:|, [], [&1, &2]}))

  @type context() :: Engine | Config | ConfigManager
  @type code() :: integer() | :unknown_error
  @type message() :: String.t()

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
          message: remove_code_from_message(opts[:message]),
          type: engine_code_type(opts[:code])
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

  @spec engine_code_type(code()) :: type()
  defp engine_code_type(code)

  for {code, type} <- Enum.uniq_by(engine_codes, &elem(&1, 0)) do
    defp engine_code_type(unquote(code)), do: unquote(type)
  end

  defp engine_code_type(_other), do: nil
end
