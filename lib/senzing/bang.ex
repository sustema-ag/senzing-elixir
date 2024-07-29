defmodule Senzing.Bang do
  @moduledoc false

  defmacro defbang(fun, opts \\ []) do
    {name, context, args} = fun

    opts =
      Keyword.put_new_lazy(opts, :to, fn ->
        name
        |> Atom.to_string()
        |> String.trim_trailing("!")
        |> String.to_existing_atom()
      end)

    to = opts[:to]

    call_args =
      Enum.map(args, fn
        {:\\, _context, [arg, _default]} -> arg
        arg -> arg
      end)

    quote file: __CALLER__.file, line: context[:line], generated: true do
      @doc """
      See `#{unquote(to)}/#{unquote(length(args))}`
      """
      def unquote(name)(unquote_splicing(args)) do
        case unquote(to)(unquote_splicing(call_args)) do
          :ok -> :ok
          {:ok, result} -> result
          {:error, error} -> raise error
        end
      end
    end
  end
end
