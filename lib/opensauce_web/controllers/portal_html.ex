defmodule OpenSauceWeb.PortalHTML do
  @moduledoc false
  use OpenSauceWeb, :html

  def check_email(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title>Check your email</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}body{background:<%= @brand.bg %>;color:<%= @brand.text %>;font-family:'Hanken Grotesk',system-ui,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;-webkit-font-smoothing:antialiased}
        </style>
      </head>
      <body>
        <div style="max-width:360px;width:100%;text-align:center;">
          <div style={"width:56px;height:56px;border-radius:50%;background:#{OpenSauce.BrandTheme.rgba(@accent, 0.12)};border:1.5px solid #{OpenSauce.BrandTheme.rgba(@accent, 0.3)};display:flex;align-items:center;justify-content:center;margin:0 auto 20px;"}>
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke={@accent}
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
              <polyline points="22,6 12,13 2,6" />
            </svg>
          </div>
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.02em;margin-bottom:10px;">
            Check your email
          </h1>
          <p style={"font-size:14px;color:#{@brand.muted};line-height:1.6;"}>
            We've sent an access link to your email address. Click it to view your document.
          </p>
          <p style={"font-size:12px;color:#{@brand.dim};margin-top:16px;"}>
            The link expires in 48 hours.
          </p>
          <p
            :if={@org_name}
            style={"font-size:12px;color:#{@brand.dim};margin-top:24px;border-top:1px solid #{OpenSauce.BrandTheme.rgba(@brand.border, 0.58)};padding-top:16px;"}
          >
            Sent by {@org_name}
          </p>
        </div>
      </body>
    </html>
    """
  end

  def invalid_link(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width,initial-scale=1" />
        <title>Link expired</title>
        <style>
          *{box-sizing:border-box;margin:0;padding:0}body{background:#16140E;color:#F4EFE2;font-family:'Hanken Grotesk',system-ui,sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;-webkit-font-smoothing:antialiased}
        </style>
      </head>
      <body>
        <div style="max-width:360px;width:100%;text-align:center;">
          <h1 style="font-family:'Bricolage Grotesque',sans-serif;font-size:22px;font-weight:700;letter-spacing:-0.02em;margin-bottom:10px;">
            Link expired
          </h1>
          <p style="font-size:14px;color:#9A9384;line-height:1.6;">
            This link is no longer valid. Ask your provider to send a new one.
          </p>
        </div>
      </body>
    </html>
    """
  end
end
