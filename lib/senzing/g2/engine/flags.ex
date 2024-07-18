defmodule Senzing.G2.Engine.Flags do
  @moduledoc false

  import Bitwise

  alias Senzing.G2

  header_file = Path.join(G2.locate_sdk_path(), "libg2.h")

  @external_resource header_file

  Module.register_attribute(__MODULE__, :flags, accumulate: true)

  base_flags =
    header_file
    |> File.read!()
    |> then(&Regex.scan(~r/#define (G2_[\w]+) static_cast<long long>\( 1LL << (\d+) \)/, &1))
    |> Map.new(fn [_, flag, shift] ->
      {flag |> String.downcase() |> String.to_atom(), 1 <<< String.to_integer(shift)}
    end)

  all_flags =
    header_file
    |> File.read!()
    |> then(
      &Regex.scan(
        ~r/#define (G2_[\w_]+)[\s\\]+\(([^\)]+)\)/sm,
        &1,
        capture: :all_but_first
      )
    )
    |> Enum.reduce(base_flags, fn [flag, contents], acc ->
      or_values =
        ~r/[\w_]+/
        |> Regex.scan(contents)
        |> List.flatten()

      Map.put(
        acc,
        flag |> String.downcase() |> String.to_atom(),
        or_values
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.downcase/1)
        |> Enum.map(&String.to_atom/1)
        |> Enum.map(&Map.fetch!(acc, &1))
        |> Enum.reduce(&|||/2)
      )
    end)

  def flag(name)

  for {flag, value} <- all_flags do
    def flag(unquote(flag)), do: unquote(value)
  end

  def combine(flags) do
    flags
    |> Enum.map(&operation/1)
    |> Enum.reduce(0, & &1.(&2))
  end

  defp operation(flag)
  defp operation(flag) when is_integer(flag), do: &(&1 ||| flag)

  for {flag, value} <- all_flags do
    defp operation(unquote(flag)), do: &(&1 ||| unquote(value))
    defp operation(unquote(:"no_#{flag}")), do: &(&1 &&& ~~~unquote(value))
  end

  def all, do: unquote(Map.keys(all_flags))

  def normalize(value, default \\ 0)
  def normalize(nil, default), do: combine([default])
  def normalize(value, _default), do: value |> List.wrap() |> combine()
end
