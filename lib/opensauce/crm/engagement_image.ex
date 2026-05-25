defmodule OpenSauce.CRM.EngagementImage do
  @moduledoc """
  A dated image attached to an Engagement — either a garden photograph or a
  garden painting.

  ## Types

  `:photo`    — A photograph of the garden taken at a point in time. Used for
                progress documentation, before/after records, and client
                communication. Not a contract item.

  `:painting` — An artistic rendering or technical drawing of the garden
                (watercolour, illustration, planting plan, etc.). These *are*
                contract items: when an engagement has at least one painting,
                invoices read "Garden as drawn, installed" / "Garden as drawn,
                maintained". Without a painting the invoice reads "Garden as
                described, installed" / "Garden as described, maintained".
                The painting is the deliverable the client is buying, making
                exact scope unambiguous at invoice time.

  ## Storage

  Images are not stored in the database — only the `storage_key` is persisted.
  The key is opaque and must be passed verbatim to `OpenSauce.Storage.url/1`
  (for rendering) or `OpenSauce.Storage.delete/1` (for cleanup). Never
  construct or parse the key outside the storage adapter.

  To upload a file:

      {:ok, key} = OpenSauce.Storage.put(
        "engagements/\#{engagement_id}",
        upload.filename,
        upload.content_type,
        File.read!(upload.path)
      )

      OpenSauce.CRM.create_engagement_image(%{
        engagement_id: engagement_id,
        type:           :painting,
        captured_on:    Date.utc_today(),
        storage_key:    key,
        content_type:   upload.content_type,
        original_filename: upload.filename
      }, actor: member, tenant: member.organisation_id)

  When deleting an image, call `OpenSauce.Storage.delete(image.storage_key)`
  *before* (or in the same transaction as) destroying the resource record so
  the file doesn't become orphaned.

  ## Dates

  `captured_on` is the date the photo was taken or the painting was completed,
  not the upload date. Clients and staff care about chronology of the garden's
  development, not about when the file landed in the system.
  """

  use Ash.Resource,
    otp_app: :opensauce,
    domain: OpenSauce.CRM,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [OpenSauce.Concerns.Multitenanted]

  postgres do
    table "crm_engagement_images"
    repo OpenSauce.Repo

    custom_indexes do
      index [:engagement_id], name: "crm_engagement_images_engagement_id_index"
      # Paintings are queried frequently for invoice description logic.
      index [:engagement_id, :type], name: "crm_engagement_images_engagement_type_index"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:engagement_id, :type, :captured_on, :storage_key, :content_type, :original_filename, :notes, :organisation_id]
    end

    # Allows updating the date and notes after upload. The storage_key and
    # content_type are immutable — to replace a file, delete and re-upload.
    update :update do
      accept [:captured_on, :notes]
    end

    # Filtered reads for common access patterns.
    read :for_engagement do
      argument :engagement_id, :uuid, allow_nil?: false
      filter expr(engagement_id == ^arg(:engagement_id))
      prepare build(sort: [captured_on: :desc])
    end

    read :paintings_for_engagement do
      argument :engagement_id, :uuid, allow_nil?: false
      filter expr(engagement_id == ^arg(:engagement_id) and type == :painting)
      prepare build(sort: [captured_on: :desc])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:staff, :manager, :owner])
    end

    policy action_type([:create, :update]) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end

    # Deleting an image is destructive and permanent (storage file must also be
    # removed by the caller). Restrict to managers and owners.
    policy action_type(:destroy) do
      authorize_if expr(^actor(:role) in [:manager, :owner])
    end
  end

  attributes do
    uuid_primary_key :id

    # :photo    — documentary photograph
    # :painting — artistic/technical rendering; a contract item
    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:photo, :painting]
    end

    # When the image was captured or the work completed — not the upload date.
    attribute :captured_on, :date do
      allow_nil? false
      public? true
    end

    # Opaque key for OpenSauce.Storage. Never construct from parts outside the
    # storage adapter — always store exactly as returned by Storage.put/4.
    attribute :storage_key, :string do
      allow_nil? false
      public? true
    end

    # MIME type as declared at upload time, e.g. "image/jpeg", "image/png",
    # "application/pdf". Used to set Content-Type when serving or downloading.
    attribute :content_type, :string do
      allow_nil? false
      public? true
    end

    # The filename as provided by the uploader — for display and download headers.
    attribute :original_filename, :string do
      allow_nil? false
      public? true
    end

    # Optional free-text description: medium, artist, revision notes, etc.
    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :engagement, OpenSauce.CRM.Engagement do
      allow_nil? false
      public? true
    end
  end
end
