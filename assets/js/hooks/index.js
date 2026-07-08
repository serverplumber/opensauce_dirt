import { FormatPhone, FormatPostal, TitleCase } from "./formatters";
import { LogoTheme } from "./logo_theme";

const CooldownButton = {
  mounted() {
    this.seconds = parseInt(this.el.dataset.cooldown || "30", 10);
    this.originalText = this.el.textContent.trim();
    this.startCooldown();
  },
  startCooldown() {
    this.el.disabled = true;
    let remaining = this.seconds;
    this.el.textContent = `Resend in ${remaining}s`;
    this.timer = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) {
        clearInterval(this.timer);
        this.el.disabled = false;
        this.el.textContent = this.originalText;
      } else {
        this.el.textContent = `Resend in ${remaining}s`;
      }
    }, 1000);
  },
  updated() {
    if (!this.el.disabled) {
      this.startCooldown();
    }
  },
  destroyed() {
    clearInterval(this.timer);
  },
};

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
  },
  CooldownButton,
  FormatPhone,
  FormatPostal,
  LogoTheme,
  TitleCase,
};

export default Hooks;
