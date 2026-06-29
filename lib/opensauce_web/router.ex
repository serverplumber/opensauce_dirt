# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.Router do
  use OpenSauceWeb, :router
  use AshAuthentication.Phoenix.Router

  #
  # Plugs
  #
  # Content Security Policy compatible with LiveView and topbar
  @csp Enum.join(
         [
           "default-src 'self'",
           "base-uri 'self'",
           "frame-ancestors 'self'",
           "img-src 'self' data: blob:",
           "style-src 'self' 'unsafe-inline'",
           "font-src 'self' data:",
           "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
           "connect-src 'self' ws: wss:"
         ],
         "; "
       )

  def put_session_timezone(conn, _opts) do
    timezone = conn.cookies["timezone"]
    put_session(conn, "timezone", timezone)
  end

  #
  # Pipelines
  #

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OpenSauceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
    plug :load_from_session
    plug :put_session_timezone
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug OpenSauceWeb.Plugs.ApiKeyAuth
  end

  pipeline :calendar_api do
    plug :fetch_query_params
    plug OpenSauceWeb.Plugs.CalendarApiKeyAuth
  end

  #
  # Public Routes
  #

  scope "/", OpenSauceWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Authentication Routes
    # Own the magic-link redemption GET so there's no intermediate confirm page.
    get "/auth/user/magic_link", AuthController, :redeem_magic_link

    auth_routes AuthController, OpenSauce.Accounts.User, path: "/auth"
    sign_out_route AuthController

    ash_authentication_live_session :sign_in_routes,
      on_mount: [{OpenSauceWeb.LiveUserAuth, :live_no_user}] do
      live "/sign-in", MobileSignInLive, :index
    end
  end

  #
  # Customer Portal Routes (token-based session, no staff auth)
  #

  scope "/c", OpenSauceWeb do
    pipe_through :browser

    get "/view/:token", PortalController, :view
    get "/access/:token", PortalController, :access
    get "/expired", PortalController, :expired

    live_session :portal,
      layout: {OpenSauceWeb.Layouts, :portal},
      on_mount: [{OpenSauceWeb.PortalAuth, :require_customer}] do
      live "/invoice/:id", PortalLive.Invoice, :show
      live "/estimate/:id", PortalLive.Estimate, :show
    end
  end

  #
  # Org Picker Routes (authenticated user, no org selected yet)
  #

  scope "/org", OpenSauceWeb do
    pipe_through :browser

    get "/pick/:id", OrgController, :pick

    ash_authentication_live_session :org_routes,
      on_mount: [{OpenSauceWeb.LiveUserAuth, :live_user_required}] do
      live "/pick", OrgPickLive, :index
      live "/new", OrgNewLive, :index
    end
  end

  #
  # Authenticated Routes
  #

  scope "/", OpenSauceWeb do
    pipe_through :browser

    # Manager Routes
    ash_authentication_live_session :admin_routes,
      on_mount: [
        {OpenSauceWeb.LiveUserAuth, :live_manager_required},
        OpenSauceWeb.LiveCurrentPath,
        OpenSauceWeb.LiveNav,
        OpenSauceWeb.LiveSettings
      ] do
      # Job Routes
      live "/manage/jobs", JobLive.Index, :index
      live "/manage/jobs/:id/edit", JobLive.Index, :edit
      live "/manage/jobs/:id/closeout", JobLive.Closeout, :index
      live "/manage/jobs/adhoc", JobLive.Adhoc, :index

      # Venue Routes
      live "/manage/venues", VenueLive.Index, :index
      live "/manage/venues/new", VenueLive.Index, :new
      live "/manage/venues/:id", VenueLive.Show, :show
      live "/manage/venues/:id/edit", VenueLive.Show, :edit

      # Org edit (owner-accessible via account page)
      live "/manage/org", OrgLive, :index
    end

    # Staff Routes
    ash_authentication_live_session :manage_routes,
      on_mount: [
        {OpenSauceWeb.LiveUserAuth, :live_staff_required},
        OpenSauceWeb.LiveCurrentPath,
        OpenSauceWeb.LiveNav,
        OpenSauceWeb.LiveSettings,
        OpenSauceWeb.LiveShift
      ] do
      # Job creation, detail, arrive + materials
      live "/manage/jobs/new", JobLive.New, :index
      live "/manage/jobs/:id/arrive", JobLive.Arrive, :index
      live "/manage/jobs/:id/materials", JobLive.Materials, :index
      live "/manage/jobs/:id", JobLive.Show, :show

      # Scheduling board
      live "/manage/schedule", ScheduleLive, :index

      # Today dashboard
      live "/manage/today", TodayLive, :index

      # Shift flows
      live "/manage/shifts/start", ShiftLive.Start, :index
      live "/manage/shifts/current", ShiftLive.Summary, :index

      # Account
      live "/manage/account", AccountLive, :index

      # Inventory
      live "/manage/inventory", InventoryLive.Index, :index
      live "/manage/inventory/new", InventoryLive.Index, :new
      live "/manage/inventory/:sku", InventoryLive.Show, :show
      live "/manage/inventory/:sku/details", InventoryLive.Show, :details
      live "/manage/inventory/:sku/stock", InventoryLive.Show, :stock
      live "/manage/inventory/:sku/edit", InventoryLive.Show, :edit
      live "/manage/inventory/:sku/adjust", InventoryLive.Show, :adjust

      # Invoices
      live "/manage/invoices", InvoiceLive.Index, :index
      live "/manage/invoices/new", InvoiceLive.New, :new
      live "/manage/invoices/:id", InvoiceLive.Show, :show
      live "/manage/invoices/:id/edit", InvoiceLive.Edit, :edit

      # Purchasing
      live "/manage/purchasing", PurchasingLive.Index, :index
      # Specific suppliers routes must come before the catch-all :po_ref
      live "/manage/purchasing/suppliers", PurchasingLive.Suppliers, :index
      live "/manage/purchasing/suppliers/new", PurchasingLive.Suppliers, :new
      live "/manage/purchasing/suppliers/:id/edit", PurchasingLive.Suppliers, :edit
      live "/manage/purchasing/suppliers/:id/import", PurchasingLive.CatalogImport, :import
      # Purchase order routes (by reference)
      live "/manage/purchasing/:po_ref", PurchasingLive.Show, :show
      live "/manage/purchasing/:po_ref/items", PurchasingLive.Show, :items
      live "/manage/purchasing/:po_ref/add_item", PurchasingLive.Show, :add_item
      live "/manage/purchasing/:po_ref/lineup", PurchasingLive.Show, :lineup

      # Customers
      live "/manage/customers", CustomerLive.Index, :index
      live "/manage/customers/new", CustomerLive.New, :index
      live "/manage/customers/:reference", CustomerLive.Show, :show
      live "/manage/customers/:reference/details", CustomerLive.Show, :details
      live "/manage/customers/:reference/statistics", CustomerLive.Show, :statistics
      live "/manage/customers/:reference/edit", CustomerLive.Show, :edit
      live "/manage/customers/:reference/engagements", CustomerLive.Show, :engagements
      live "/manage/customers/:reference/engagements/new", EngagementLive.New, :new
      live "/manage/customers/:reference/engagements/:engagement_id", EngagementLive.Show, :show

      live "/manage/customers/:reference/engagements/:engagement_id/edit",
           EngagementLive.New,
           :edit

      live "/manage/customers/:reference/engagements/:engagement_id/materials",
           EngagementLive.Materials,
           :index

      live "/manage/customers/:reference/engagements/:engagement_id/estimate",
           EngagementLive.Estimate,
           :show

      # Production
    end
  end

  #
  # API Routes
  #

  scope "/api/json" do
    pipe_through :api
    forward "/", OpenSauceWeb.JsonApiRouter
  end

  scope "/api/graphql" do
    pipe_through :api
    forward "/", Absinthe.Plug, schema: OpenSauceWeb.Schema
  end

  scope "/api/calendar" do
    pipe_through :calendar_api
    get "/feed.ics", OpenSauceWeb.CalendarController, :feed
  end

  #
  # Development Routes
  #

  if Application.compile_env(:opensauce, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview

      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: OpenSauceWeb.Schema,
        interface: :playground
    end
  end

  #
  # Content Security Policy
  #
  # Phoenix 1.8 secures defaults in `put_secure_browser_headers`. We provide an
  # explicit CSP compatible with LiveView, topbar, and dev websocket connections.
  # Tighten as needed for your deployment.
  defp put_csp(conn, _opts), do: Plug.Conn.put_resp_header(conn, "content-security-policy", @csp)
end
