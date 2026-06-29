defmodule OpenSauce.CRM.Engagement.Signature do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :signed_by_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :signed_by_email, :string do
      allow_nil? false
      public? true
    end

    attribute :signed_at, :utc_datetime do
      allow_nil? false
      public? true
    end

    attribute :signed_from_ip, :string do
      allow_nil? false
      public? true
    end

    attribute :user_agent, :string do
      allow_nil? true
      public? true
    end

    # Snapshot of the engagement terms at the moment of signing.
    attribute :engagement_snapshot, :map do
      allow_nil? false
      public? true
    end

    # Full text of each sign-off item the client explicitly checked before signing.
    # Each entry: %{"label" => string, "body" => string | nil}
    attribute :agreed_items, {:array, :map} do
      allow_nil? true
      public? true
      default []
    end

    # The exact words the signer agreed to (rendered consent copy, not a reference).
    attribute :consent_text, :string do
      allow_nil? false
      public? true
    end
  end
end
