defmodule Senzing.G2.MatchKey do
  @moduledoc "Relationship Match Key Utility Functions"

  import NimbleParsec

  defmodule ParseError do
    @moduledoc "Parse Error Exception"

    @type t() :: %__MODULE__{
            message: String.t(),
            subject: String.t(),
            rest: String.t(),
            offset: non_neg_integer()
          }

    defexception [:message, :subject, :rest, :offset]

    @impl Exception
    def message(exception) do
      """
      Parse Error in Match Key:
      #{inspect(exception.subject)}
       #{String.duplicate(" ", exception.offset)}^
       #{String.duplicate(" ", exception.offset)}#{exception.message}
      """
    end
  end

  ## Grammar
  ## <match_key> ::= <field>+EOS
  ## <field> ::= <signal><attribute_name>[<relationship>]
  ## <signal> ::= "+" | "-"
  ## <attribute_name> ::= [a-zA-Z_]+
  ## <relationship> ::= "("[<relationship_types>]":"[<relationship_types>]")"
  ## <relationship_types> ::= relationship_type[","relationship_type]
  ## <relationship_type> ::= [a-zA-Z_]+

  positive = "+" |> string() |> replace(:positive)
  negative = "-" |> string() |> replace(:negative)
  signal = [positive, negative] |> choice() |> label("signal [+-]") |> unwrap_and_tag(:signal)

  relationship_type =
    [?a..?z, ?A..?Z, ?_] |> utf8_string(min: 1) |> label("relationship type [a-zA-Z_]+")

  relationship_types =
    concat(relationship_type, repeat(concat(ignore(string(",")), relationship_type)))

  attribute_name =
    [?a..?z, ?A..?Z, ?_]
    |> utf8_string(min: 1)
    |> unwrap_and_tag(:attribute_name)
    |> label("attribute name [a-zA-Z_]+")

  relationship =
    "("
    |> string()
    |> ignore()
    |> concat(relationship_types |> tag(:initiating) |> optional())
    |> concat(":" |> string() |> ignore())
    |> concat(relationship_types |> tag(:receiving) |> optional())
    |> concat(ignore(string(")")))
    |> label("relationship <relationship_types>:<relationship_types>")
    |> reduce({Map, :new, []})
    |> unwrap_and_tag(:disclosed)
    |> optional()

  field =
    signal
    |> concat(attribute_name)
    |> concat(relationship)
    |> reduce({Map, :new, []})

  defparsecp(:_parse, choice([field |> times(min: 1) |> concat(eos()), replace(eos(), :empty)]))

  @type match_key() :: %{
          required(:signal) => :positive | :negative,
          required(:attribute_name) => String.t(),
          optional(:disclosed) => %{
            optional(:receiving) => [String.t()],
            optional(:initiating) => [String.t()]
          }
        }

  @doc """
  Parse a match key string into a list of match key maps.

  ## Examples

      iex> MatchKey.parse(
      ...>   "+NAME+LEI(:IS_DIRECTLY_CONSOLIDATED_BY,IS_ULTIMATELY_CONSOLIDATED_BY)-LEI_NUMBER"
      ...> )
      {:ok,
       [
         %{
           signal: :positive,
           attribute_name: "NAME"
         },
         %{
           signal: :positive,
           attribute_name: "LEI",
           disclosed: %{
             receiving: ["IS_DIRECTLY_CONSOLIDATED_BY", "IS_ULTIMATELY_CONSOLIDATED_BY"]
           }
         },
         %{
           signal: :negative,
           attribute_name: "LEI_NUMBER"
         }
       ]}

  """
  @spec parse(match_key :: String.t()) :: {:ok, [match_key()]} | {:error, ParseError.t()}
  def parse(match_key) do
    case _parse(match_key) do
      {:ok, [:empty], "", _acc, _loc, _offset} ->
        {:ok, []}

      {:ok, contents, "", _acc, _loc, _offset} ->
        {:ok, contents}

      {:error, message, rest, _acc, _line, offset} ->
        {:error, ParseError.exception(subject: match_key, message: message, rest: rest, offset: offset)}
    end
  end

  @doc """
  See `parse/1` for more information.
  """
  @spec parse!(match_key :: String.t()) :: [match_key()]
  def parse!(match_key) do
    case parse(match_key) do
      {:ok, contents} -> contents
      {:error, reason} -> raise reason
    end
  end
end
