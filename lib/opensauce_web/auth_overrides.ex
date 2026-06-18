# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauceWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "grid h-screen place-items-center dark:bg-stone-50"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :root_class, """
    flex-1 flex flex-col justify-center py-12 px-4 sm:px-6 lg:flex-none
    lg:px-20 xl:px-24 border rounded-md border border-stone-300 bg-stone-200/30
    """

    set :show_banner, false
    set :strategy_class, "mx-auto w-full max-w-sm lg:w-96"

    set :authentication_error_container_class, "text-black dark:text-stone-900 text-center"
    set :authentication_error_text_class, ""
  end

  override AshAuthentication.Phoenix.Components.Banner do
    set :root_class, "w-full flex justify-center py-2"
    set :href_class, nil
    set :href_url, "/"
    set :image_class, "block dark:hidden"
    set :dark_image_class, "hidden dark:block"
    set :image_url, "https://ash-hq.org/images/ash-framework-light.png"
    set :dark_image_url, "https://ash-hq.org/images/ash-framework-dark.png"
    set :text_class, nil
    set :text, nil
  end

  override AshAuthentication.Phoenix.Components.HorizontalRule do
    set :root_class, "relative my-2"
    set :hr_outer_class, "absolute inset-0 flex items-center"
    set :hr_inner_class, "w-full border-t border-stone-300 dark:border-stone-700"
    set :text_outer_class, "relative flex justify-center text-sm"

    set :text_inner_class,
        "px-2 bg-white text-stone-400 font-medium dark:bg-stone-50 dark:text-neutral-900"

    set :text, "or"
  end

  override AshAuthentication.Phoenix.Components.MagicLink do
    set :root_class, "mt-4 mb-4"

    set :label_class,
        "mt-2 mb-4 text-2xl tracking-tight font-bold text-stone-900 dark:text-stone-900"

    set :form_class, nil

    set :request_flash_text,
        "If this user exists in our database you will contacted with a sign-in link shortly."

    set :disable_button_text, "Requesting ..."
  end

  override AshAuthentication.Phoenix.Components.OAuth2 do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center py-2 px-4 border border-transparent rounded-md
    text-sm font-medium text-black bg-stone-200 hover:bg-stone-300
    focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
    inline-flex items-center
    """

    set :icon_class, "-ml-0.4 mr-2 h-4 w-4"
  end

  override AshAuthentication.Phoenix.Components.Apple do
    set :root_class, "w-full mt-2 mb-4"

    set :link_class, """
    w-full flex justify-center px-4 border border-transparent rounded-md
    text-sm font-medium text-white bg-black focus:outline-none
    focus:ring-2 focus:ring-offset-2 focus:ring-black inline-flex items-center
    dark:bg-white dark:text-black dark:ring-white
    """

    set :icon_class, ""
  end
end
