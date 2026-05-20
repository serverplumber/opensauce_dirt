defmodule OpenSauce.CRM.Engagement.Painting do
  @moduledoc false
  use Waffle.Definition

  @versions [:original]

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    if file_extension in ~w(.jpg .jpeg .png .gif .webp .pdf) do
      :ok
    else
      {:error, "invalid file type"}
    end
  end

  def filename(_version, {file, _}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def storage_dir(_version, {_file, engagement}) do
    "uploads/engagements/#{engagement.id}/painting"
  end
end
