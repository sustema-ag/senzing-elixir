defmodule Senzing.Application do
  @moduledoc false

  use Application

  alias Senzing.G2.ResourceInit

  @impl true
  def start(_type, args) do
    children =
      case g2_start_opts(args) do
        {:ok, options} -> [{ResourceInit, options}]
        :error -> []
      end

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: Senzing.Supervisor
    )
  end

  @spec g2_start_opts(args :: Keyword.t()) :: {:ok, ResourceInit.options()} | :error
  defp g2_start_opts(args) do
    with {:ok, mod} <- Keyword.fetch(args, :mod) do
      {:ok,
       [mod: mod]
       |> then(fn opts ->
         case Keyword.fetch(args, :ini_params) do
           :error -> opts
           {:ok, params} -> Keyword.put(opts, :ini_params, params)
         end
       end)
       |> then(fn opts ->
         case Application.fetch_env(:senzing, :engine_name) do
           :error -> opts
           {:ok, name} -> Keyword.put(opts, :name, name)
         end
       end)
       |> then(fn opts ->
         case Application.fetch_env(:senzing, :verbose_logging?) do
           :error -> opts
           {:ok, verbose_logging?} -> Keyword.put(opts, :verbose_logging, verbose_logging?)
         end
       end)
       |> then(fn opts ->
         case Application.fetch_env(:senzing, :prime) do
           :error -> opts
           {:ok, prime?} -> Keyword.put(opts, :prime, prime?)
         end
       end)}
    end
  end
end
