// FormatPhone — formats North American numbers to (xxx) xxx-xxxx as you type
export const FormatPhone = {
  mounted() {
    this._fmt = () => {
      const d = this.el.value.replace(/\D/g, "").slice(0, 10);
      let out = d;
      if (d.length > 6) out = `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`;
      else if (d.length > 3) out = `(${d.slice(0, 3)}) ${d.slice(3)}`;
      if (this.el.value !== out) this.el.value = out;
    };
    this.el.addEventListener("input", this._fmt);
    this._fmt();
  },
  destroyed() { this.el.removeEventListener("input", this._fmt); },
};

// FormatPostal — Canadian A1A 1A1, uppercase as you type
export const FormatPostal = {
  mounted() {
    this._fmt = () => {
      const clean = this.el.value.replace(/\s/g, "").toUpperCase().slice(0, 6);
      const out = clean.length > 3 ? `${clean.slice(0, 3)} ${clean.slice(3)}` : clean;
      if (this.el.value !== out) this.el.value = out;
    };
    this.el.addEventListener("input", this._fmt);
    this._fmt();
  },
  destroyed() { this.el.removeEventListener("input", this._fmt); },
};

// TitleCase — capitalises each word on blur (city names, country)
export const TitleCase = {
  mounted() {
    this._fmt = () => {
      const out = this.el.value.replace(/\b\w/g, (c) => c.toUpperCase());
      if (this.el.value !== out) this.el.value = out;
    };
    this.el.addEventListener("blur", this._fmt);
  },
  destroyed() { this.el.removeEventListener("blur", this._fmt); },
};
