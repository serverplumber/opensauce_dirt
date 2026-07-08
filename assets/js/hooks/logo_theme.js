import {
  QuantizerCelebi,
  Score,
  themeFromSourceColor,
  hexFromArgb,
} from "../../vendor/material-color-utilities";

// Extracts Material-You colour schemes from the chosen colour-logo file and
// pushes the hexes to the LiveView, which stores them on the organisation.
// The scorer ranks several candidate colours; all are pushed so the org
// screen can offer them as tappable accent swatches. Runs once at upload
// time; documents and emails read the stored hexes.

// Quantization runs over every pixel, synchronously on the main thread — a
// full-resolution logo freezes the tab long enough for the LiveView socket
// to time out and kill the upload. Colour extraction doesn't need
// resolution, so downscale first.
const MAX_EXTRACT_PX = 128;
const MAX_CANDIDATES = 6;

function opaquePixels(img) {
  const scale = Math.min(1, MAX_EXTRACT_PX / Math.max(img.naturalWidth, img.naturalHeight));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(img.naturalWidth * scale));
  canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
  const ctx = canvas.getContext("2d");
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const pixels = [];
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 255) continue; // transparent logo background
    pixels.push(((255 << 24) | (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]) >>> 0);
  }
  return pixels;
}

export const LogoTheme = {
  // Attached to the label wrapping the file input, not the input itself:
  // live_file_input carries data-phx-hook="Phoenix.LiveFileUpload" and LiveView
  // mounts one hook per element (data-phx-hook wins), so a phx-hook placed on
  // the input silently never mounts. The change event bubbles up to the label.
  mounted() {
    this.onChange = (e) => {
      const file = e.target.files && e.target.files[0];
      if (file) this.extract(file);
    };
    this.el.addEventListener("change", this.onChange);
  },
  destroyed() {
    this.el.removeEventListener("change", this.onChange);
  },
  async extract(file) {
    const url = URL.createObjectURL(file);
    try {
      const img = new Image();
      img.src = url;
      await img.decode();
      const ranked = Score.score(QuantizerCelebi.quantize(opaquePixels(img), 128), {
        desired: MAX_CANDIDATES,
      });
      const roles = (scheme) => ({
        primary: hexFromArgb(scheme.primary),
        on_primary: hexFromArgb(scheme.onPrimary),
        primary_container: hexFromArgb(scheme.primaryContainer),
        on_primary_container: hexFromArgb(scheme.onPrimaryContainer),
      });
      // Screen surfaces from the neutral tonal palettes — the same structure
      // as the soil palette (bg / paper / border / text / muted / dim) but
      // tinted with the logo's hue, in both modes. Tones chosen to match the
      // soil palette's contrast structure.
      const screen = (p) => ({
        dark: {
          bg: hexFromArgb(p.neutral.tone(6)),
          paper: hexFromArgb(p.neutral.tone(12)),
          border: hexFromArgb(p.neutralVariant.tone(24)),
          text: hexFromArgb(p.neutral.tone(95)),
          muted: hexFromArgb(p.neutralVariant.tone(70)),
          dim: hexFromArgb(p.neutralVariant.tone(50)),
        },
        light: {
          bg: hexFromArgb(p.neutral.tone(95)),
          paper: hexFromArgb(p.neutral.tone(99)),
          border: hexFromArgb(p.neutralVariant.tone(80)),
          text: hexFromArgb(p.neutral.tone(10)),
          muted: hexFromArgb(p.neutralVariant.tone(45)),
          dim: hexFromArgb(p.neutralVariant.tone(65)),
        },
      });
      const candidates = ranked.slice(0, MAX_CANDIDATES).map((argb) => {
        const theme = themeFromSourceColor(argb);
        return {
          source: hexFromArgb(argb),
          light: roles(theme.schemes.light),
          dark: roles(theme.schemes.dark),
          screen: screen(theme.palettes),
        };
      });
      this.pushEvent("brand_theme_extracted", {
        theme: { ...candidates[0], candidates },
      });
    } catch (e) {
      // Best-effort: without a theme, documents fall back to the leaf palette.
      console.error("LogoTheme extraction failed:", e);
    } finally {
      URL.revokeObjectURL(url);
    }
  },
};
