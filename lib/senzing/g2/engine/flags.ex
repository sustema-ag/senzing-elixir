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
    |> then(&Regex.scan(~r/#define G2_([\w]+) static_cast<long long>\( 1LL << (\d+) \)/, &1))
    |> Map.new(fn [_, flag, shift] ->
      {flag |> String.downcase() |> String.to_atom(), 1 <<< String.to_integer(shift)}
    end)

  all_flags =
    header_file
    |> File.read!()
    |> then(
      &Regex.scan(
        ~r/#define G2_([\w_]+)[\s\\]+\(([^\)]+)\)/sm,
        &1,
        capture: :all_but_first
      )
    )
    |> Enum.reduce(base_flags, fn [flag, contents], acc ->
      or_values =
        ~r/G2_([\w_]+)/
        |> Regex.scan(contents, capture: :all_but_first)
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

  flags_only_name_typespec =
    all_flags
    |> Map.keys()
    |> Enum.reduce(&{:|, [], [&1, &2]})

  flags_typespec =
    all_flags
    |> Map.keys()
    |> Enum.flat_map(fn flag -> [flag, :"no_#{flag}"] end)
    |> then(
      &[
        quote do
          integer()
        end
        | &1
      ]
    )
    |> Enum.reduce(&{:|, [], [&1, &2]})

  @typep flag_only_name() :: unquote(flags_only_name_typespec)
  @typep flag() :: unquote(flags_typespec)

  @spec flag(name :: flag()) :: integer()
  def flag(name)

  for {flag, value} <- all_flags do
    def flag(unquote(flag)), do: unquote(value)
  end

  @spec combine(flags :: [flag()]) :: integer()
  def combine(flags) do
    flags
    |> Enum.map(&operation/1)
    |> Enum.reduce(0, & &1.(&2))
  end

  @spec operation(flag :: flag()) :: (integer() -> integer())
  defp operation(flag)
  defp operation(flag) when is_integer(flag), do: &(&1 ||| flag)

  for {flag, value} <- all_flags do
    defp operation(unquote(flag)), do: &(&1 ||| unquote(value))
    defp operation(unquote(:"no_#{flag}")), do: &(&1 &&& ~~~unquote(value))
  end

  @spec all() :: [flag_only_name()]
  def all, do: unquote(Map.keys(all_flags))

  @spec normalize(value :: nil | flag() | [flag()], default :: flag() | [flag()]) :: integer()
  def normalize(value, default \\ 0)
  def normalize(nil, default), do: default |> List.wrap() |> combine()
  def normalize(value, _default), do: value |> List.wrap() |> combine()
end
