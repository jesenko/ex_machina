defmodule ExMachina.Ecto do
  defmacro __using__(opts) do
    verify_ecto_dep

    quote do
      use ExMachina

      import ExMachina.Ecto, only: [assoc: 1, assoc: 2]

      @repo Dict.fetch!(unquote(opts), :repo)

      def fields_for(factory_name, attrs \\ %{}) do
        ExMachina.Ecto.fields_for(__MODULE__, factory_name, attrs)
      end

      def save_record(record) do
        ExMachina.Ecto.save_record(__MODULE__, @repo, record)
      end
    end
  end

  defmacro assoc(factory_name, opts \\ []) do
    quote do
      ExMachina.Ecto.assoc(__MODULE__, var!(attrs), unquote(factory_name), unquote(opts))
    end
  end

  defp verify_ecto_dep do
    unless Code.ensure_loaded?(Ecto) do
      raise "You tried to use ExMachina.Ecto, but the Ecto module is not loaded. " <>
        "Please add ecto to your dependencies."
    end
  end

  @doc """
  Builds a factory with the passed in factory_name and returns its fields

  This is only for use with Ecto models.

  Will return a map with the fields and virtual fields, but without the Ecto
  metadata and associations.

  ## Example

      factory :user do
        %MyApp.User{name: "John Doe", admin: false}
      end

      # Returns %{name: "John Doe", admin: true}
      fields_for(:user, admin: true)
  """
  def fields_for(module, factory_name, attrs \\ %{}) do
    module.build(factory_name, attrs)
    |> drop_ecto_fields
  end

  defp drop_ecto_fields(record = %{__struct__: struct, __meta__: %{__struct__: Ecto.Schema.Metadata}}) do
    record
    |> Map.from_struct
    |> Map.delete(:__meta__)
    |> Map.drop(struct.__schema__(:associations))
  end
  defp drop_ecto_fields(record) do
    raise ArgumentError, "#{inspect record} is not an Ecto model. Use `build` instead."
  end

  @doc """
  Gets a factory from the passed in attrs, or creates if none is present

  ## Examples

      attrs = %{user: %{name: "Someone"}}
      # Returns attrs.user
      assoc(:user)

      attrs = %{}
      # Creates and returns new instance based on :user factory
      assoc(:user)

      attrs = %{}
      # Creates and returns new instance based on :user factory
      assoc(:author, factory: :user)
  """
  def assoc(module, attrs, factory_name, opts \\ []) do
    case Map.get(attrs, factory_name) do
      nil -> create_assoc(module, factory_name, opts)
      record -> record
    end
  end

  defp create_assoc(module, _factory_name, factory: factory_name) do
    ExMachina.create(module, factory_name)
  end
  defp create_assoc(module, factory_name, _opts) do
    ExMachina.create(module, factory_name)
  end

  defp get_assocs(%{__struct__: struct}) do
    for a <- struct.__schema__(:associations) do
      {a, struct.__schema__(:association, a)}
    end
  end

  defp belongs_to_assocs(model) do
    for {a, %Ecto.Association.BelongsTo{}} <- get_assocs(model), do: a
  end

  defp not_loaded_assocs(model) do
    for {a, %Ecto.Association.Has{}} <- get_assocs(model),
      !Ecto.Association.loaded?(Map.get(model, a)),
      do: a
  end

  defp convert_to_changes(record) do
    record
    |> Map.from_struct
    |> Map.delete(:__meta__)
    # drop fields for `belongs_to` assocs as they cannot be handled by changeset
    |> Map.drop(belongs_to_assocs(record))
    |> Map.drop(not_loaded_assocs(record))
  end

  @doc """
  Saves a record using `Repo.insert!` when `create` is called.
  """
  def save_record(module, repo, %{__struct__: model} = record) do
    struct(model)
    # `belongs_to` assocs are not managed by changeset, add them to model
    |> Map.merge(Map.take(record, belongs_to_assocs(record)))
    |> Ecto.Changeset.change(convert_to_changes(record))
    |> repo.insert!
  end
  def save_record(_, _ , record) do
    raise ArgumentError, "#{inspect record} is not Ecto model."
  end
end
