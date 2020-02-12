defmodule Nmap.Args do
  def atom_to_name(atom) do
    name = atom
    |> Atom.to_string
    |> String.replace("_", "-")
    if name |> String.length > 2 do
      "--#{name}"
    else
      "-#{name}"
    end
  end
  
  def prepare_arg(atom) when is_atom(atom) do
    {:ok, ["#{atom_to_name(atom)}"]}
  end
  def prepare_arg({atom, value}) when is_atom(atom) do
    {"#{atom_to_name(atom)}", value}
    |> prepare_arg
  end
  def prepare_arg({name, tuple}) when is_tuple(tuple) do
    {name, Tuple.to_list(tuple)}
    |> prepare_arg
  end
  def prepare_arg({name, []}), do: {:error, {:empty_list_arg, name}}
  def prepare_arg({name, list}) when is_list(list) do
    import Utils
    case all_ok_transform(list, &maybe_string/1) do
      {:ok, strings} ->
        {name, strings |> Enum.join(",")}
        |> prepare_arg
      {:error, error} -> {:error, {:bad_list, name, list, error[:error]}}
    end
  end
  def prepare_arg({name, integer}) when is_integer(integer) do
    {name, Integer.to_string(integer)}
    |> prepare_arg
  end
  def prepare_arg({name, value}) when is_binary(name) and is_binary(value) do
    {:ok, ["#{name}","#{value}"]}
  end
  def prepare_arg(string) when is_binary(string), do: {:ok, [string]}
  def prepare_arg(bad), do: {:error, {:cannot_parse_arg, bad}}
  
  def from_list(list) when is_list(list) do
    args = list
    |> Enum.map(&prepare_arg/1)
    |> Enum.group_by(fn({atom, _}) -> atom end)

    error = Map.get(args, :error, [])
    if error |> Enum.count > 0 do
      IO.inspect(error)
      {:error, {:bad_args, error}}
    else
      {:ok,
       args[:ok]
       |> Enum.map(fn({:ok, v}) -> v end)
       |> Enum.concat
       |> IO.inspect
       # |> Enum.join(" ")
      }
    end
  end
  
end


