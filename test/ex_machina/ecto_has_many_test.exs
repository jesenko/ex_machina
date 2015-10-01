defmodule ExMachina.EctoHasManyTest do
  use ExUnit.Case, async: true

  defmodule TestRepo do
    def insert!(changeset) do
      send self, {:created, changeset}
      changeset |> Ecto.Changeset.apply_changes |> Map.put(:id, 1)
    end
  end

  defmodule MyApp2.Package do
    use Ecto.Model
    schema "packages" do
      field :description, :string
      has_many :statuses, MyApp2.PackageStatus
    end
  end

  defmodule MyApp2.PackageStatus do
    use Ecto.Model
    schema "package_statuses" do
      field :status, :string
      belongs_to :package, MyApp2.Package
    end
  end

  defmodule MyApp2.Invoice do
    use Ecto.Model
    schema "invoices" do
      field :title, :string
      belongs_to :package, MyApp2.Package
    end
  end


  defmodule MyApp2.EctoFactories do
    use ExMachina.Ecto, repo: TestRepo

    factory(:invalid_package) do
      %MyApp2.Package{
        description: "Invalid package without any statuses"
      }
    end

    factory(:package) do
      %MyApp2.Package{
        description: "Package that just got ordered",
        statuses: [
          %MyApp2.PackageStatus{status: "ordered"}
        ]
      }
    end

    factory(:shipped_package) do
      %MyApp2.Package{
        description: "Package that got shipped",
        statuses: [
          %MyApp2.PackageStatus{status: "ordered"},
          %MyApp2.PackageStatus{status: "sent"},
          %MyApp2.PackageStatus{status: "shipped"}
        ]
      }
    end

    factory(:invoice) do
      %MyApp2.Invoice{
        title: "Invoice for shipped package",
        package_id: assoc(:package, factory: :shipped_package).id
      }
    end
  end

  test "create/1 creates model with `has_many` associations" do
    package = MyApp2.EctoFactories.create(:package)

    assert %{statuses: [%{status: "ordered"}]} = package
    assert_received {:created, %{model: %MyApp2.Package{}} = package_changeset}
    assert %{changes: %{statuses: [%{action: :insert}]}} = package_changeset
    assert %{valid?: true} = package_changeset
    refute_received {:created, %{model: %MyApp2.PackageStatus{}}}
  end

  test "create/2 creates model with overriden `has_many` associations" do
    statuses = [
      %MyApp2.PackageStatus{status: "ordered"},
      %MyApp2.PackageStatus{status: "delayed"}
    ]
    package = MyApp2.EctoFactories.create :package,
      description: "Delayed package",
      statuses: statuses

    assert %{statuses: [%{status: "ordered"}, %{status: "delayed"}]} = package
    assert_received {:created, %{model: %MyApp2.Package{}} = package_changeset}
    assert %{changes: %{statuses: [%{action: :insert}, %{action: :insert}]}} = package_changeset
    assert %{valid?: true} = package_changeset
  end

  test "create/1 creates model without `has_many` association specified" do
    package = MyApp2.EctoFactories.create(:invalid_package)

    assert_received {:created, %{model: %MyApp2.Package{}} = package_changeset}
    assert %{valid?: true} = package_changeset
  end

  test "create/1 creates model with `belongs_to` having `has_many` associations" do
    invoice = MyApp2.EctoFactories.create(:invoice)

    assert %{title: "Invoice for shipped package", package_id: 1} = invoice
    assert_received {:created, %{model: %MyApp2.Invoice{}}}
    assert_received {:created, %{model: %MyApp2.Package{}} = package_changeset}
    assert %{valid?: true} = package_changeset
    assert %{changes: %{statuses: [%{}, %{}, %{}]}} = package_changeset
  end
end
