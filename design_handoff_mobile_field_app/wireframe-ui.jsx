// Sketchy wireframe primitives for low-fi mobile screens.
// All components are roughly hand-drawn: slight rotation, irregular borders,
// handwritten type. Designed to look like a marker on cream paper.

const wfInk = 'oklch(0.93 0.02 80)';         // warm cream ink
const wfInkSoft = 'oklch(0.72 0.025 75)';    // muted cream
const wfInkFaint = 'oklch(0.50 0.022 70)';   // dim cream
const wfPaper = 'oklch(0.21 0.022 60)';      // dark soil — the bg
const wfSurface = 'oklch(0.26 0.024 62)';    // slightly raised surface (inputs, callouts)
const wfAccent = 'oklch(0.74 0.16 140)';     // leaf green — primary accent
const wfAccentSoft = 'oklch(0.32 0.07 140)'; // deep green wash for fills
const wfGreen = 'oklch(0.78 0.17 145)';      // brighter green for success
const wfBlue = 'oklch(0.70 0.12 70)';        // warm amber/copper (formerly blue — used for 'stored on-site')
const wfBlueSoft = 'oklch(0.30 0.06 65)';    // dark amber wash

// Tiny seeded RNG so jitters are stable per element key, not flickering on re-render.
function wfSeed(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    h = (h ^ (h >>> 16)) >>> 0;
    return h / 4294967296;
  };
}
function wfJitter(key, range = 1) {
  const r = wfSeed(key);
  return {
    x: (r() - 0.5) * 2 * range,
    y: (r() - 0.5) * 2 * range,
    rot: (r() - 0.5) * 2 * range * 0.4,
  };
}

// Phone frame — fixed 320×640 inner by default; pass `tall` (920) for the
// long-form screens like G3 (leave-job), or a numeric `height` override for
// even taller content (F1 supply run with truck picker + gauge + plants).
function WFPhone({ children, label, note, density = 'cozy', annotated = true, persona = 'field', tall = false, height = null }) {
  const innerW = 320;
  const innerH = height ?? (tall ? 920 : 640);
  const bezel = 10;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      <div
        style={{
          width: innerW + bezel * 2,
          height: innerH + bezel * 2,
          background: 'oklch(0.10 0.015 60)',
          border: `2px solid oklch(0.06 0.012 60)`,
          borderRadius: 38,
          padding: bezel,
          boxShadow: '4px 6px 0 rgba(0,0,0,0.25)',
          position: 'relative',
        }}
      >
        <div
          className="wf-phone-body"
          data-density={density}
          data-annotated={annotated ? '1' : '0'}
          data-persona={persona}
          style={{
            width: innerW,
            height: innerH,
            background: wfPaper,
            borderRadius: 28,
            overflow: 'hidden',
            position: 'relative',
            display: 'flex',
            flexDirection: 'column',
            fontFamily: '"Patrick Hand", "Caveat", cursive',
            color: wfInk,
          }}
        >
          {/* status bar */}
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              padding: '6px 18px 2px',
              fontSize: 11,
              fontFamily: '"Patrick Hand", cursive',
              color: wfInkSoft,
              flex: '0 0 auto',
            }}
          >
            <span>9:41</span>
            <span>● ● ●</span>
            <span>▮▮▮</span>
          </div>
          {children}
        </div>
        {/* notch */}
        <div
          style={{
            position: 'absolute',
            top: bezel + 4,
            left: '50%',
            transform: 'translateX(-50%)',
            width: 70,
            height: 14,
            background: 'oklch(0.05 0.01 60)',
            borderRadius: 8,
          }}
        />
      </div>
      {annotated && (label || note) && (
        <div style={{ textAlign: 'center', maxWidth: innerW + bezel * 2 }}>
          {label && (
            <div
              style={{
                fontFamily: '"Caveat", cursive',
                fontSize: 22,
                color: wfInk,
                lineHeight: 1.1,
                fontWeight: 600,
              }}
            >
              {label}
            </div>
          )}
          {note && (
            <div
              style={{
                fontFamily: '"IBM Plex Mono", monospace',
                fontSize: 10,
                color: wfInkSoft,
                marginTop: 4,
                lineHeight: 1.4,
                letterSpacing: 0.2,
              }}
            >
              {note}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// Sketchy rectangle — gives a hand-drawn rounded-rect SVG border.
function WFBox({
  children,
  k = 'b',
  style = {},
  pad = 10,
  fill = 'transparent',
  stroke = wfInk,
  strokeW = 1.5,
  radius = 8,
  dashed = false,
  thick = false,
  onClick,
}) {
  const sw = thick ? 2.4 : strokeW;
  return (
    <div
      onClick={onClick}
      style={{
        position: 'relative',
        padding: pad,
        ...style,
        cursor: onClick ? 'pointer' : style.cursor || 'inherit',
      }}
    >
      <svg
        aria-hidden
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
        preserveAspectRatio="none"
      >
        <rect
          x={sw / 2}
          y={sw / 2}
          width={`calc(100% - ${sw}px)`}
          height={`calc(100% - ${sw}px)`}
          rx={radius}
          ry={radius}
          fill={fill}
          stroke={stroke}
          strokeWidth={sw}
          strokeDasharray={dashed ? '4 3' : undefined}
          strokeLinejoin="round"
        />
      </svg>
      <div style={{ position: 'relative' }}>{children}</div>
    </div>
  );
}

// Handwritten heading
function WFH({ children, size = 18, color = wfInk, weight = 600, style = {} }) {
  return (
    <div
      style={{
        fontFamily: '"Caveat", cursive',
        fontSize: size,
        fontWeight: weight,
        color,
        lineHeight: 1.1,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// Body / label text
function WFT({ children, size = 13, color = wfInk, style = {} }) {
  return (
    <div
      style={{
        fontFamily: '"Patrick Hand", cursive',
        fontSize: size,
        color,
        lineHeight: 1.2,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// Squiggle line — placeholder for body copy
function WFSquiggle({ width = '100%', length = 1, color = wfInkSoft, height = 10 }) {
  // length: how many wavy segments
  const segs = Math.max(1, Math.round(length * 8));
  const w = 100;
  const h = 10;
  let d = `M 0 ${h / 2}`;
  for (let i = 1; i <= segs; i++) {
    const x = (w / segs) * i;
    const y = h / 2 + (i % 2 === 0 ? -1.5 : 1.5);
    d += ` Q ${x - w / (segs * 2)} ${y} ${x} ${h / 2}`;
  }
  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${w} ${h}`}
      preserveAspectRatio="none"
      aria-hidden
      style={{ display: 'block' }}
    >
      <path d={d} fill="none" stroke={color} strokeWidth={1} strokeLinecap="round" />
    </svg>
  );
}

// Multiple stacked squiggles — paragraph placeholder
function WFLines({ count = 3, width = '100%', lastShort = true, gap = 6, color = wfInkSoft }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap, width }}>
      {Array.from({ length: count }).map((_, i) => (
        <WFSquiggle
          key={i}
          color={color}
          width={lastShort && i === count - 1 ? '60%' : '100%'}
          length={1}
        />
      ))}
    </div>
  );
}

// Filled hand-drawn button
function WFBtn({ children, primary = false, size = 'md', style = {}, k = 'btn', onClick }) {
  const h = size === 'sm' ? 28 : size === 'lg' ? 44 : 36;
  const fs = size === 'sm' ? 13 : size === 'lg' ? 18 : 15;
  return (
    <WFBox
      k={k}
      onClick={onClick}
      fill={primary ? wfInk : 'transparent'}
      stroke={wfInk}
      thick={primary}
      radius={h / 2}
      pad={0}
      style={{
        height: h,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: `0 ${size === 'sm' ? 12 : 16}px`,
        minWidth: 60,
        ...style,
      }}
    >
      <span
        style={{
          fontFamily: '"Caveat", cursive',
          fontSize: fs,
          color: primary ? wfPaper : wfInk,
          fontWeight: 600,
          lineHeight: 1,
          whiteSpace: 'nowrap',
        }}
      >
        {children}
      </span>
    </WFBox>
  );
}

// Pill / chip / badge
function WFPill({ children, color = wfInk, fill = 'transparent', style = {} }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        padding: '2px 9px',
        border: `1.4px solid ${color}`,
        borderRadius: 999,
        background: fill,
        color,
        fontFamily: '"Patrick Hand", cursive',
        fontSize: 11,
        lineHeight: 1.2,
        ...style,
      }}
    >
      {children}
    </span>
  );
}

// Sketchy icon — a labeled placeholder square
function WFIcon({ label = '?', size = 22, color = wfInk, style = {} }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        border: `1.5px solid ${color}`,
        borderRadius: 6,
        fontFamily: '"Caveat", cursive',
        fontSize: size * 0.55,
        color,
        background: 'transparent',
        lineHeight: 1,
        flex: '0 0 auto',
        ...style,
      }}
    >
      {label}
    </div>
  );
}

// Annotation arrow + label — only shown when annotated tweak is on.
function WFNote({ children, side = 'right', style = {} }) {
  return (
    <div
      data-wf-anno
      style={{
        position: 'absolute',
        fontFamily: '"Caveat", cursive',
        fontSize: 14,
        color: wfAccent,
        lineHeight: 1.1,
        maxWidth: 130,
        pointerEvents: 'none',
        ...style,
      }}
    >
      <span style={{ display: 'inline-block', transform: 'rotate(-2deg)' }}>↳ {children}</span>
    </div>
  );
}

// Bottom-tab nav bar (renders 5 tabs)
function WFBottomTabs({ tabs, active = 0 }) {
  return (
    <div
      style={{
        flex: '0 0 auto',
        borderTop: `1.5px solid ${wfInk}`,
        background: wfPaper,
        padding: '6px 4px 8px',
        display: 'grid',
        gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
        gap: 2,
      }}
    >
      {tabs.map((t, i) => (
        <div
          key={i}
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 2,
            opacity: i === active ? 1 : 0.55,
          }}
        >
          <WFIcon label={t[0]} size={22} color={i === active ? wfAccent : wfInk} />
          <span
            style={{
              fontFamily: '"Patrick Hand", cursive',
              fontSize: 10,
              color: i === active ? wfAccent : wfInkSoft,
              lineHeight: 1,
            }}
          >
            {t}
          </span>
        </div>
      ))}
    </div>
  );
}

// Top app bar
function WFTopBar({ title, left, right, sub }) {
  return (
    <div
      style={{
        flex: '0 0 auto',
        padding: '4px 14px 8px',
        borderBottom: `1.5px solid ${wfInk}`,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, minHeight: 32 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 40 }}>{left}</div>
        <WFH size={20} style={{ flex: 1, textAlign: 'center' }}>{title}</WFH>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 40, justifyContent: 'flex-end' }}>
          {right}
        </div>
      </div>
      {sub && <div style={{ textAlign: 'center', marginTop: 2 }}>{sub}</div>}
    </div>
  );
}

// Scroll body region
function WFBody({ children, style = {} }) {
  return (
    <div
      style={{
        flex: '1 1 auto',
        overflow: 'hidden',
        padding: '10px 14px 14px',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// Stat / KPI tile
function WFStat({ k, value, label, color = wfInk }) {
  return (
    <WFBox k={k} pad={8} radius={10} style={{ flex: 1 }}>
      <WFH size={26} color={color} style={{ lineHeight: 1 }}>
        {value}
      </WFH>
      <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>
        {label}
      </WFT>
    </WFBox>
  );
}

// List row — compact line item
function WFRow({ title, meta, right, accent, density = 'cozy', onClick }) {
  const pad = density === 'compact' ? 6 : density === 'roomy' ? 12 : 9;
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: `${pad}px 4px`,
        borderBottom: `1px dashed ${wfInkFaint}`,
      }}
    >
      {accent && (
        <div
          style={{
            width: 4,
            height: 24,
            background: accent,
            borderRadius: 2,
            flex: '0 0 auto',
          }}
        />
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <WFT size={14} style={{ fontWeight: 600 }}>{title}</WFT>
        {meta && (
          <WFT size={11} color={wfInkSoft} style={{ marginTop: 1 }}>
            {meta}
          </WFT>
        )}
      </div>
      {right && <div style={{ flex: '0 0 auto' }}>{right}</div>}
    </div>
  );
}

// Card row — fatter, for stacked-card list style
function WFCard({ children, k = 'card', accent, pad = 10, style = {} }) {
  return (
    <WFBox k={k} pad={pad} radius={10} style={style}>
      {accent && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            background: accent,
            borderTopLeftRadius: 10,
            borderBottomLeftRadius: 10,
          }}
        />
      )}
      {children}
    </WFBox>
  );
}

// FAB
function WFFab({ children = '+', style = {}, color = wfInk }) {
  return (
    <div
      style={{
        position: 'absolute',
        right: 12,
        bottom: 70,
        width: 48,
        height: 48,
        borderRadius: 24,
        background: color,
        color: wfPaper,
        border: `2px solid ${wfInk}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: '"Caveat", cursive',
        fontSize: 30,
        fontWeight: 700,
        boxShadow: '2px 3px 0 rgba(0,0,0,0.15)',
        lineHeight: 1,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// Input placeholder
function WFInput({ placeholder, value, style = {}, k = 'in' }) {
  return (
    <WFBox k={k} pad={8} radius={6} stroke={wfInkSoft} style={{ background: wfSurface, ...style }}>
      <WFT size={13} color={value ? wfInk : wfInkFaint}>
        {value || placeholder}
      </WFT>
    </WFBox>
  );
}

// Section header
function WFSection({ title, action, style = {} }) {
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'baseline',
        marginTop: 4,
        marginBottom: 2,
        ...style,
      }}
    >
      <WFH size={17}>{title}</WFH>
      {action && (
        <WFT size={11} color={wfAccent} style={{ textDecoration: 'underline' }}>
          {action}
        </WFT>
      )}
    </div>
  );
}

Object.assign(window, {
  WFPhone, WFBox, WFH, WFT, WFSquiggle, WFLines, WFBtn, WFPill, WFIcon, WFNote,
  WFBottomTabs, WFTopBar, WFBody, WFStat, WFRow, WFCard, WFFab, WFInput, WFSection,
  wfInk, wfInkSoft, wfInkFaint, wfPaper, wfSurface, wfAccent, wfAccentSoft, wfGreen, wfBlue, wfBlueSoft, wfJitter, wfSeed,
});
