// Mobile-first wireframe screens for OpenSauce.
// Each exported component returns a single phone-sized body (inside WFPhone)
// showing one variant. Inline annotation notes appear only when annotated
// tweak is on.

// ─────────────────────────────────────────────────────────────────────────────
// Shared nav configs
// ─────────────────────────────────────────────────────────────────────────────

const TABS_FIELD = ['Today', 'Jobs', 'Customers', 'POs', 'More'];
const TABS_ADMIN = ['Today', 'Jobs', 'Customers', 'POs', 'More'];

function tabsFor(persona) {
  return persona === 'admin' ? TABS_ADMIN : TABS_FIELD;
}

// Render the nav element chosen by the current tweak.
function WFNavStrip({ pattern, active = 0, persona = 'field' }) {
  const tabs = tabsFor(persona);
  if (pattern === 'drawer') {
    return (
      <div
        style={{
          flex: '0 0 auto',
          padding: '8px 14px',
          borderTop: `1.5px solid ${wfInk}`,
          background: wfPaper,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
        
        <WFT size={12} color={wfInkSoft}>≡ open drawer</WFT>
        <WFT size={11} color={wfInkFaint}>swipe from edge</WFT>
      </div>);

  }
  if (pattern === 'tiles') {
    // tiles pattern: a tiny "home" button only
    return (
      <div
        style={{
          flex: '0 0 auto',
          padding: '8px 14px',
          borderTop: `1.5px solid ${wfInk}`,
          background: wfPaper,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 14
        }}>
        
        <WFIcon label="⌂" size={22} />
        <WFT size={12} color={wfInkSoft}>tap home to return</WFT>
      </div>);

  }
  return <WFBottomTabs tabs={tabs} active={active} />;
}

// ─────────────────────────────────────────────────────────────────────────────
// A · Home / Dashboard variants
// ─────────────────────────────────────────────────────────────────────────────

// A1 — "Today first": single-purpose feed of today's work.
function ScreenA1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="today"
        left={<WFIcon label="⌂" size={22} color={wfInkSoft} />}
        right={<WFIcon label="🔍" size={22} color={wfInkSoft} />} />
      
      <WFBody>
        <WFBox k="a1-shift" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
              <div
                style={{
                  border: `2px solid ${wfAccent}`,
                  borderRadius: 8,
                  width: 36,
                  height: 36,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: '"Caveat", cursive',
                  fontSize: 22,
                  fontWeight: 700,
                  color: wfAccent,
                  flex: '0 0 auto',
                  marginTop: 2
                }}
                title="shift 1 of the day">
                
                S1
              </div>
              <div>
                <WFT size={11} color={wfAccent} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>on shift · 2h 14m</WFT>
                <WFH size={20} color={wfInk} style={{ marginTop: 2 }}>at Greenwood</WFH>
                <WFT size={11} color={wfInkSoft}>started 8:42 from Hadlow · odo 48,224 km</WFT>
              </div>
            </div>
            <WFBtn k="a1-end" size="sm">end shift</WFBtn>
          </div>
        </WFBox>

        <WFSection title="here now" />
        <WFCard k="a1-now" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <WFT size={14} style={{ fontWeight: 600 }}>Greenwood Estate</WFT>
              <WFT size={11} color={wfInkSoft}>hedge trim · arrived 9:02 · Sam + Joe</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>on&nbsp;site</WFPill>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <WFBtn k="a1-plant" size="sm">+ planted</WFBtn>
            <WFBtn k="a1-mat" size="sm">+ material</WFBtn>
            <WFBtn k="a1-leave" size="sm" primary>leave →</WFBtn>
          </div>
        </WFCard>

        <WFSection title="up next" />
        <WFCard k="a1-up1">
          <WFT size={13} style={{ fontWeight: 600 }}>Marshfield bedding</WFT>
          <WFT size={11} color={wfInkSoft}>11:30 — plant out · 1 crew · 13 km</WFT>
        </WFCard>
        <WFCard k="a1-up2">
          <WFT size={13} style={{ fontWeight: 600 }}>St Anne's churchyard</WFT>
          <WFT size={11} color={wfInkSoft}>2:00 — mow · 2 crew · 22 km</WFT>
        </WFCard>

        <WFSection title="needs you" />
        <WFRow
          title="Mulch — low stock"
          meta="2 bags left · used 4/wk"
          right={<WFPill color={wfAccent}>order</WFPill>}
          density={density} />
        
        <WFRow
          title="PO #2027 — confirm price"
          meta="Cramer · 12 items"
          right={<WFPill>open</WFPill>}
          density={density} />
        
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 100, right: -130 }}>
            shift state pinned · timer, depart point, odo
          </WFNote>
          <WFNote style={{ top: 230, right: -130 }}>
            current location = 'here now' · JobEvent quick-adds
          </WFNote>
          <WFNote style={{ bottom: 150, right: -130 }}>
            'needs you' = inbox of small decisions
          </WFNote>
        </>
      }
    </>);

}

// A2 — Tile grid: no persistent nav, big section tiles like a home screen.
function ScreenA2({ pattern, persona, density, annotated }) {
  const tiles = [
  { label: 'Today', meta: '3 jobs', icon: '●', accent: wfAccent },
  { label: 'Schedule', meta: 'this week', icon: '▤', accent: wfInk },
  { label: 'Stock', meta: '2 low', icon: '▥', accent: wfInk },
  { label: 'POs', meta: '1 draft', icon: '⌖', accent: wfInk },
  { label: 'Customers', meta: '24', icon: '☻', accent: wfInk },
  { label: 'Invoices', meta: '4 due', icon: '✪', accent: wfInk }];

  return (
    <>
      <WFTopBar
        title="opensauce"
        right={<WFIcon label="☺" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 14 }}>
        <div>
          <WFH size={22}>g'morning, Sam</WFH>
          <WFT size={12} color={wfInkSoft}>Tuesday · sunny 14°</WFT>
        </div>

        <WFInput k="a2-search" placeholder="🔍 search by latin or common name…" />

        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 10
          }}>
          
          {tiles.map((t, i) =>
          <WFBox key={i} k={`a2-t${i}`} pad={12} radius={12} thick={i === 0} style={{ minHeight: 90 }}>
              <WFIcon label={t.icon} size={26} color={t.accent} />
              <WFH size={20} style={{ marginTop: 6 }}>{t.label}</WFH>
              <WFT size={11} color={wfInkSoft}>{t.meta}</WFT>
            </WFBox>
          )}
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            'apps' layout — no chrome, just destinations
          </WFNote>
          <WFNote style={{ top: 280, right: -130 }}>
            tile #1 = today's job, sized + accented
          </WFNote>
        </>
      }
    </>);

}

// A3 — Action-first: big quick actions on top, recent items below.
function ScreenA3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="hi sam"
        left={<WFIcon label="☰" size={22} color={wfInkSoft} />}
        right={<WFIcon label="🔍" size={22} color={wfInkSoft} />} />
      
      <WFBody>
        <WFSection title="quick" />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <WFBox k="a3-q1" pad={10} radius={10} thick>
            <WFIcon label="+" size={22} />
            <WFH size={17} style={{ marginTop: 4 }}>log materials</WFH>
            <WFT size={10} color={wfInkSoft}>on a job</WFT>
          </WFBox>
          <WFBox k="a3-q2" pad={10} radius={10}>
            <WFIcon label="❀" size={22} />
            <WFH size={17} style={{ marginTop: 4 }}>find plant</WFH>
            <WFT size={10} color={wfInkSoft}>by latin</WFT>
          </WFBox>
          <WFBox k="a3-q3" pad={10} radius={10}>
            <WFIcon label="◐" size={22} />
            <WFH size={17} style={{ marginTop: 4 }}>start job</WFH>
            <WFT size={10} color={wfInkSoft}>clock in</WFT>
          </WFBox>
          <WFBox k="a3-q4" pad={10} radius={10}>
            <WFIcon label="□" size={22} />
            <WFH size={17} style={{ marginTop: 4 }}>new PO</WFH>
            <WFT size={10} color={wfInkSoft}>order parts</WFT>
          </WFBox>
        </div>

        <WFSection title="recent" action="all" />
        <WFRow
          title="Greenwood — hedge trim"
          meta="started 14 min ago"
          accent={wfAccent}
          right={<WFT size={11} color={wfAccent}>live</WFT>}
          density={density} />
        
        <WFRow
          title="PO #2027 received"
          meta="Cramer · yesterday"
          density={density} />
        
        <WFRow
          title="Mulch stock low"
          meta="2 bags · was 18 last wk"
          density={density} />
        
        <WFRow
          title="Inv #441 sent"
          meta="St Anne's · £2,240"
          density={density} />
        
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -130 }}>
            4 fat actions = thumbs on a glove
          </WFNote>
          <WFNote style={{ bottom: 160, right: -130 }}>
            recent ≠ today — chronological breadcrumb
          </WFNote>
        </>
      }
    </>);

}

// A4 — Inbox / feed: chronological list of everything that happened.
function ScreenA4({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="feed"
        left={<WFIcon label="☰" size={22} color={wfInkSoft} />}
        right={<WFPill color={wfAccent} fill={wfAccentSoft}>4 new</WFPill>} />
      
      <WFBody style={{ gap: 6 }}>
        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>today · tue 12</WFT>
        <WFCard k="a4-1" accent={wfAccent} pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>job started</WFT>
            <WFT size={11} color={wfInkSoft}>9:02</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Greenwood · hedge trim · Sam + Joe</WFT>
        </WFCard>
        <WFCard k="a4-2" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>stock low</WFT>
            <WFT size={11} color={wfInkSoft}>8:14</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Mulch · 2 bags left</WFT>
        </WFCard>
        <WFCard k="a4-3" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>PO arrived</WFT>
            <WFT size={11} color={wfInkSoft}>7:40</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Cramer · 12 items · £420</WFT>
        </WFCard>

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 6 }}>yesterday</WFT>
        <WFCard k="a4-4" pad={8}>
          <WFT size={13} style={{ fontWeight: 600 }}>invoice sent</WFT>
          <WFT size={11} color={wfInkSoft}>St Anne's · £2,240</WFT>
        </WFCard>
        <WFCard k="a4-5" pad={8}>
          <WFT size={13} style={{ fontWeight: 600 }}>job complete</WFT>
          <WFT size={11} color={wfInkSoft}>Marshfield · plant out</WFT>
        </WFCard>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -130 }}>
            everything in one timeline, like email
          </WFNote>
          <WFNote style={{ bottom: 200, right: -130 }}>
            day dividers anchor scroll
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// B · Jobs (list + detail)
// ─────────────────────────────────────────────────────────────────────────────

// B1 — Stacked cards grouped by date.
function ScreenB1({ pattern, persona, density, annotated }) {
  const Card = ({ k, name, when, status, statusColor, crew, hours }) =>
  <WFCard k={k} accent={statusColor}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <WFT size={14} style={{ fontWeight: 600 }}>{name}</WFT>
        <WFPill color={statusColor}>{status}</WFPill>
      </div>
      <WFT size={11} color={wfInkSoft}>{when} · {crew}</WFT>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
        <WFT size={11} color={wfInkSoft}>⏱ {hours}</WFT>
        <WFT size={11} color={wfInkSoft}>£ —</WFT>
      </div>
    </WFCard>;

  return (
    <>
      <WFTopBar
        title="jobs"
        left={<WFIcon label="☰" size={22} color={wfInkSoft} />}
        right={
        <div style={{ display: 'flex', gap: 6 }}>
            <WFIcon label="🔍" size={22} color={wfInkSoft} />
            <WFIcon label="+" size={22} color={wfAccent} />
          </div>
        }
        sub={
        <div style={{ display: 'flex', gap: 6, justifyContent: 'center', marginTop: 4 }}>
            <WFPill fill={wfInk} color={wfPaper}>all</WFPill>
            <WFPill>mine</WFPill>
            <WFPill>open</WFPill>
            <WFPill>done</WFPill>
          </div>
        } />
      
      <WFBody style={{ gap: 8 }}>
        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>today · tue 12</WFT>
        <Card k="b1-a" name="Greenwood Estate" when="9:00 hedge trim" status="live" statusColor={wfAccent} crew="Sam+Joe" hours="0:14 of 4" />
        <Card k="b1-b" name="Marshfield" when="11:30 plant out" status="next" statusColor={wfInk} crew="Joe" hours="—" />
        <Card k="b1-c" name="St Anne's" when="2:00 mow" status="next" statusColor={wfInk} crew="Sam" hours="—" />

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 6 }}>tomorrow · wed 13</WFT>
        <Card k="b1-d" name="Rosehill (new)" when="9:00 survey" status="todo" statusColor={wfInkSoft} crew="Sam" hours="—" />
        <Card k="b1-e" name="Greenwood (return)" when="1:00 mulch" status="todo" statusColor={wfInkSoft} crew="Joe" hours="—" />
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -130 }}>
            filter chips replace desktop table filters
          </WFNote>
          <WFNote style={{ top: 240, right: -130 }}>
            accent stripe = status at a glance
          </WFNote>
        </>
      }
    </>);

}

// B2 — Agenda timeline (vertical ticks)
function ScreenB2({ pattern, persona, density, annotated }) {
  const slot = (k, time, name, meta, accent) =>
  <div key={k} style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
      <div style={{ width: 42, flex: '0 0 auto' }}>
        <WFT size={11} color={wfInkSoft}>{time}</WFT>
      </div>
      <div
      style={{
        width: 10,
        flex: '0 0 auto',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        alignSelf: 'stretch'
      }}>
      
        <div style={{ width: 8, height: 8, borderRadius: 4, background: accent || wfInk, marginTop: 4 }} />
        <div style={{ flex: 1, width: 1.5, background: wfInkFaint, marginTop: 2 }} />
      </div>
      <WFBox k={k} pad={8} radius={8} style={{ flex: 1 }}>
        <WFT size={13} style={{ fontWeight: 600 }}>{name}</WFT>
        <WFT size={11} color={wfInkSoft}>{meta}</WFT>
      </WFBox>
    </div>;

  return (
    <>
      <WFTopBar
        title="schedule"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="📅" size={22} color={wfInkSoft} />}
        sub={
        <div style={{ display: 'flex', gap: 4, justifyContent: 'center', marginTop: 4 }}>
            <WFPill>mon</WFPill>
            <WFPill fill={wfInk} color={wfPaper}>tue 12</WFPill>
            <WFPill>wed</WFPill>
            <WFPill>thu</WFPill>
            <WFPill>fri</WFPill>
          </div>
        } />
      
      <WFBody style={{ gap: 8 }}>
        {slot('b2-1', '9:00', 'Greenwood hedge', '2h · Sam+Joe · live', wfAccent)}
        {slot('b2-2', '11:30', 'Marshfield plant', '1.5h · Joe')}
        {slot('b2-3', '1:00', 'lunch', '30m')}
        {slot('b2-4', '2:00', 'St Anne\'s mow', '2h · Sam')}
        {slot('b2-5', '4:30', 'depot return', '20m')}
      </WFBody>
      {annotated &&
      <WFNote style={{ top: 150, right: -130 }}>
          day-strip in header = ±1 wk in a swipe
        </WFNote>
      }
    </>);

}

// B3 — Map + list hybrid
function ScreenB3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="jobs · map"
        left={<WFIcon label="☰" size={22} color={wfInkSoft} />}
        right={
        <div style={{ display: 'flex', gap: 4 }}>
            <WFPill fill={wfInk} color={wfPaper}>map</WFPill>
            <WFPill>list</WFPill>
          </div>
        } />
      
      <WFBody style={{ padding: 0, gap: 0 }}>
        {/* map placeholder */}
        <div
          style={{
            height: 200,
            background:
            `repeating-linear-gradient(45deg, ${wfInkFaint}22 0 6px, transparent 6px 14px), ${wfPaper}`,
            position: 'relative',
            borderBottom: `1.5px solid ${wfInk}`
          }}>
          
          {/* roads */}
          <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
            <path d="M 0 90 Q 80 60 160 110 T 320 80" fill="none" stroke={wfInkSoft} strokeWidth={2} strokeLinecap="round" />
            <path d="M 40 0 L 180 200" fill="none" stroke={wfInkSoft} strokeWidth={2} strokeLinecap="round" />
            <path d="M 240 0 Q 200 100 280 200" fill="none" stroke={wfInkSoft} strokeWidth={2} strokeLinecap="round" />
          </svg>
          {[
          { x: 80, y: 70, label: '1', color: wfAccent },
          { x: 180, y: 110, label: '2', color: wfInk },
          { x: 240, y: 50, label: '3', color: wfInk }].
          map((p, i) =>
          <div
            key={i}
            style={{
              position: 'absolute',
              left: p.x,
              top: p.y,
              width: 26,
              height: 26,
              borderRadius: 13,
              background: p.color,
              color: wfPaper,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: '"Caveat", cursive',
              fontSize: 16,
              fontWeight: 700,
              border: `2px solid ${wfPaper}`,
              boxShadow: '0 1px 2px rgba(0,0,0,0.2)'
            }}>
            
              {p.label}
            </div>
          )}
          <WFT size={10} color={wfInkSoft} style={{ position: 'absolute', bottom: 6, right: 8 }}>map placeholder</WFT>
        </div>
        {/* sheet of jobs */}
        <div style={{ flex: 1, padding: 12, display: 'flex', flexDirection: 'column', gap: 8, overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <div style={{ width: 36, height: 3, borderRadius: 2, background: wfInkFaint }} />
          </div>
          <WFH size={17}>today's stops</WFH>
          <WFRow
            title="1 · Greenwood Estate"
            meta="9:00 · hedge · 0.6 km from depot"
            accent={wfAccent}
            right={<WFT size={11}>›</WFT>}
            density={density} />
          
          <WFRow
            title="2 · Marshfield"
            meta="11:30 · plant out · 1.9 km"
            right={<WFT size={11}>›</WFT>}
            density={density} />
          
          <WFRow
            title="3 · St Anne's"
            meta="2:00 · mow · 4.5 km"
            right={<WFT size={11}>›</WFT>}
            density={density} />
          
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            pins for today's jobs · numbered in scheduled order
          </WFNote>
          <WFNote style={{ top: 360, right: -130 }}>
            bottom sheet pulls up · order is what the scheduler set
          </WFNote>
        </>
      }
    </>);

}

// B4 — Job detail screen (the workhorse)
function ScreenB4({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="job"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="⋯" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 8 }}>
        <div>
          <WFH size={24}>Greenwood Estate</WFH>
          <WFT size={12} color={wfInkSoft}>hedge trim · Tue 9:00–11:00</WFT>
        </div>

        <WFBox k="b4-hero" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={11} color={wfAccent} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>on site · 2h 16m</WFT>
              <WFT size={11} color={wfInkSoft}>arrived 9:02 · odo 48,224 km · Sam + Joe</WFT>
            </div>
            <WFBtn k="b4-leave" primary size="sm">leave →</WFBtn>
          </div>
        </WFBox>

        <div style={{ display: 'flex', gap: 6 }}>
          <WFBtn k="b4-act1" size="sm" style={{ flex: 1 }}>+ planted</WFBtn>
          <WFBtn k="b4-act2" size="sm" style={{ flex: 1 }}>+ material</WFBtn>
          <WFBtn k="b4-act3" size="sm" style={{ flex: 1 }}>+ photo</WFBtn>
        </div>

        <WFSection title="materials" action="all 3" />
        <WFRow title="Mulch · 4 bags" meta="brought · 3 used so far" density={density} />
        <WFRow title="Plant feed · 1 L" meta="brought · 0 used" density={density} />

        <WFSection title="event log" action="full" />
        <WFRow title="arrived" meta="9:02 · 48,224 km · Sam, Joe" accent={wfAccent} density={density} />
        <WFRow title="planted" meta="9:30 · Lavandula 'Hidcote' ×18" density={density} />
        <WFRow title="material used" meta="9:48 · mulch ×3" density={density} />
        <WFRow title="pete joined" meta="10:30" density={density} />
        <WFRow title="break" meta="11:00 · 12m" density={density} />

        <WFBtn k="b4-leave-cta" primary size="lg" style={{ marginTop: 6 }}>leave job · log distance →</WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 170, right: -130 }}>
            hero = arrival event · odo + crew · 'leave →' shortcut
          </WFNote>
          <WFNote style={{ top: 280, right: -130 }}>
            quick adds = the 3 JobEvent types ('planted' is plant ops)
          </WFNote>
          <WFNote style={{ top: 410, right: -130 }}>
            event log reads as a real shift narrative
          </WFNote>
          <WFNote style={{ bottom: 50, right: -130 }}>
            CTA explicit about distance capture — not just 'done'
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// C · Inventory
// ─────────────────────────────────────────────────────────────────────────────

// C1 — categorised list
function ScreenC1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="stock"
        left={<WFIcon label="☰" size={22} color={wfInkSoft} />}
        right={
        <div style={{ display: 'flex', gap: 6 }}>
            <WFIcon label="🔍" size={22} color={wfInkSoft} />
            <WFIcon label="+" size={22} color={wfInkSoft} />
          </div>
        }
        sub={
        <div style={{ display: 'flex', gap: 4, justifyContent: 'center', marginTop: 4 }}>
            <WFPill fill={wfInk} color={wfPaper}>all</WFPill>
            <WFPill>low</WFPill>
            <WFPill>plants</WFPill>
            <WFPill>cons.</WFPill>
            <WFPill>tools</WFPill>
          </div>
        } />
      
      <WFBody style={{ gap: 6 }}>
        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>↓ low stock</WFT>
        <WFRow
          title="Mulch · bag"
          meta="2 left · 4/wk avg"
          accent={wfAccent}
          right={<WFPill color={wfAccent} fill={wfAccentSoft}>order</WFPill>}
          density={density} />
        
        <WFRow
          title="Plant feed 5L"
          meta="1 bottle · 2/wk"
          accent={wfAccent}
          right={<WFPill color={wfAccent} fill={wfAccentSoft}>order</WFPill>}
          density={density} />
        

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 6 }}>plants</WFT>
        <WFRow title="Lavandula 'Hidcote' 9cm" meta="48 · ok" density={density} />
        <WFRow title="Buxus sempervirens 30cm" meta="22 · ok" density={density} />
        <WFRow title="Hebe pinguifolia 'Pagei'" meta="14 · low?" density={density} />

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 6 }}>consumables</WFT>
        <WFRow title="Compost 40L" meta="11 bags" density={density} />
        <WFRow title="Bone meal" meta="6 sacks" density={density} />
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 100, right: -130 }}>
            search icon top right — quick filter
          </WFNote>
          <WFNote style={{ top: 180, right: -130 }}>
            low-stock section pinned to top, accent-striped
          </WFNote>
        </>
      }
    </>);

}

// C2 — Latin text-search first. Horticulturalists know their Latin.
function ScreenC2({ pattern, persona, density, annotated }) {
  const Hit = ({ k, latin, common, meta, accent }) =>
  <WFBox k={k} pad={8} radius={8} stroke={accent || wfInkFaint}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>{latin}</WFT>
        {accent && <WFPill color={accent}>in stock</WFPill>}
      </div>
      <WFT size={11} color={wfInkSoft}>{common} · {meta}</WFT>
    </WFBox>;

  return (
    <>
      <WFTopBar
        title="find a plant"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 8 }}>
        <WFInput k="c2-search" value="lavandula a" placeholder="🔍 latin, cultivar, common name, sku…" />
        <WFT size={10} color={wfInkSoft} style={{ marginTop: -4 }}>
          one box — catalog (plants + amendments) + stock
        </WFT>

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 4 }}>
          ↓ matches · 14
        </WFT>
        <Hit
          k="c2-h1"
          latin="Lavandula angustifolia 'Hidcote'"
          common="English lavender"
          meta="9cm · 48 in stock"
          accent={wfGreen} />
        
        <Hit
          k="c2-h2"
          latin="Lavandula angustifolia 'Munstead'"
          common="English lavender"
          meta="9cm · 22 in stock"
          accent={wfGreen} />
        
        <Hit
          k="c2-h3"
          latin="Lavandula angustifolia 'Loddon Blue'"
          common="English lavender"
          meta="2L · 0 — Cramer 3d" />
        
        <Hit
          k="c2-h4"
          latin="Lavandula × allardii"
          common="Giant lavender"
          meta="3L · catalog only" />
        
        <Hit
          k="c2-h5"
          latin="Lavandula × intermedia 'Grosso'"
          common="lavandin"
          meta="9cm · 6 low"
          accent={wfAccent} />
        

        <WFSection title="recent searches" />
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          <WFPill>buxus sempervirens</WFPill>
          <WFPill>hebe ping.</WFPill>
          <WFPill>compost 40L</WFPill>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -130 }}>
            single box · latin · cultivar · common · sku · amendments (server-side)
          </WFNote>
          <WFNote style={{ top: 240, right: -130 }}>
            italic Latin name + common name underneath
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            recent searches as chips · no taxonomy tree
          </WFNote>
        </>
      }
    </>);

}

// C3 — Material detail (stock + lots + movements)
function ScreenC3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="material"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="⋯" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 10 }}>
        <div>
          <WFH size={22}>Mulch · bark, fine</WFH>
          <WFT size={11} color={wfInkSoft}>SKU MUL-001 · supplier: Cramer</WFT>
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <WFStat k="c3-s1" value="2" label="on hand" color={wfAccent} />
          <WFStat k="c3-s2" value="4/wk" label="usage" />
          <WFStat k="c3-s3" value="3d" label="runway" color={wfAccent} />
        </div>

        <div style={{ display: 'flex', gap: 6 }}>
          <WFBtn k="c3-a1" primary size="sm" style={{ flex: 1 }}>order</WFBtn>
          <WFBtn k="c3-a2" size="sm" style={{ flex: 1 }}>receive</WFBtn>
          <WFBtn k="c3-a3" size="sm" style={{ flex: 1 }}>adjust</WFBtn>
        </div>

        <WFSection title="lots" action="all" />
        <WFRow title="Lot A — 2 bags" meta="Cramer · rec'd 04 Mar" density={density} />

        <WFSection title="movements" action="all" />
        <WFRow title="−4 used" meta="Greenwood · Mon" density={density} />
        <WFRow title="−4 used" meta="Marshfield · Fri" density={density} />
        <WFRow title="+10 received" meta="PO #2018 · 24 Feb" density={density} />
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 200, right: -130 }}>
            3 KPIs > scrolling tables
          </WFNote>
          <WFNote style={{ top: 290, right: -130 }}>
            'order/receive/adjust' = the only 3 inv. verbs
          </WFNote>
        </>
      }
    </>);

}

// C4 — Quick stock count flow
function ScreenC4({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="stock count"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        sub={
        <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>
            item 7 of 24 · 17 to go
          </WFT>
        } />
      
      <WFBody style={{ gap: 14, justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'center', marginTop: 4 }}>
          <WFT size={11} color={wfInkSoft}>shelf B-3</WFT>
          <WFH size={28} style={{ textAlign: 'center', fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFH>
          <WFT size={11} color={wfInkSoft}>last count 48 · 7 days ago</WFT>

          <WFBox k="c4-count" pad={20} radius={14} thick style={{ width: 200, textAlign: 'center' }}>
            <WFT size={11} color={wfInkSoft}>count</WFT>
            <WFH size={56} style={{ lineHeight: 1 }}>46</WFH>
          </WFBox>

          <div style={{ display: 'flex', gap: 8 }}>
            <WFBtn k="c4-minus" size="lg" style={{ width: 64 }}>−</WFBtn>
            <WFBtn k="c4-plus" size="lg" style={{ width: 64 }}>+</WFBtn>
          </div>

          <div style={{ display: 'flex', gap: 6 }}>
            <WFPill>−10</WFPill>
            <WFPill>−5</WFPill>
            <WFPill>0</WFPill>
            <WFPill>+5</WFPill>
            <WFPill>+10</WFPill>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <WFBtn k="c4-skip" size="lg" style={{ flex: 1 }}>skip</WFBtn>
          <WFBtn k="c4-next" primary size="lg" style={{ flex: 2 }}>save & next →</WFBtn>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            single-item flow w/ progress crumb
          </WFNote>
          <WFNote style={{ top: 350, right: -130 }}>
            big +/- + quick deltas. no keypad needed
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// D · Engagements & material editing (David: "purchases are tied to jobs")
//   Engagement = meta-job (contract w/ a customer for a garden, has scope,
//   signature, prices, planned materials, child jobs). Manual purchasing
//   doesn't exist — POs emerge from editing job/engagement material lists.
// ─────────────────────────────────────────────────────────────────────────────

// D5 — New engagement: the FAST first-touch capture, done standing in the
// garden. Scope note + a few photos + a loose budget + a due date. No
// materials, no signature, no child jobs — that's all the "real work" that
// happens later on the detail screen (D1). Budget is deliberately loose:
// "reasonable" / "open" / a rough figure — the customer gets a quote with a
// drawing later ("does £4k for this bed sound good?").
function ScreenD5({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="new engagement"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        right={<WFT size={13} color={wfInkFaint}>save</WFT>}
        sub={<WFT size={11} color={wfInkSoft}>Mrs Penrose · pick a garden</WFT>} />

      <WFBody style={{ gap: 9 }}>
        {/* garden — quick pick, pre-selected if she has just one */}
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', alignItems: 'center' }}>
          <WFPill fill={wfAccentSoft} color={wfAccent}>★ Rosehill</WFPill>
          <WFPill>Coach House</WFPill>
          <WFPill color={wfInkSoft}>+ garden</WFPill>
        </div>

        {/* THE NOTE — the heart of the screen */}
        <WFSection title="the note — what are we doing?" style={{ marginTop: 2 }} />
        <WFBox k="d5-scope" pad={10} radius={10} stroke={wfInkSoft} style={{ background: wfSurface, minHeight: 92 }}>
          <WFT size={13} style={{ lineHeight: 1.35 }}>
            Strip the front bed, lavender hedge along the path + a few boxwood
            balls for structure, mulch it all.
          </WFT>
          <WFT size={12} color={wfInkFaint} style={{ marginTop: 6 }}>
            she wants it low-fuss, lots of purple in summer…
          </WFT>
        </WFBox>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: -2 }}>
          <WFPill color={wfInkSoft}>🎙 dictate</WFPill>
          <WFT size={11} color={wfInkFaint}>rough is fine — tidy it up later</WFT>
        </div>

        {/* a few pictures — first-class capture */}
        <WFSection title="a few pictures" action="paint a plan" style={{ marginTop: 6 }} />
        <div style={{ display: 'flex', gap: 6 }}>
          {/* big primary camera tile */}
          <WFBox k="d5-cam" pad={0} radius={10} thick stroke={wfAccent} fill={wfAccentSoft}
            style={{ width: 84, height: 92, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, flex: '0 0 auto' }}>
            <WFIcon label="📷" size={28} color={wfAccent} style={{ border: 'none' }} />
            <WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>snap</WFT>
          </WFBox>
          {/* just-captured thumbnails */}
          {[1, 2].map((n) => (
            <WFBox key={n} k={`d5-ph${n}`} pad={0} radius={10} stroke={wfInkFaint}
              style={{ width: 66, height: 92, position: 'relative', overflow: 'hidden', background: wfSurface, flex: '0 0 auto' }}>
              <div style={{ position: 'absolute', inset: 0, background: `repeating-linear-gradient(${35 * n}deg, ${wfInkFaint}22 0 5px, transparent 5px 12px)` }} />
              <div style={{ position: 'absolute', left: 4, top: 4 }}><WFPill>📸</WFPill></div>
              <div style={{ position: 'absolute', right: 3, top: 3 }}>
                <WFIcon label="✕" size={15} color={wfInkSoft} style={{ background: wfPaper, borderRadius: 8 }} />
              </div>
            </WFBox>
          ))}
          {/* library */}
          <WFBox k="d5-lib" pad={0} radius={10} dashed stroke={wfInkFaint}
            style={{ width: 50, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
            <WFT size={11} color={wfInkSoft} style={{ textAlign: 'center', lineHeight: 1.2 }}>+ from<br />library</WFT>
          </WFBox>
        </div>

        {/* budget — two boxes; type a figure or leave it 0 (saves as n/a) */}
        <WFSection title="budget — a figure, or leave it 0" style={{ marginTop: 6 }} />
        <div style={{ display: 'flex', gap: 7 }}>
          <WFBox k="d5-bud-install" pad={8} radius={9} stroke={wfInkSoft} style={{ flex: 1, background: wfSurface }}>
            <WFT size={10} color={wfInkSoft} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>install</WFT>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
              <WFH size={20} style={{ lineHeight: 1 }}>£0</WFH>
              <WFPill color={wfInkSoft}>→ n/a</WFPill>
            </div>
          </WFBox>
          <WFBox k="d5-bud-maint" pad={8} radius={9} stroke={wfInkSoft} style={{ flex: 1, background: wfSurface }}>
            <WFT size={10} color={wfInkSoft} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>maint / yr</WFT>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
              <WFH size={20} style={{ lineHeight: 1 }}>£0</WFH>
              <WFPill color={wfInkSoft}>→ n/a</WFPill>
            </div>
          </WFBox>
        </div>
        <WFBox k="d5-budget-note" pad={9} radius={9} stroke={wfBlue} style={{ background: wfBlueSoft }}>
          <WFT size={11} color={wfInk} style={{ lineHeight: 1.35 }}>
            ⓘ 0 saves as <span style={{ fontWeight: 600 }}>n/a</span> — “reasonable” or “open”, spelled out in the note. we quote off the drawing later (“does £4k sound good?”). staged / monthly / weekly terms are quote-only — for the formal clients (by far the least lucrative).
          </WFT>
        </WFBox>

        {/* due dates — light */}
        <WFSection title="when" style={{ marginTop: 6 }} />
        <div style={{ display: 'flex', gap: 7 }}>
          <WFBox k="d5-start" pad={8} radius={9} stroke={wfInkSoft} style={{ flex: 1, background: wfSurface }}>
            <WFT size={10} color={wfInkSoft} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>start</WFT>
            <WFT size={14} style={{ marginTop: 2, fontWeight: 600 }}>asap ▾</WFT>
          </WFBox>
          <WFBox k="d5-due" pad={8} radius={9} stroke={wfInkSoft} style={{ flex: 1, background: wfSurface }}>
            <WFT size={10} color={wfInkSoft} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>done by</WFT>
            <WFT size={14} style={{ marginTop: 2, fontWeight: 600 }}>end of April ▾</WFT>
          </WFBox>
        </div>

        {/* sticky save — glows once garden + a note exist */}
        <div style={{
          position: 'absolute',
          left: 14, right: 14, bottom: 16,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <WFBtn k="d5-save" primary size="lg" style={{ flex: 1 }}>save · quote later</WFBtn>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 96, right: -128 }}>
            scope note is the heart — everything else is optional
          </WFNote>
          <WFNote style={{ top: 300, right: -128 }}>
            photos first-class · snap the bed now, paint the real plan later
          </WFNote>
          <WFNote style={{ top: 470, right: -128 }}>
            install + maint/yr · type a figure or leave 0 → saves n/a · staged terms are quote-only
          </WFNote>
          <WFNote style={{ bottom: 80, right: -128 }}>
            save fast · materials, jobs + signature all happen on detail (D1)
          </WFNote>
        </>
      }
    </>);

}

// D1 — Engagement detail (the meta-job)
function ScreenD1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="engagement"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="⋯" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 10 }}>
        <div>
          <WFT size={11} color={wfInkSoft}>Mrs Penrose · Rosehill garden</WFT>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <WFH size={22}>Front bed redesign</WFH>
            <span
              title="signed M. Penrose · 04 Mar"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: 18,
                height: 18,
                borderRadius: 9,
                border: `1.5px solid ${wfGreen}`,
                color: wfGreen,
                fontFamily: '"Caveat", cursive',
                fontSize: 14,
                fontWeight: 700,
                lineHeight: 1,
              }}
            >
              ✓
            </span>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 4, alignItems: 'center' }}>
            <WFPill color={wfAccent} fill={wfAccentSoft}>in&nbsp;progress</WFPill>
            <WFT size={11} color={wfInkSoft}>Mar–Oct 2026 · signed 04 Mar by M.P.</WFT>
          </div>
        </div>

        {/* garden imagery — first-class gallery */}
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
            <WFH size={16}>garden beds · as drawn | described</WFH>
            <WFT size={11} color={wfAccent}>view all 4</WFT>
          </div>
          <div style={{ display: 'flex', gap: 6, overflow: 'hidden' }}>
            {/* primary painting thumbnail */}
            <WFBox k="d1-img-paint" pad={0} radius={8} stroke={wfInkFaint} style={{ width: 96, height: 96, position: 'relative', overflow: 'hidden', background: wfSurface, flex: '0 0 auto' }}>
              <div style={{ position: 'absolute', inset: 0, background: `repeating-linear-gradient(135deg, ${wfInkFaint}33 0 4px, transparent 4px 10px)` }} />
              <div style={{ position: 'absolute', left: 4, top: 4 }}>
                <WFPill>🎨 painting</WFPill>
              </div>
              <div style={{ position: 'absolute', right: 4, bottom: 4 }}>
                <WFT size={10} color={wfInkSoft}>tap</WFT>
              </div>
            </WFBox>
            {/* photo thumbnails */}
            {[1, 2, 3].map((n) => (
              <WFBox key={n} k={`d1-img-photo${n}`} pad={0} radius={8} stroke={wfInkFaint} style={{ width: 72, height: 96, position: 'relative', overflow: 'hidden', background: wfSurface, flex: '0 0 auto' }}>
                <div style={{ position: 'absolute', inset: 0, background: `repeating-linear-gradient(${30 * n}deg, ${wfInkFaint}22 0 5px, transparent 5px 12px)` }} />
                <div style={{ position: 'absolute', left: 4, top: 4 }}>
                  <WFPill>📸</WFPill>
                </div>
              </WFBox>
            ))}
            {/* add */}
            <WFBox k="d1-img-add" pad={0} radius={8} stroke={wfInkFaint} dashed style={{ width: 56, height: 96, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
              <WFT size={11} color={wfInkSoft} style={{ textAlign: 'center', lineHeight: 1.2 }}>+ paint /<br />photo</WFT>
            </WFBox>
          </div>
        </div>

        <WFBox k="d1-scope" pad={10} radius={10}>
          <WFT size={11} color={wfInkSoft} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>scope</WFT>
          <WFT size={13} style={{ marginTop: 4 }}>
            Strip front bed, install lavender hedge + boxwood structure, mulch.
            Annual maintenance: 2 visits spring, 1 autumn.
          </WFT>
        </WFBox>

        <div style={{ display: 'flex', gap: 8 }}>
          <WFStat k="d1-f1" value="£4,820" label="install ✎" />
          <WFStat k="d1-f2" value="£1,200" label="maint./yr ✎" />
          <WFStat k="d1-f3" value="42" label="plants" />
        </div>

        <WFSection title="planned materials" action="edit list" />
        <WFRow
          title="42 line items · est £1,840"
          meta="Lavandula ×60 · Buxus ×24 · compost ×16 · …"
          density={density}
          right={<WFT size={11}>›</WFT>} />
        

        <WFSection title="jobs" action="+ schedule" />
        <WFRow title="Strip + level bed" meta="Mon 11 Mar · done · 6h" accent={wfGreen} density={density} />
        <WFRow title="Plant hedge + box" meta="Wed 13 Mar · scheduled · 8h" accent={wfAccent} density={density} />
        <WFRow title="Mulch + finish" meta="Fri 15 Mar · unscheduled" density={density} right={<WFPill color={wfAccent}>place</WFPill>} />
        <WFRow title="Maint. visit 1" meta="Apr — TBD" density={density} />
        <WFRow title="Maint. visit 2" meta="Jul — TBD" density={density} />

        <WFBox k="d1-auto" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>
            ↻ new jobs auto-pull materials from the plan by install-by date.
          </WFT>
        </WFBox>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 100, right: -130 }}>
            small ✓ next to title = signed · no separate footer block
          </WFNote>
          <WFNote style={{ top: 220, right: -130 }}>
            first-class gallery · '+ paint/photo' adds, tap thumb to view
          </WFNote>
          <WFNote style={{ top: 420, right: -130 }}>
            prices show ✎ — tap to set/edit · '—' when unset
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            reached via more → engagements (not a bottom tab)
          </WFNote>
        </>
      }
    </>);

}

// D2 — Edit engagement materials (catalog picker scoped to engagement)
function ScreenD2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="plan materials"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>done</WFT>}
        sub={<WFT size={11} color={wfInkSoft}>Penrose · Front bed redesign</WFT>} />
      
      <WFBody style={{ gap: 8 }}>
        {/* source: catalog vs already-on-hand inventory (link to D4) */}
        <div style={{ display: 'flex', gap: 4 }}>
          <WFPill fill={wfInk} color={wfPaper}>catalog</WFPill>
          <WFPill>browse inventory →</WFPill>
        </div>

        <WFInput k="d2-search" placeholder="🔍 latin / cultivar / common name…" value="lavandul" />

        <div style={{ display: 'flex', gap: 4 }}>
          <WFPill fill={wfInk} color={wfPaper}>9cm</WFPill>
          <WFPill>1L</WFPill>
          <WFPill>3L</WFPill>
          <WFPill>5L</WFPill>
        </div>

        <WFCard k="d2-1" accent={wfGreen}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£15/f ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Cramer · 6 / flat · 48 in stock</WFT>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6, gap: 4 }}>
            <div style={{ display: 'flex', gap: 3, alignItems: 'center' }}>
              <WFBtn k="d2-1mf" size="sm" style={{ minWidth: 32, padding: '0 6px' }}>−f</WFBtn>
              <WFBtn k="d2-1m1" size="sm" style={{ minWidth: 28, padding: '0 6px' }}>−1</WFBtn>
              <div style={{ minWidth: 52, textAlign: 'center' }}>
                <WFH size={18} style={{ lineHeight: 1 }}>10f</WFH>
                <WFT size={10} color={wfInkSoft}>60 plants</WFT>
              </div>
              <WFBtn k="d2-1p1" size="sm" style={{ minWidth: 28, padding: '0 6px' }}>+1</WFBtn>
              <WFBtn k="d2-1pf" size="sm" style={{ minWidth: 32, padding: '0 6px' }}>+f</WFBtn>
            </div>
          </div>
          <div style={{ marginTop: 4, display: 'flex', justifyContent: 'flex-end' }}>
            <WFPill>need Wed 13</WFPill>
          </div>
        </WFCard>

        <WFCard k="d2-2">
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Munstead' 9cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£15/f ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Cramer · 6 / flat · 22 in stock</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4 }}>
            <WFBtn k="d2-2addf" size="sm">+ flat</WFBtn>
            <WFBtn k="d2-2add1" size="sm">+ 1</WFBtn>
          </div>
        </WFCard>

        <WFCard k="d2-3">
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula × intermedia 'Grosso' 9cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted', color: wfInkSoft }}>— ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Cramer · 6 / flat · catalog only · price unset</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4 }}>
            <WFBtn k="d2-3addf" size="sm">+ flat</WFBtn>
            <WFBtn k="d2-3add1" size="sm">+ 1</WFBtn>
          </div>
        </WFCard>

        <div style={{
          position: 'absolute',
          left: 14, right: 14, bottom: 72,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '8px 12px',
          background: wfInk, color: wfPaper, borderRadius: 10
        }}>
          <WFT size={12} color={wfPaper}>plan · 42 items · est £1,840</WFT>
          <WFT size={12} color={wfPaper} style={{ fontWeight: 600 }}>back to engagement →</WFT>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            two sources: catalog (here) · inventory (D4, in-stock items)
          </WFNote>
          <WFNote style={{ top: 280, right: -130 }}>
            stepper: −f / −1 / count / +1 / +f · 'f' = flat
          </WFNote>
          <WFNote style={{ top: 440, right: -130 }}>
            price w/ ✎ · tap to set/edit · '—' when not on file
          </WFNote>
          <WFNote style={{ bottom: 110, right: -130 }}>
            sticky bar: plan total · returns to engagement
          </WFNote>
        </>
      }
    </>);

}

// D3 — Edit job materials (catalog picker scoped to a single job — this is
// where day-to-day "purchases" happen)
function ScreenD3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="job materials"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>done</WFT>}
        sub={<WFT size={11} color={wfInkSoft}>Plant hedge + box · Wed 13 Mar</WFT>} />
      
      <WFBody style={{ gap: 8 }}>
        <WFBox k="d3-engscope" pad={8} radius={8} stroke={wfInkFaint} style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>↑ from engagement plan</WFT>
          <WFT size={11} color={wfInkSoft}>Penrose · Front bed redesign · 42 planned</WFT>
        </WFBox>

        <WFInput k="d3-search" placeholder="🔍 latin/cultivar/common · or pick from engagement plan…" />

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1, marginTop: 2 }}>↓ on this job</WFT>

        <WFCard k="d3-1" accent={wfGreen}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£15/f ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>from plan · 6 / flat · 48 in stock ✓</WFT>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6, gap: 4 }}>
            <div style={{ display: 'flex', gap: 3, alignItems: 'center' }}>
              <WFBtn k="d3-1mf" size="sm" style={{ minWidth: 32, padding: '0 6px' }}>−f</WFBtn>
              <WFBtn k="d3-1m1" size="sm" style={{ minWidth: 28, padding: '0 6px' }}>−1</WFBtn>
              <div style={{ minWidth: 50, textAlign: 'center' }}>
                <WFH size={18} style={{ lineHeight: 1 }}>4f</WFH>
                <WFT size={10} color={wfInkSoft}>24</WFT>
              </div>
              <WFBtn k="d3-1p1" size="sm" style={{ minWidth: 28, padding: '0 6px' }}>+1</WFBtn>
              <WFBtn k="d3-1pf" size="sm" style={{ minWidth: 32, padding: '0 6px' }}>+f</WFBtn>
            </div>
          </div>
          <div style={{ marginTop: 4, textAlign: 'right' }}>
            <WFT size={11} color={wfInkSoft}>= £60</WFT>
          </div>
        </WFCard>

        <WFCard k="d3-2" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Buxus sempervirens 30cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£4.20 ea ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>from plan · 30cm pots (no flats) · short 2</WFT>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 }}>
            <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <WFBtn k="d3-2m" size="sm" style={{ minWidth: 30 }}>−1</WFBtn>
              <WFH size={20} style={{ minWidth: 30, textAlign: 'center' }}>24</WFH>
              <WFBtn k="d3-2p" size="sm" style={{ minWidth: 30 }}>+1</WFBtn>
            </div>
            <WFPill color={wfAccent}>will PO 2</WFPill>
          </div>
        </WFCard>

        <WFCard k="d3-3">
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>Compost 40L</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£6 / bag ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>amendment · not in plan · adhoc</WFT>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 }}>
            <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <WFBtn k="d3-3m" size="sm" style={{ minWidth: 30 }}>−1</WFBtn>
              <WFH size={20} style={{ minWidth: 30, textAlign: 'center' }}>4</WFH>
              <WFBtn k="d3-3p" size="sm" style={{ minWidth: 30 }}>+1</WFBtn>
            </div>
            <WFT size={11} color={wfInkSoft}>= £24</WFT>
          </div>
        </WFCard>

        <div style={{
          position: 'absolute',
          left: 14, right: 14, bottom: 72,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '8px 12px',
          background: wfInk, color: wfPaper, borderRadius: 10
        }}>
          <WFT size={12} color={wfPaper}>3 items · £144 · 2 will PO</WFT>
          <WFT size={12} color={wfPaper} style={{ fontWeight: 600 }}>back to job →</WFT>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            picker linked to parent engagement · re-uses plan items
          </WFNote>
          <WFNote style={{ top: 270, right: -130 }}>
            ≤9cm: −f·−1·count·+1·+f · 30cm+/amendments: −/+1 only
          </WFNote>
          <WFNote style={{ bottom: 110, right: -130 }}>
            sticky bar: job total · returns to job (not to a PO)
          </WFNote>
        </>
      }
    </>);

}

// D4 — Browse inventory · add to garden (in-stock items, NOT from catalog)
function ScreenD4({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="inventory"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>done</WFT>}
        sub={<WFT size={11} color={wfInkSoft}>add to · Penrose / Front bed redesign</WFT>}
      />
      <WFBody style={{ gap: 8 }}>
        <div style={{ display: 'flex', gap: 4 }}>
          <WFPill>catalog</WFPill>
          <WFPill fill={wfInk} color={wfPaper}>inventory</WFPill>
        </div>

        <WFInput k="d4-search" placeholder="🔍 latin / common · in-stock only…" />

        <div style={{ display: 'flex', gap: 4 }}>
          <WFPill fill={wfInk} color={wfPaper}>all</WFPill>
          <WFPill>plants</WFPill>
          <WFPill>amendments</WFPill>
          <WFPill>tools</WFPill>
        </div>

        <WFT size={10} color={wfInkFaint} style={{ textTransform: 'uppercase', letterSpacing: 1 }}>↓ on hand · 24</WFT>

        <WFCard k="d4-1" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£15/f ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>48 on hand · 8 flats · last received 04 Mar</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
            <WFBtn k="d4-1f" size="sm">+ flat to garden</WFBtn>
            <WFBtn k="d4-11" size="sm">+ 1</WFBtn>
          </div>
        </WFCard>

        <WFCard k="d4-2" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Buxus sempervirens 30cm</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£4.20 ea ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>22 on hand · pots (no flats)</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
            <WFBtn k="d4-2add" size="sm">+ 1 to garden</WFBtn>
          </div>
        </WFCard>

        <WFCard k="d4-3" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Hebe pinguifolia 'Pagei'</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£14/f ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>14 on hand · 2 partial flats · stored on-site at Marshfield</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
            <WFBtn k="d4-3f" size="sm">+ flat to garden</WFBtn>
            <WFBtn k="d4-31" size="sm">+ 1</WFBtn>
          </div>
        </WFCard>

        <WFCard k="d4-4" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>Compost 40L</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted' }}>£6 / bag ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>11 bags on hand · amendment</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
            <WFBtn k="d4-4add" size="sm">+ 1 to garden</WFBtn>
          </div>
        </WFCard>

        <WFCard k="d4-5" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>Bone meal</WFT>
            <WFT size={11} style={{ textDecoration: 'underline dotted', color: wfInkSoft }}>— ✎</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>6 sacks on hand · price unset</WFT>
          <div style={{ marginTop: 6, display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
            <WFBtn k="d4-5add" size="sm">+ 1 to garden</WFBtn>
          </div>
        </WFCard>

        <div style={{
          position: 'absolute',
          left: 14, right: 14, bottom: 72,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '8px 12px',
          background: wfInk, color: wfPaper, borderRadius: 10
        }}>
          <WFT size={12} color={wfPaper}>added · 12 plants · 2 amendments</WFT>
          <WFT size={12} color={wfPaper} style={{ fontWeight: 600 }}>back to engagement →</WFT>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            two sources: catalog (D2) · inventory (here, in-stock)
          </WFNote>
          <WFNote style={{ top: 250, right: -130 }}>
            search-inventory · category chips
          </WFNote>
          <WFNote style={{ top: 380, right: -130 }}>
            '+ to garden' = add to the engagement's material list
          </WFNote>
          <WFNote style={{ bottom: 110, right: -130 }}>
            sticky bar tracks what was added · returns to engagement
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// E · Schedule (first-class planner flow)
// ─────────────────────────────────────────────────────────────────────────────

// E1 — Week board: columns = days, rows = crews. Drag jobs around.
function ScreenE1({ pattern, persona, density, annotated }) {
  const days = ['M', 'T', 'W', 'T', 'F'];
  const Block = ({ name, color, h = 40, faded = false }) =>
  <div
    style={{
      background: faded ? 'transparent' : color || wfInk,
      border: `1.5px ${faded ? 'dashed' : 'solid'} ${color || wfInk}`,
      color: faded ? wfInkSoft : wfPaper,
      padding: '3px 5px',
      borderRadius: 4,
      fontFamily: '"Patrick Hand", cursive',
      fontSize: 10,
      lineHeight: 1.1,
      marginBottom: 3,
      height: h,
      overflow: 'hidden'
    }}>
    
      {name}
    </div>;

  const Day = ({ d, today, children }) =>
  <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ textAlign: 'center', marginBottom: 4 }}>
        <WFT size={10} color={wfInkSoft}>{d}</WFT>
        {today && <div style={{ height: 2, background: wfAccent, marginTop: 1 }} />}
      </div>
      {children}
    </div>;

  return (
    <>
      <WFTopBar
        title="schedule"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={
        <div style={{ display: 'flex', gap: 4 }}>
            <WFPill fill={wfInk} color={wfPaper}>week</WFPill>
            <WFPill>day</WFPill>
          </div>
        }
        sub={<WFT size={11} color={wfInkSoft}>w/c Mon 11 Mar · 12 jobs · 2 unscheduled</WFT>} />
      
      <WFBody style={{ gap: 8 }}>
        {/* Crew A */}
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <WFT size={12} style={{ fontWeight: 600 }}>● Sam (crew A)</WFT>
            <WFT size={10} color={wfInkSoft}>28h</WFT>
          </div>
          <div style={{ display: 'flex', gap: 3 }}>
            <Day d="M"><Block name="Marshfield" color={wfBlue} h={28} /></Day>
            <Day d="T" today><Block name="Greenwood" color={wfAccent} h={40} /></Day>
            <Day d="W"><Block name="Rosehill survey" color={wfBlue} h={28} /></Day>
            <Day d="T"><Block name="St Anne's" color={wfBlue} h={50} /></Day>
            <Day d="F"><Block name="—" faded h={28} /></Day>
          </div>
        </div>
        {/* Crew B */}
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
            <WFT size={12} style={{ fontWeight: 600 }}>● Joe (crew B)</WFT>
            <WFT size={10} color={wfInkSoft}>22h</WFT>
          </div>
          <div style={{ display: 'flex', gap: 3 }}>
            <Day d="M"><Block name="—" faded h={28} /></Day>
            <Day d="T" today><Block name="Marshfield plant" color={wfBlue} h={28} /></Day>
            <Day d="W"><Block name="Greenwood mulch" color={wfBlue} h={40} /></Day>
            <Day d="T"><Block name="—" faded h={28} /></Day>
            <Day d="F"><Block name="Hortus depot" color={wfGreen} h={28} /></Day>
          </div>
        </div>

        <WFSection title="unscheduled" action="+ new" />
        <WFRow
          title="Rosehill — bed prep"
          meta="4h · needs 24× Lavandula 'Hidcote'"
          right={<WFPill color={wfAccent}>place</WFPill>}
          density={density} />
        
        <WFRow
          title="Greenwood — autumn return"
          meta="2h · no materials"
          right={<WFPill color={wfAccent}>place</WFPill>}
          density={density} />
        

        <WFBox k="e1-tip" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>
            ↻ schedule changes auto-recompute PO demand
          </WFT>
        </WFBox>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -130 }}>
            crew × day grid · tap a placed job to send it back to unscheduled
          </WFNote>
          <WFNote style={{ top: 360, right: -130 }}>
            unscheduled jobs queue — tap 'place' to slot
          </WFNote>
          <WFNote style={{ bottom: 70, right: -130 }}>
            every schedule change feeds the PO engine
          </WFNote>
        </>
      }
    </>);

}

// E2 — Schedule a single job: pick slot + see materials required.
function ScreenE2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="schedule job"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>save</WFT>} />
      
      <WFBody style={{ gap: 10 }}>
        <div>
          <WFH size={22}>Rosehill — bed prep</WFH>
          <WFT size={11} color={wfInkSoft}>Mrs Penrose · NEW customer · est. 4h</WFT>
        </div>

        <WFSection title="when" />
        <div style={{ display: 'flex', gap: 4 }}>
          {['Mon 11', 'Tue 12', 'Wed 13', 'Thu 14', 'Fri 15'].map((d, i) =>
          <WFBox
            key={i}
            k={`e2-d${i}`}
            pad={6}
            radius={8}
            fill={i === 2 ? wfInk : 'transparent'}
            thick={i === 2}
            style={{ flex: 1, textAlign: 'center' }}>
            
              <WFT size={10} color={i === 2 ? wfPaper : wfInkSoft}>{d.split(' ')[0]}</WFT>
              <WFH size={16} color={i === 2 ? wfPaper : wfInk}>{d.split(' ')[1]}</WFH>
            </WFBox>
          )}
        </div>

        <div style={{ display: 'flex', gap: 6 }}>
          <WFInput k="e2-start" value="9:00" placeholder="start" style={{ flex: 1 }} />
          <WFInput k="e2-end" value="1:00" placeholder="end" style={{ flex: 1 }} />
        </div>

        <WFSection title="crew" />
        <div style={{ display: 'flex', gap: 6 }}>
          <WFPill fill={wfInk} color={wfPaper}>● Sam</WFPill>
          <WFPill>Joe</WFPill>
          <WFPill>+ add</WFPill>
        </div>

        <WFSection title="materials required" action="edit list" />
        <WFRow
          title="Lavandula 'Hidcote' 9cm"
          meta="24 needed · 48 in stock ✓"
          density={density}
          right={<WFT size={11} color={wfGreen}>ok</WFT>} />
        
        <WFRow
          title="Buxus sempervirens 30cm"
          meta="12 needed · 22 in stock ✓"
          density={density}
          right={<WFT size={11} color={wfGreen}>ok</WFT>} />
        
        <WFRow
          title="Compost 40L"
          meta="6 bags · 4 in stock · short 2"
          density={density}
          right={<WFPill color={wfAccent}>PO</WFPill>} />
        
        <WFRow
          title="Bone meal"
          meta="2 sacks · 6 in stock ✓"
          density={density}
          right={<WFT size={11} color={wfGreen}>ok</WFT>} />
        

        <WFBox k="e2-warn" pad={8} radius={8} stroke={wfAccent} fill={wfAccentSoft}>
          <WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>1 shortfall → will draft a PO</WFT>
          <WFT size={11} color={wfInkSoft}>Compost 40L · 2 bags · Cramer · 2-day lead</WFT>
        </WFBox>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 200, right: -130 }}>
            day strip · big tap targets, no calendar widget
          </WFNote>
          <WFNote style={{ top: 380, right: -130 }}>
            materials surface stock-vs-need at schedule time
          </WFNote>
          <WFNote style={{ bottom: 70, right: -130 }}>
            shortfall warning + auto-draft PO before save
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// F · Stock flow (the OpenSauce Dirt chain)
//   schedule → required supplies → PO generation → pickup at nursery
// ─────────────────────────────────────────────────────────────────────────────

// F1 — Required supplies: auto-aggregated demand from the schedule.
// F1 — Supply run: build the next nursery trip. Volume-driven (truck capacity),
// not date-windowed. Amendments auto-calculate volume; plants need a human to
// decide what fits.
function ScreenF1({ pattern, persona, density, annotated }) {
  // Truck capacity (selectable — own van vs rentals). Amendments are the only
  // thing we measure against the truck; plants are a human call.
  const truckTotal = 6.0;
  const amendmentsVol = 2.4;
  const amendPct = amendmentsVol / truckTotal * 100;
  return (
    <>
      <WFTopBar
        title="supply run"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="⋯" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>next pickup · Wed 13 Mar</WFT>} />
      
      <WFBody style={{ gap: 10 }}>
        {/* Truck size — selectable (own van, rentals come in std sizes) */}
        <WFBox k="f1-truck" pad={10} radius={10}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <WFT size={11} color={wfInkSoft}>truck</WFT>
            <WFT size={11} color={wfAccent}>change ›</WFT>
          </div>
          <div style={{ display: 'flex', gap: 4, marginTop: 6, flexWrap: 'wrap' }}>
            <WFPill>own · 4 m³</WFPill>
            <WFPill fill={wfInk} color={wfPaper}>rented · 6 m³</WFPill>
            <WFPill>rented · 10 m³</WFPill>
            <WFPill>rented · 14 m³</WFPill>
          </div>
        </WFBox>

        {/* Amendment volume gauge — the only thing on the gauge per David */}
        <WFBox k="f1-gauge" pad={10} radius={10}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <WFT size={11} color={wfInkSoft}>amendments volume</WFT>
            <div style={{ display: 'flex', gap: 4, alignItems: 'baseline' }}>
              <WFH size={22} color={wfBlue}>2.4</WFH>
              <WFT size={11} color={wfInkSoft}>/ 6.0 m³ · 40%</WFT>
            </div>
          </div>
          <div style={{
            height: 14, marginTop: 6, borderRadius: 7,
            background: wfSurface, border: `1px solid ${wfInkFaint}`,
            position: 'relative', overflow: 'hidden'
          }}>
            <div style={{
              position: 'absolute', left: 0, top: 0, bottom: 0,
              width: `${amendPct}%`, background: wfBlue
            }} />
          </div>
          <WFT size={10} color={wfInkSoft} style={{ marginTop: 4 }}>
            plants don't count against this — they're a human call below
          </WFT>
        </WFBox>

        <WFSection title="amendments · auto" action="recalc" />
        <WFRow
          title="Topsoil"
          meta="1.0 m³ · 2 jobs (Penrose, Marshfield)"
          accent={wfBlue}
          density={density} />
        
        <WFRow
          title="Compost 40L · 30 bags"
          meta="1.2 m³ · 3 jobs"
          accent={wfBlue}
          density={density} />
        
        <WFRow
          title="Bone meal · 8 sacks"
          meta="0.2 m³ · 2 jobs"
          accent={wfBlue}
          density={density} />
        

        <WFSection title="on the run · plants" action="clear" />
        <WFCard k="f1-p1" accent={wfAccent} pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
            <WFT size={11}>10 flats</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Penrose (front bed) · 6 / flat</WFT>
        </WFCard>
        <WFCard k="f1-p2" accent={wfAccent} pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Buxus sempervirens 30cm</WFT>
            <WFT size={11}>24 plants</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Penrose · pots, not flats</WFT>
        </WFCard>

        <WFSection title="from plans · pick what fits" />
        <WFCard k="f1-c1" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Hebe pinguifolia 'Pagei'</WFT>
            <WFT size={11}>2 flats</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Marshfield maint. · Mar 18</WFT>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 4 }}>
            <WFBtn k="f1-c1add" size="sm">+ add to run</WFBtn>
          </div>
        </WFCard>
        <WFCard k="f1-c2" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Acer palmatum 'Bloodgood' 60cm</WFT>
            <WFT size={11}>3 specimens</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>large · will need a bigger truck · Rosehill · Mar 22</WFT>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 4 }}>
            <WFBtn k="f1-c2add" size="sm">+ add to run</WFBtn>
          </div>
        </WFCard>
        <WFCard k="f1-c3" pad={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Munstead' 9cm</WFT>
            <WFT size={11}>4 flats</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>Greenwood return · Apr 4</WFT>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 4 }}>
            <WFBtn k="f1-c3add" size="sm">+ add to run</WFBtn>
          </div>
        </WFCard>

        <WFBtn k="f1-gen" primary size="lg" style={{ marginTop: 8 }}>
          generate POs · send to printer →
        </WFBtn>
        <WFT size={10} color={wfInkSoft} style={{ textAlign: 'center', marginTop: -2 }}>
          drafts one PO per supplier · prints via the PurchaseOrderPrint sheet
        </WFT>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -130 }}>
            truck size is picked (rentals come in std sizes)
          </WFNote>
          <WFNote style={{ top: 240, right: -130 }}>
            gauge = amendments only · plants are a human call
          </WFNote>
          <WFNote style={{ top: 570, right: -130 }}>
            candidates from any open plan · '+ add to run' per item
          </WFNote>
          <WFNote style={{ bottom: 90, right: -130 }}>
            CTA hits PurchaseOrderPrint · one PO per supplier
          </WFNote>
        </>
      }
    </>);

}

// F2 — Generated POs: review per-supplier drafts before sending.
function ScreenF2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="2 PO drafts"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>auto-generated from schedule · review & send</WFT>} />
      
      <WFBody style={{ gap: 10 }}>
        <WFCard k="f2-1" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <WFT size={14} style={{ fontWeight: 600 }}>Cramer Wholesale</WFT>
              <WFT size={11} color={wfInkSoft}>2 lines · est £258 · 2-5d lead</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>draft</WFPill>
          </div>
          <div style={{ marginTop: 6, paddingTop: 6, borderTop: `1px dashed ${wfInkFaint}` }}>
            <WFT size={11} color={wfInkSoft} style={{ fontStyle: 'italic' }}>6 flats Lavandula 'Hidcote' 9cm (×36) · £85</WFT>
            <WFT size={11} color={wfInkSoft} style={{ fontStyle: 'italic' }}>18 × Buxus sempervirens 30cm · £76</WFT>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <WFBtn k="f2-1e" size="sm" style={{ flex: 1 }}>edit</WFBtn>
            <WFBtn k="f2-1s" size="sm" primary style={{ flex: 1 }}>send</WFBtn>
          </div>
        </WFCard>

        <WFCard k="f2-2" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <WFT size={14} style={{ fontWeight: 600 }}>Hortus Supplies</WFT>
              <WFT size={11} color={wfInkSoft}>1 line · est £48 · 1d lead</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>draft</WFPill>
          </div>
          <div style={{ marginTop: 6, paddingTop: 6, borderTop: `1px dashed ${wfInkFaint}` }}>
            <WFT size={11} color={wfInkSoft}>8 × Compost 40L · £48</WFT>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <WFBtn k="f2-2e" size="sm" style={{ flex: 1 }}>edit</WFBtn>
            <WFBtn k="f2-2s" size="sm" primary style={{ flex: 1 }}>send</WFBtn>
          </div>
        </WFCard>

        <WFSection title="what happens next" />
        <WFBox k="f2-flow" pad={10} radius={10} stroke={wfInkFaint} dashed>
          <WFT size={11} color={wfInkSoft}>1. send → prints PO sheet (PurchaseOrderPrint)</WFT>
          <WFT size={11} color={wfInkSoft}>2. nursery pickup auto-scheduled</WFT>
          <WFT size={11} color={wfInkSoft}>3. receive → stock arrives → jobs unblocked</WFT>
        </WFBox>

        <WFBtn k="f2-all" primary size="lg" style={{ marginTop: 4 }}>
          send all 2 · print →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 170, right: -130 }}>
            one card per supplier — natural grouping
          </WFNote>
          <WFNote style={{ top: 320, right: -130 }}>
            per-supplier edit/send, or 'send all' at bottom
          </WFNote>
          <WFNote style={{ bottom: 100, right: -130 }}>
            inline flow reminder · print via PurchaseOrderPrint after send
          </WFNote>
        </>
      }
    </>);

}

// F3 — Nursery pickup: a delivery-job style screen for going to collect.
function ScreenF3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="pickup · Cramer"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="⋯" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 10 }}>
        <WFBox k="f3-hero" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <WFT size={11} color={wfAccent} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>pickup job</WFT>
              <WFH size={20} color={wfInk}>Cramer Wholesale</WFH>
              <WFT size={11} color={wfInkSoft}>Hadlow rd · 22 km · ~28 min</WFT>
            </div>
            <WFPill color={wfAccent}>today</WFPill>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
            <WFBtn k="f3-nav" size="sm" style={{ flex: 1 }}>↗ navigate</WFBtn>
            <WFBtn k="f3-call" size="sm" style={{ flex: 1 }}>call</WFBtn>
          </div>
        </WFBox>

        <WFT size={11} color={wfInkSoft}>PO #2027 · est £258 · for 2 jobs</WFT>

        <WFSection title="collect — tick as you load" />
        <WFBox k="f3-i1" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
              <WFT size={11} color={wfInkSoft}>× 36 · trays of 6</WFT>
            </div>
            <WFBox k="f3-cb1" pad={6} radius={6} thick fill={wfInk} stroke={wfInk} style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <WFT size={14} color={wfPaper} style={{ fontWeight: 600 }}>✓</WFT>
            </WFBox>
          </div>
        </WFBox>
        <WFBox k="f3-i2" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Buxus sempervirens 30cm</WFT>
              <WFT size={11} color={wfInkSoft}>× 18 · bare-root bundles</WFT>
            </div>
            <WFBox k="f3-cb2" pad={6} radius={6} style={{ width: 28, height: 28 }} />
          </div>
        </WFBox>

        <WFSection title="if short" />
        <WFRow
          title="report shortage"
          meta="adjust qty + note · auto re-orders"
          right={<WFT size={11}>›</WFT>}
          density={density} />
        
        <WFRow
          title="substitute plant"
          meta="search nursery catalog · keep on PO"
          right={<WFT size={11}>›</WFT>}
          density={density} />
        

        <WFBtn k="f3-done" primary size="lg" style={{ marginTop: 6 }}>
          received & on truck →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -130 }}>
            pickup = a job · routes, navigate, call
          </WFNote>
          <WFNote style={{ top: 290, right: -130 }}>
            ticklist not a form · driver loads while ticking
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            graceful failure: report short / substitute
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// G · Shifts & JobEvents (the field-worker workflow)
//   shift starts (depart depot OR check in @ greenhouse) → arrive job (distance)
//   → leave job (distance, planted, materials used/stored on-site, crew changes)
//   → end shift summary
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// L · Login & onboarding (magic link → org selection)
// ─────────────────────────────────────────────────────────────────────────────

// L1 — Sign in: passwordless. Enter email, get a magic link.
function ScreenL1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFBody style={{ gap: 0, justifyContent: 'space-between', paddingTop: 18, paddingBottom: 22 }}>
        {/* brand block */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, marginTop: 28 }}>
          <div
            style={{
              width: 64,
              height: 64,
              borderRadius: 16,
              border: `2.4px solid ${wfAccent}`,
              background: wfAccentSoft,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: '"Caveat", cursive',
              fontSize: 38,
              fontWeight: 700,
              color: wfAccent,
              transform: 'rotate(-3deg)',
            }}>
            🌱
          </div>
          <WFH size={30} style={{ marginTop: 4 }}>OpenSauce Dirt</WFH>
          <WFT size={12} color={wfInkSoft} style={{ textAlign: 'center' }}>
            jobs, crews & dirt — in your pocket
          </WFT>
        </div>

        {/* email + magic link */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <WFT size={12} color={wfInkSoft}>your work email</WFT>
          <WFBox k="l1-email" pad={11} radius={8} stroke={wfInk} style={{ background: wfSurface }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <WFIcon label="@" size={20} color={wfInkSoft} />
              <WFT size={15} color={wfInk}>sam@greenfields.co</WFT>
            </div>
          </WFBox>
          <WFBtn k="l1-send" primary size="lg" style={{ marginTop: 2, width: '100%' }}>
            send magic link →
          </WFBtn>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center', marginTop: 4 }}>
            <WFIcon label="🔒" size={16} color={wfInkFaint} />
            <WFT size={11} color={wfInkFaint}>no password — we email you a one-tap link</WFT>
          </div>
        </div>

        <WFT size={11} color={wfInkFaint} style={{ textAlign: 'center' }}>
          by continuing you agree to the terms & privacy
        </WFT>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 96, right: -128 }}>
            passwordless — field crews hate typing passwords on a phone
          </WFNote>
          <WFNote style={{ bottom: 150, right: -120 }}>
            one big primary action · nothing else competes
          </WFNote>
        </>
      }
    </>);

}

// L2 — Check your email: the link has been sent. Holding screen.
function ScreenL2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title=""
        left={<WFIcon label="←" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 0, justifyContent: 'center', alignItems: 'center', paddingBottom: 40 }}>
        <div
          style={{
            width: 84,
            height: 84,
            borderRadius: 20,
            border: `2.4px solid ${wfAccent}`,
            background: wfAccentSoft,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 40,
            transform: 'rotate(2deg)',
            marginBottom: 18,
          }}>
          ✉️
        </div>
        <WFH size={28} style={{ textAlign: 'center' }}>check your email</WFH>
        <WFT size={13} color={wfInkSoft} style={{ textAlign: 'center', marginTop: 8, maxWidth: 220 }}>
          we sent a sign-in link to
        </WFT>
        <WFT size={15} color={wfInk} style={{ textAlign: 'center', marginTop: 4, fontWeight: 600 }}>
          sam@greenfields.co
        </WFT>
        <WFT size={12} color={wfInkSoft} style={{ textAlign: 'center', marginTop: 10, maxWidth: 230, lineHeight: 1.4 }}>
          tap the link on this phone and you're in — the link works once and expires in 15 min
        </WFT>

        <WFBtn k="l2-open" primary size="lg" style={{ marginTop: 22, width: 200 }}>
          open mail app
        </WFBtn>
        <div style={{ display: 'flex', gap: 16, marginTop: 14 }}>
          <WFT size={12} color={wfAccent} style={{ textDecoration: 'underline' }}>resend link</WFT>
          <WFT size={12} color={wfInkSoft} style={{ textDecoration: 'underline' }}>use another email</WFT>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -120 }}>
            holding screen — polls for the tap, auto-advances when link is opened
          </WFNote>
          <WFNote style={{ bottom: 120, right: -120 }}>
            resend has a 30s cooldown · escape hatch to fix a typo'd email
          </WFNote>
        </>
      }
    </>);

}

// L3 — Choose organisation: a person can belong to several crews/companies.
function ScreenL3({ pattern, persona, density, annotated }) {
  const orgs = [
    { name: 'Greenfields Landscaping', role: 'Field crew', meta: 'Hadlow depot · 12 mates', initial: 'G', last: true },
    { name: 'Cramer Nurseries', role: 'Supplier account', meta: 'Tonbridge · read-only', initial: 'C' },
    { name: 'Oakhill Gardens Ltd', role: 'Owner', meta: '3 depots · 28 crew', initial: 'O' },
  ];
  return (
    <>
      <WFTopBar
        title="choose org"
        left={<WFIcon label="←" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 12 }}>
        <div style={{ marginTop: 2 }}>
          <WFH size={24}>g'day, Sam 👋</WFH>
          <WFT size={12} color={wfInkSoft} style={{ marginTop: 2 }}>
            you're signed in · pick where you're working today
          </WFT>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {orgs.map((o, i) =>
          <WFBox
            key={i}
            k={`l3-org-${i}`}
            pad={11}
            radius={12}
            thick={o.last}
            stroke={o.last ? wfAccent : wfInk}
            fill={o.last ? wfAccentSoft : 'transparent'}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div
                style={{
                  width: 42,
                  height: 42,
                  borderRadius: 10,
                  border: `2px solid ${o.last ? wfAccent : wfInk}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: '"Caveat", cursive',
                  fontSize: 24,
                  fontWeight: 700,
                  color: o.last ? wfAccent : wfInk,
                  flex: '0 0 auto',
                }}>
                  {o.initial}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <WFT size={15} style={{ fontWeight: 600 }}>{o.name}</WFT>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                    <WFPill color={o.last ? wfAccent : wfInkSoft} fill={o.last ? wfAccentSoft : 'transparent'}>
                      {o.role}
                    </WFPill>
                  </div>
                  <WFT size={11} color={wfInkSoft} style={{ marginTop: 4 }}>{o.meta}</WFT>
                </div>
                <WFIcon label="›" size={22} color={o.last ? wfAccent : wfInkSoft} />
              </div>
            </WFBox>
          )}
        </div>

        <WFBox k="l3-create" pad={11} radius={12} dashed stroke={wfInkFaint} style={{ marginTop: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <WFIcon label="+" size={20} color={wfInkSoft} />
            <WFT size={13} color={wfInkSoft}>create org</WFT>
          </div>
        </WFBox>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -120 }}>
            one identity, many orgs — the same person is crew here, owner there
          </WFNote>
          <WFNote style={{ bottom: 150, right: -120 }}>
            no memberships yet? this 'create org' is the whole screen — straight to setup
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// H · Customer creation
//   Every customer must have ≥1 garden AND a billing address. The billing
//   address is not separate — one garden is flagged as billing. Exactly one.
// ─────────────────────────────────────────────────────────────────────────────

// Sketchy toggle (on/off) — local to these screens.
function WFToggle({ on = false, color = wfAccent }) {
  return (
    <div
      style={{
        width: 40,
        height: 22,
        borderRadius: 11,
        border: `2px solid ${on ? color : wfInkSoft}`,
        background: on ? wfAccentSoft : 'transparent',
        position: 'relative',
        flex: '0 0 auto',
        transition: 'all .15s',
      }}>
      <div
        style={{
          position: 'absolute',
          top: 2,
          left: on ? 20 : 2,
          width: 14,
          height: 14,
          borderRadius: 7,
          background: on ? color : wfInkSoft,
        }} />
    </div>);
}

// Sketchy radio dot.
function WFRadio({ on = false, color = wfAccent }) {
  return (
    <div
      style={{
        width: 22,
        height: 22,
        borderRadius: 11,
        border: `2px solid ${on ? color : wfInkSoft}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flex: '0 0 auto',
      }}>
      {on && <div style={{ width: 11, height: 11, borderRadius: 6, background: color }} />}
    </div>);
}

// Sketchy segmented control — 2-3 options, one selected.
function WFSegment({ options, value }) {
  return (
    <div style={{ display: 'flex', border: `2px solid ${wfInk}`, borderRadius: 10, overflow: 'hidden' }}>
      {options.map((o, i) =>
      <div
        key={i}
        style={{
          flex: 1,
          textAlign: 'center',
          padding: '9px 6px',
          background: o.value === value ? wfInk : 'transparent',
          color: o.value === value ? wfPaper : wfInk,
          fontFamily: '"Caveat", cursive',
          fontSize: 16,
          fontWeight: 600,
          lineHeight: 1.1,
          borderLeft: i ? `1.5px solid ${wfInk}` : 'none',
        }}>
          {o.label}
        </div>
      )}
    </div>);
}

// H1 — New customer: contact + at least one garden, one of which is billing.
function ScreenH1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="new customer"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        right={<WFT size={13} color={wfInkFaint}>save</WFT>} />

      <WFBody style={{ gap: 11 }}>
        <WFSection title="who is this?" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          <WFInput k="h1-name" placeholder="name — person or company" value="Mrs Eleanor Penrose" />
          <div style={{ display: 'flex', gap: 7 }}>
            <WFInput k="h1-phone" placeholder="phone" value="07700 900 412" style={{ flex: 1 }} />
            <WFInput k="h1-email" placeholder="email" value="" style={{ flex: 1 }} />
          </div>
        </div>

        <WFSection title="gardens" action="+ add garden" style={{ marginTop: 6 }} />
        <WFT size={11} color={wfInkSoft} style={{ marginTop: -2 }}>
          at least one — work happens at a garden, not a customer
        </WFT>

        <WFBox k="h1-g1" pad={10} radius={11} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ flex: 1 }}>
              <WFT size={14} style={{ fontWeight: 600 }}>Rosehill</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>14 Rosehill Lane, Hadlow · TN11 0DG</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>★ billing</WFPill>
          </div>
        </WFBox>

        <WFBox k="h1-add" pad={10} radius={11} dashed stroke={wfInkFaint}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <WFIcon label="+" size={20} color={wfInkSoft} />
            <WFT size={13} color={wfInkSoft}>add another garden</WFT>
          </div>
        </WFBox>

        <WFBox k="h1-rule" pad={9} radius={9} stroke={wfBlue} style={{ background: wfBlueSoft, marginTop: 2 }}>
          <WFT size={11} color={wfInk}>
            ⓘ every customer needs a garden + a billing address. the billing address is whichever garden you flag ★.
          </WFT>
        </WFBox>

        <WFBtn k="h1-save" primary size="lg" style={{ marginTop: 4, width: '100%' }}>
          save customer
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 120, right: -126 }}>
            name + one way to reach them — that's the whole contact
          </WFNote>
          <WFNote style={{ top: 300, right: -126 }}>
            first garden auto-flagged ★ billing · can't save with zero gardens
          </WFNote>
        </>
      }
    </>);

}

// H2 — Add garden: address + the billing toggle (exactly one customer-wide).
function ScreenH2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="add garden"
        left={<WFIcon label="←" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        <WFSection title="what's it called?" />
        <WFInput k="h2-label" placeholder="garden name — e.g. Rosehill, the cottage" value="The Coach House" />

        <WFSection title="address" style={{ marginTop: 6 }} />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          <WFInput k="h2-l1" placeholder="street / line 1" value="2 Mill Lane" />
          <div style={{ display: 'flex', gap: 7 }}>
            <WFInput k="h2-town" placeholder="town" value="Tonbridge" style={{ flex: 1.4 }} />
            <WFInput k="h2-pc" placeholder="postcode" value="TN9 1BX" style={{ flex: 1 }} />
          </div>
          <WFInput k="h2-access" placeholder="access notes — gate code, parking, dog…" value="" />
        </div>

        <WFBox k="h2-bill" pad={11} radius={11} stroke={wfAccent} style={{ marginTop: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ flex: 1 }}>
              <WFT size={14} style={{ fontWeight: 600 }}>★ Use as billing address</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>invoices for this customer go here</WFT>
            </div>
            <WFToggle on={true} />
          </div>
          <div style={{ marginTop: 8, paddingTop: 8, borderTop: `1px dashed ${wfInkFaint}` }}>
            <WFT size={11} color={wfInkSoft}>
              turning this on moves the ★ off <span style={{ color: wfInk, fontWeight: 600 }}>Rosehill</span> — only one garden can be billing.
            </WFT>
          </div>
        </WFBox>

        <WFBtn k="h2-save" primary size="lg" style={{ marginTop: 4, width: '100%' }}>
          save garden
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -126 }}>
            a garden is a named place — a customer can have several
          </WFNote>
          <WFNote style={{ bottom: 150, right: -120 }}>
            billing is a single-select across all the customer's gardens, not a separate address
          </WFNote>
        </>
      }
    </>);

}

// H3 — Gardens & billing: pick which garden is the billing address.
function ScreenH3({ pattern, persona, density, annotated }) {
  const gardens = [
    { name: 'Rosehill', addr: '14 Rosehill Lane, Hadlow · TN11 0DG', billing: false },
    { name: 'The Coach House', addr: '2 Mill Lane, Tonbridge · TN9 1BX', billing: true },
    { name: 'Allotment plot 7', addr: 'Vauxhall Gardens, Tonbridge · TN9 2RX', billing: false },
  ];
  return (
    <>
      <WFTopBar
        title="gardens & billing"
        left={<WFIcon label="←" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        <div style={{ marginTop: 2 }}>
          <WFH size={22}>Mrs Penrose</WFH>
          <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>3 gardens · tap ★ to set the billing address</WFT>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {gardens.map((g, i) =>
          <WFBox
            key={i}
            k={`h3-g-${i}`}
            pad={11}
            radius={11}
            thick={g.billing}
            stroke={g.billing ? wfAccent : wfInk}
            fill={g.billing ? wfAccentSoft : 'transparent'}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <WFRadio on={g.billing} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                    <WFT size={14} style={{ fontWeight: 600 }}>{g.name}</WFT>
                    {g.billing && <WFPill color={wfAccent} fill={wfAccentSoft}>★ billing</WFPill>}
                  </div>
                  <WFT size={11} color={wfInkSoft} style={{ marginTop: 3 }}>{g.addr}</WFT>
                </div>
              </div>
            </WFBox>
          )}
        </div>

        <WFBox k="h3-rule" pad={9} radius={9} stroke={wfBlue} style={{ background: wfBlueSoft, marginTop: 2 }}>
          <WFT size={11} color={wfInk}>
            ⓘ exactly one garden is the billing address — invoices & statements post there.
          </WFT>
        </WFBox>

        <WFBtn k="h3-done" primary size="lg" style={{ marginTop: 2, width: '100%' }}>
          done
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 140, right: -120 }}>
            single-select radio — choosing one clears the others
          </WFNote>
          <WFNote style={{ bottom: 130, right: -120 }}>
            billing address ≠ a separate field · it's always one of the gardens
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// I · Customers (list + detailed summary → create engagement)
// ─────────────────────────────────────────────────────────────────────────────

// I1 — Customers list: searchable, filterable, with a quick add.
function ScreenI1({ pattern, persona, density, annotated }) {
  const customers = [
    { name: 'Mrs Eleanor Penrose', meta: '3 gardens · Hadlow', right: <WFPill color={wfBlue} fill={wfBlueSoft}>£1,200 due</WFPill>, sub: '1 active engagement', initial: 'P', active: true },
    { name: 'Oakwood School', meta: '1 garden · Tonbridge', right: <WFPill color={wfAccent} fill={wfAccentSoft}>2 active</WFPill>, sub: 'grounds contract', initial: 'O', active: true },
    { name: 'The Vineyard Estate', meta: '2 gardens · Penshurst', right: null, sub: 'last visit 18 Feb', initial: 'V' },
    { name: 'Mr & Mrs Dale', meta: '1 garden · Leigh', right: <WFPill color={wfInkSoft}>new</WFPill>, sub: 'no engagements yet', initial: 'D' },
    { name: 'Marshfield Nursing Home', meta: '1 garden · Tonbridge', right: null, sub: 'maintenance · monthly', initial: 'M' },
  ];
  return (
    <>
      <WFTopBar
        title="customers"
        left={<WFIcon label="⌂" size={22} color={wfInkSoft} />}
        right={<WFIcon label="+" size={22} color={wfAccent} />} />

      <WFBody style={{ gap: 9 }}>
        <WFInput k="i1-search" placeholder="🔍  search name, garden, postcode…" value="" />

        <div style={{ display: 'flex', gap: 6 }}>
          <WFPill color={wfAccent} fill={wfAccentSoft}>all · 24</WFPill>
          <WFPill color={wfInkSoft}>active</WFPill>
          <WFPill color={wfInkSoft}>owing</WFPill>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 2 }}>
          {customers.map((c, i) =>
          <WFBox key={i} k={`i1-c-${i}`} pad={10} radius={11} stroke={wfInk}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div
                style={{
                  width: 38,
                  height: 38,
                  borderRadius: 10,
                  border: `2px solid ${c.active ? wfAccent : wfInk}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: '"Caveat", cursive',
                  fontSize: 22,
                  fontWeight: 700,
                  color: c.active ? wfAccent : wfInk,
                  flex: '0 0 auto',
                }}>
                  {c.initial}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <WFT size={14} style={{ fontWeight: 600 }}>{c.name}</WFT>
                  <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>{c.meta}</WFT>
                  <WFT size={11} color={wfInkSoft} style={{ marginTop: 1 }}>{c.sub}</WFT>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4, flex: '0 0 auto' }}>
                  {c.right}
                  <WFIcon label="›" size={20} color={wfInkSoft} />
                </div>
              </div>
            </WFBox>
          )}
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 130, right: -122 }}>
            search hits gardens & postcodes too — crews think in places
          </WFNote>
          <WFNote style={{ top: 250, right: -122 }}>
            right rail surfaces what's owed / how many engagements are live
          </WFNote>
        </>
      }
    </>);

}

// I2 — Customer summary: everything at a glance + sticky 'new engagement'.
function ScreenI2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="customer"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFIcon label="✎" size={20} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        {/* identity */}
        <div style={{ display: 'flex', gap: 11, alignItems: 'flex-start' }}>
          <div
            style={{
              width: 48,
              height: 48,
              borderRadius: 12,
              border: `2.4px solid ${wfAccent}`,
              background: wfAccentSoft,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontFamily: '"Caveat", cursive',
              fontSize: 28,
              fontWeight: 700,
              color: wfAccent,
              flex: '0 0 auto',
            }}>
            P
          </div>
          <div style={{ flex: 1 }}>
            <WFH size={24}>Mrs Eleanor Penrose</WFH>
            <div style={{ display: 'flex', gap: 12, marginTop: 3 }}>
              <WFT size={11} color={wfInkSoft}>📞 07700 900 412</WFT>
              <WFT size={11} color={wfInkSoft}>✉ epenrose@…</WFT>
            </div>
          </div>
        </div>

        {/* KPIs */}
        <div style={{ display: 'flex', gap: 8 }}>
          <WFStat k="i2-k1" value="3" label="gardens" />
          <WFStat k="i2-k2" value="1" label="active eng." color={wfAccent} />
          <WFStat k="i2-k3" value="£1,200" label="balance due" color={wfBlue} />
        </div>

        {/* gardens — billing flagged */}
        <WFSection title="gardens" action="+ add" />
        <WFBox k="i2-g1" pad={9} radius={10} stroke={wfInk}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ flex: 1 }}>
              <WFT size={13} style={{ fontWeight: 600 }}>Rosehill</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 1 }}>14 Rosehill Lane · TN11 0DG</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>★ billing</WFPill>
          </div>
        </WFBox>
        <WFRow title="The Coach House" meta="2 Mill Lane · TN9 1BX" density={density} right={<WFT size={11} color={wfInkSoft}>›</WFT>} />
        <WFRow title="Allotment plot 7" meta="Vauxhall Gardens · TN9 2RX" density={density} right={<WFT size={11} color={wfInkSoft}>›</WFT>} />

        {/* engagements */}
        <WFSection title="engagements" action="see all" style={{ marginTop: 4 }} />
        <WFCard k="i2-e1" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ flex: 1 }}>
              <WFT size={14} style={{ fontWeight: 600 }}>Front bed redesign</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>Rosehill · Mar–Oct · signed ✓</WFT>
            </div>
            <WFPill color={wfAccent} fill={wfAccentSoft}>in&nbsp;progress</WFPill>
          </div>
        </WFCard>
        <WFRow title="Pond clearance" meta="The Coach House · 2025 · closed" density={density} right={<WFPill color={wfInkSoft}>done</WFPill>} />

        <WFBox k="i2-hint" pad={9} radius={9} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>
            an engagement is a contract for one garden — scope, prices, signature, child jobs.
          </WFT>
        </WFBox>
      </WFBody>

      {/* sticky CTA — make creating an engagement a one-tap action */}
      <div
        style={{
          flex: '0 0 auto',
          borderTop: `1.5px solid ${wfInk}`,
          background: wfPaper,
          padding: '10px 14px',
        }}>
        <WFBtn k="i2-new-eng" primary size="lg" style={{ width: '100%' }}>
          + new engagement
        </WFBtn>
      </div>
      {annotated &&
      <>
          <WFNote style={{ top: 96, right: -122 }}>
            contact + balance up top — the two things you check first
          </WFNote>
          <WFNote style={{ top: 250, right: -122 }}>
            gardens carry the ★ billing flag through from creation
          </WFNote>
          <WFNote style={{ bottom: 70, right: -124 }}>
            sticky primary — new engagement asks 'which garden?' then opens D1
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// J · Ad-hoc job (unplanned visit)
//   From Jobs → '+ ad-hoc'. Creates a job + an arrival OR departure event.
//   Arrival: opens an active job you close normally before the next.
//   Departure: logs a finished visit retrospectively (timespan + materials) in one screen.
//   Gated: only available when there's NO active job.
// ─────────────────────────────────────────────────────────────────────────────

// Shared garden-picker row used by the ad-hoc forms.
function AdHocGarden() {
  return (
    <WFBox k="adhoc-garden" pad={9} radius={10} stroke={wfInk}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div
          style={{
            width: 36,
            height: 36,
            borderRadius: 9,
            border: `2px solid ${wfAccent}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontFamily: '"Caveat", cursive',
            fontSize: 20,
            fontWeight: 700,
            color: wfAccent,
            flex: '0 0 auto',
          }}>
          P
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <WFT size={14} style={{ fontWeight: 600 }}>Mrs Penrose · Rosehill</WFT>
          <WFT size={11} color={wfInkSoft} style={{ marginTop: 1 }}>14 Rosehill Lane · TN11 0DG</WFT>
        </div>
        <WFT size={11} color={wfAccent} style={{ textDecoration: 'underline' }}>change</WFT>
      </div>
    </WFBox>);
}

// J1 — Jobs screen entry + the gate. Button is live only with no active job.
function ScreenJ1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="jobs"
        left={<WFIcon label="⌂" size={22} color={wfInkSoft} />}
        right={<WFIcon label="🔍" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        {/* active job — the reason the gate is closed */}
        <WFBox k="j1-active" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={11} color={wfAccent} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>on a job · 38m</WFT>
              <WFT size={14} style={{ fontWeight: 600, marginTop: 2 }}>Greenwood · hedge trim</WFT>
            </div>
            <WFBtn k="j1-close" size="sm">close →</WFBtn>
          </div>
        </WFBox>

        {/* gated ad-hoc button */}
        <WFBox k="j1-adhoc" pad={12} radius={11} dashed stroke={wfInkFaint} style={{ background: wfSurface }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <WFIcon label="🔒" size={22} color={wfInkFaint} />
            <div style={{ flex: 1 }}>
              <WFT size={14} color={wfInkFaint} style={{ fontWeight: 600 }}>+ ad-hoc job</WFT>
              <WFT size={11} color={wfInkFaint} style={{ marginTop: 2 }}>close your current job first — one job at a time</WFT>
            </div>
          </div>
        </WFBox>

        <WFSection title="today" />
        <WFRow title="Greenwood · hedge trim" meta="9:02 · on site now" accent={wfAccent} density={density} right={<WFPill color={wfAccent}>live</WFPill>} />
        <WFRow title="St Anne's · bed prep" meta="13:00 · scheduled · 4h" density={density} />
        <WFRow title="Marshfield · mow" meta="15:30 · scheduled · 1h" density={density} />
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -124 }}>
            ad-hoc button greys out while a job is live — gate is the active job
          </WFNote>
          <WFNote style={{ top: 250, right: -124 }}>
            free of a job → button turns green & opens the create form
          </WFNote>
        </>
      }
    </>);

}

// J2 — Create ad-hoc · ARRIVAL: minimal. Opens an active job you close later.
function ScreenJ2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="ad-hoc job"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        <WFSection title="where?" />
        <AdHocGarden />

        <WFSection title="what are you doing?" style={{ marginTop: 4 }} />
        <WFInput k="j2-desc" placeholder="job description — e.g. emergency storm clear-up" value="Storm branch clear-up" />

        <WFSection title="arrival or departure?" style={{ marginTop: 4 }} />
        <WFSegment
          value="arrival"
          options={[
            { value: 'arrival', label: 'Arriving now' },
            { value: 'departure', label: 'Log a past visit' },
          ]} />

        <WFBox k="j2-explain" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft} style={{ marginTop: 2 }}>
          <WFT size={13} color={wfInk} style={{ fontWeight: 600 }}>↳ logs your arrival now</WFT>
          <WFT size={12} color={wfInkSoft} style={{ marginTop: 4, lineHeight: 1.4 }}>
            this becomes your active job. flag materials & supplies as you work, then close it before the next job — just like a scheduled one.
          </WFT>
        </WFBox>

        <WFBtn k="j2-start" primary size="lg" style={{ marginTop: 4, width: '100%' }}>
          start job · log arrival →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 110, right: -124 }}>
            pick an existing garden or '+ new' on the fly
          </WFNote>
          <WFNote style={{ bottom: 120, right: -122 }}>
            arrival path = single arrival event · you'll close it like B4
          </WFNote>
        </>
      }
    </>);

}

// J3 — Create ad-hoc · DEPARTURE: full retrospective log in one screen.
function ScreenJ3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="ad-hoc job"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />} />

      <WFBody style={{ gap: 11 }}>
        <WFSection title="where?" />
        <AdHocGarden />

        <WFSection title="what did you do?" style={{ marginTop: 4 }} />
        <WFInput k="j3-desc" placeholder="job description" value="Dropped off 6 bags compost" />

        <WFSection title="arrival or departure?" style={{ marginTop: 4 }} />
        <WFSegment
          value="departure"
          options={[
            { value: 'arrival', label: 'Arriving now' },
            { value: 'departure', label: 'Log a past visit' },
          ]} />

        {/* timespan — required for departure */}
        <WFBox k="j3-span" pad={10} radius={10} thick stroke={wfAccent} fill={wfAccentSoft} style={{ marginTop: 2 }}>
          <WFT size={11} color={wfAccent} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>time on site</WFT>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
            <WFBox k="j3-from" pad={7} radius={7} stroke={wfInk} style={{ flex: 1, background: wfPaper }}>
              <WFT size={11} color={wfInkSoft}>from</WFT>
              <WFT size={16}>10:20</WFT>
            </WFBox>
            <WFT size={16} color={wfInkSoft}>→</WFT>
            <WFBox k="j3-to" pad={7} radius={7} stroke={wfInk} style={{ flex: 1, background: wfPaper }}>
              <WFT size={11} color={wfInkSoft}>to</WFT>
              <WFT size={16}>10:55</WFT>
            </WFBox>
            <WFPill color={wfAccent} fill={wfPaper}>35 min</WFPill>
          </div>
        </WFBox>

        {/* materials used */}
        <WFSection title="materials used" action="+ add" style={{ marginTop: 4 }} />
        <WFRow title="Compost, peat-free" meta="6 bags · from van stock" density={density} right={<WFT size={13} style={{ fontWeight: 600 }}>6</WFT>} />
        <WFRow title="Bark mulch" meta="2 bags" density={density} right={<WFT size={13} style={{ fontWeight: 600 }}>2</WFT>} />

        {/* supplies used */}
        <WFSection title="supplies / consumables" action="+ add" style={{ marginTop: 2 }} />
        <WFRow title="Tree ties" meta="pack" density={density} right={<WFT size={13} style={{ fontWeight: 600 }}>1</WFT>} />

        <WFBox k="j3-note" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>notes / photos — optional…</WFT>
        </WFBox>
      </WFBody>

      {/* sticky save — departure is committed in one go, no active job left open */}
      <div
        style={{
          flex: '0 0 auto',
          borderTop: `1.5px solid ${wfInk}`,
          background: wfPaper,
          padding: '10px 14px',
        }}>
        <WFBtn k="j3-save" primary size="lg" style={{ width: '100%' }}>
          save visit · log departure
        </WFBtn>
      </div>
      {annotated &&
      <>
          <WFNote style={{ top: 250, right: -124 }}>
            departure = one screen · timespan required, no live timer to close
          </WFNote>
          <WFNote style={{ bottom: 80, right: -122 }}>
            materials & supplies flagged exactly like a regular job
          </WFNote>
        </>
      }
    </>);

}

// ─────────────────────────────────────────────────────────────────────────────
// K · Job creation (planned)
//   The foundational create flow. A Job has a TYPE (client work / shift / internal).
//   Client work: an optional engagement drives the garden; a service category is
//   required; addressable categories require a garden. Then schedule + crew + estimate.
//   (Ad-hoc · section J is the unplanned special case of this.)
// ─────────────────────────────────────────────────────────────────────────────

// Small step dots for the 2-step create.
function WFSteps({ step = 1, total = 2 }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      {Array.from({ length: total }).map((_, i) =>
      <div
        key={i}
        style={{
          width: i + 1 === step ? 20 : 8,
          height: 8,
          borderRadius: 4,
          background: i + 1 === step ? wfAccent : 'transparent',
          border: `1.5px solid ${i + 1 <= step ? wfAccent : wfInkFaint}`,
        }} />
      )}
    </div>);
}

// Selectable category chip.
function WFChip({ children, on = false }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '7px 12px',
        borderRadius: 9,
        border: `1.8px solid ${on ? wfAccent : wfInkSoft}`,
        background: on ? wfAccentSoft : 'transparent',
        color: on ? wfAccent : wfInkSoft,
        fontFamily: '"Caveat", cursive',
        fontSize: 15,
        fontWeight: on ? 700 : 600,
        lineHeight: 1,
      }}>
      {children}
    </span>);
}

// K1 — New job · context: type → engagement → category → garden.
function ScreenK1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="new job"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        right={<WFSteps step={1} total={2} />} />

      <WFBody style={{ gap: 11 }}>
        <WFSection title="type of work" />
        <WFSegment
          value="client"
          options={[
            { value: 'client', label: 'Client work' },
            { value: 'shift', label: 'Shift' },
            { value: 'internal', label: 'Internal' },
          ]} />

        <WFSection title="for which engagement?" action="skip" style={{ marginTop: 4 }} />
        <WFBox k="k1-eng" pad={10} radius={11} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <div
              style={{
                width: 40,
                height: 40,
                borderRadius: 10,
                border: `2px solid ${wfAccent}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontFamily: '"Caveat", cursive',
                fontSize: 22,
                fontWeight: 700,
                color: wfAccent,
                flex: '0 0 auto',
              }}>
              P
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <WFT size={14} style={{ fontWeight: 600 }}>Front bed redesign</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>Mrs Penrose · signed ✓</WFT>
            </div>
            <WFT size={11} color={wfAccent} style={{ textDecoration: 'underline' }}>change</WFT>
          </div>
        </WFBox>
        <WFT size={11} color={wfInkSoft} style={{ marginTop: -2 }}>
          picking an engagement fills in the customer &amp; garden below
        </WFT>

        <WFSection title="service category" style={{ marginTop: 4 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
          <WFChip>Install</WFChip>
          <WFChip>Delivery</WFChip>
          <WFChip on>Pruning</WFChip>
          <WFChip>Design</WFChip>
          <WFChip>Consult</WFChip>
          <WFChip>Winterize</WFChip>
          <WFChip>Nursery run</WFChip>
          <WFChip>Other</WFChip>
        </div>

        <WFSection title="garden / site" style={{ marginTop: 6 }} />
        <WFBox k="k1-garden" pad={10} radius={11} stroke={wfInk}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ flex: 1 }}>
              <WFT size={14} style={{ fontWeight: 600 }}>Rosehill</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>14 Rosehill Lane · TN11 0DG · from engagement</WFT>
            </div>
            <WFIcon label="✓" size={20} color={wfAccent} />
          </div>
        </WFBox>

        <WFBtn k="k1-next" primary size="lg" style={{ marginTop: 8, width: '100%' }}>
          next · schedule &amp; crew →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 96, right: -126 }}>
            type drives the fields · shift = no garden, internal = account code instead of category
          </WFNote>
          <WFNote style={{ top: 300, right: -124 }}>
            addressable categories (prune, install…) require a garden — others (nursery run) don't
          </WFNote>
        </>
      }
    </>);

}

// K2 — New job · schedule & crew: date, duration, crew, notes, live estimate.
function ScreenK2({ pattern, persona, density, annotated }) {
  const crew = [
    { initial: 'S', name: 'Sam (you)', rate: '£24/h', lead: true },
    { initial: 'R', name: 'Ravi', rate: '£21/h' },
  ];
  return (
    <>
      <WFTopBar
        title="new job"
        left={<WFIcon label="←" size={22} color={wfInkSoft} />}
        right={<WFSteps step={2} total={2} />} />

      <WFBody style={{ gap: 11 }}>
        {/* summary of step 1 */}
        <WFBox k="k2-sum" pad={9} radius={10} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <WFPill color={wfAccent} fill={wfAccentSoft}>Pruning</WFPill>
            <WFT size={12} color={wfInkSoft}>Front bed redesign · Rosehill</WFT>
          </div>
        </WFBox>

        <WFSection title="when?" />
        <div style={{ display: 'flex', gap: 7 }}>
          <WFBox k="k2-date" pad={9} radius={9} stroke={wfInk} style={{ flex: 1.4, background: wfPaper }}>
            <WFT size={11} color={wfInkSoft}>date</WFT>
            <WFT size={16}>Tue 9 Jun</WFT>
          </WFBox>
          <WFBox k="k2-dur" pad={9} radius={9} stroke={wfInk} style={{ flex: 1, background: wfPaper }}>
            <WFT size={11} color={wfInkSoft}>est. duration</WFT>
            <WFT size={16}>3h 30m</WFT>
          </WFBox>
        </div>

        <WFSection title="crew" action="+ add" style={{ marginTop: 4 }} />
        <WFT size={11} color={wfInkSoft} style={{ marginTop: -2 }}>
          tentative — drives the schedule &amp; the cost estimate
        </WFT>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {crew.map((c, i) =>
          <WFBox key={i} k={`k2-crew-${i}`} pad={9} radius={10} stroke={wfInk}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
                <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 9,
                  border: `2px solid ${wfInk}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: '"Caveat", cursive',
                  fontSize: 18,
                  fontWeight: 700,
                  color: wfInk,
                  flex: '0 0 auto',
                }}>
                  {c.initial}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                    <WFT size={14} style={{ fontWeight: 600 }}>{c.name}</WFT>
                    {c.lead && <WFPill color={wfAccent} fill={wfAccentSoft}>lead</WFPill>}
                  </div>
                  <WFT size={11} color={wfInkSoft} style={{ marginTop: 2 }}>{c.rate}</WFT>
                </div>
                <WFIcon label="✕" size={16} color={wfInkFaint} />
              </div>
            </WFBox>
          )}
        </div>

        <WFSection title="notes" style={{ marginTop: 4 }} />
        <WFBox k="k2-notes" pad={9} radius={9} stroke={wfInkSoft} style={{ background: wfSurface }}>
          <WFLines count={2} />
        </WFBox>

        {/* live estimate */}
        <WFBox k="k2-est" pad={11} radius={11} thick stroke={wfBlue} fill={wfBlueSoft} style={{ marginTop: 2 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={11} color={wfBlue} style={{ fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>estimated cost</WFT>
              <WFT size={11} color={wfInkSoft} style={{ marginTop: 3 }}>7 man-hrs × rate + overhead</WFT>
            </div>
            <WFT size={22} style={{ fontWeight: 700 }}>£196</WFT>
          </div>
        </WFBox>
      </WFBody>

      {/* sticky create */}
      <div
        style={{
          flex: '0 0 auto',
          borderTop: `1.5px solid ${wfInk}`,
          background: wfPaper,
          padding: '10px 14px',
        }}>
        <WFBtn k="k2-create" primary size="lg" style={{ width: '100%' }}>
          create job
        </WFBtn>
      </div>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -124 }}>
            duration estimate × crew rates → the live cost, before anyone's on site
          </WFNote>
          <WFNote style={{ bottom: 110, right: -122 }}>
            estimate updates as crew is added — man-hours × man-hour-rate + materials
          </WFNote>
        </>
      }
    </>);

}

// G1 — Start shift: pick where you're starting from. Two paths.
function ScreenG1({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="start shift"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />} />
      
      <WFBody style={{ gap: 12 }}>
        <div>
          <WFH size={22}>g'morning, Sam</WFH>
          <WFT size={11} color={wfInkSoft}>Tue 12 Mar · 8:42 · where are you?</WFT>
        </div>

        <WFBox k="g1-depot" pad={12} radius={12} thick stroke={wfAccent} fill={wfAccentSoft}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ flex: 1 }}>
              <WFH size={20} color={wfAccent}>departing depot</WFH>
              <WFT size={11} color={wfInkSoft}>loading the van · driving to a job</WFT>
            </div>
            <WFIcon label="🚐" size={32} color={wfAccent} />
          </div>
          <div style={{ marginTop: 8, paddingTop: 8, borderTop: `1px dashed ${wfAccent}` }}>
            <WFT size={11} color={wfInkSoft}>start odometer</WFT>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
              <WFH size={28}>48,210</WFH>
              <WFT size={12} color={wfInkSoft}>km · last: 48,184</WFT>
            </div>
          </div>
        </WFBox>

        <div style={{ textAlign: 'center' }}>
          <WFT size={11} color={wfInkFaint}>— or —</WFT>
        </div>

        <WFBox k="g1-gh" pad={12} radius={12} stroke={wfInk}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ flex: 1 }}>
              <WFH size={20}>checking in at…</WFH>
              <WFT size={11} color={wfInkSoft}>starting work on-site · no driving</WFT>
            </div>
            <WFIcon label="⌂" size={32} />
          </div>
          <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <WFBox k="g1-loc1" pad={8} radius={8} stroke={wfInkFaint}>
              <WFT size={13} style={{ fontWeight: 600 }}>● Hadlow greenhouse</WFT>
              <WFT size={11} color={wfInkSoft}>your usual · last checked in Mon</WFT>
            </WFBox>
            <WFBox k="g1-loc2" pad={8} radius={8} stroke={wfInkFaint}>
              <WFT size={13} style={{ fontWeight: 600 }}>Greenwood Estate</WFT>
              <WFT size={11} color={wfInkSoft}>scheduled 9:00 · already on-site</WFT>
            </WFBox>
            <WFT size={11} color={wfInkSoft} style={{ textAlign: 'center', marginTop: 2 }}>
              + somewhere else
            </WFT>
          </div>
        </WFBox>

        <WFBtn k="g1-go" primary size="lg" style={{ marginTop: 4 }}>
          start shift →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -130 }}>
            two paths · depart depot (distance) OR check in
          </WFNote>
          <WFNote style={{ top: 260, right: -130 }}>
            odo prefilled w/ last reading · just confirm
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            usual greenhouse + today's first scheduled job offered
          </WFNote>
        </>
      }
    </>);

}

// G2 — Arrive at job: fast log. Distance + who's here.
function ScreenG2({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="arrived"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>auto-logged at 9:02 · Greenwood Estate</WFT>} />
      
      <WFBody style={{ gap: 12 }}>
        <div>
          <WFH size={22}>Greenwood Estate</WFH>
          <WFT size={11} color={wfInkSoft}>hedge trim · scheduled 9:00–11:00</WFT>
        </div>

        <WFBox k="g2-odo" pad={12} radius={12} thick>
          <WFT size={11} color={wfInkSoft}>odometer on arrival</WFT>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
            <WFH size={32}>48,224</WFH>
            <WFT size={12} color={wfInkSoft}>km · +22 from depot</WFT>
          </div>
          <WFT size={11} color={wfInkSoft} style={{ marginTop: 4 }}>
            tap to edit ✎
          </WFT>
        </WFBox>

        <WFSection title="who's here" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <WFBox k="g2-c1" pad={8} radius={8} fill={wfSurface}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <WFT size={13} style={{ fontWeight: 600 }}>● Sam (you)</WFT>
                <WFT size={11} color={wfInkSoft}>driver · arrived</WFT>
              </div>
              <WFT size={14}>✓</WFT>
            </div>
          </WFBox>
          <WFBox k="g2-c2" pad={8} radius={8} fill={wfSurface}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <WFT size={13} style={{ fontWeight: 600 }}>● Joe</WFT>
                <WFT size={11} color={wfInkSoft}>passenger · arrived</WFT>
              </div>
              <WFT size={14}>✓</WFT>
            </div>
          </WFBox>
          <WFBox k="g2-c3" pad={8} radius={8} stroke={wfInkFaint} dashed>
            <WFT size={13} color={wfInkSoft}>+ add someone (met on-site, contractor…)</WFT>
          </WFBox>
        </div>

        <WFBox k="g2-note" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>note (optional) — gate code, where to park, etc.</WFT>
        </WFBox>

        <div style={{ display: 'flex', gap: 6 }}>
          <WFBtn k="g2-back" size="md" style={{ flex: 1 }}>back</WFBtn>
          <WFBtn k="g2-start" primary size="md" style={{ flex: 2 }}>start working →</WFBtn>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 150, right: -130 }}>
            arrival = quick. odo pre-read + crew confirm
          </WFNote>
          <WFNote style={{ top: 320, right: -130 }}>
            crew carried over from shift · easy to add stragglers
          </WFNote>
        </>
      }
    </>);

}

// G3 — Job close-out (MANAGER side). Per David: leave is complex; staff just
// leaves (see G5), manager records what was done and used here.
function ScreenG3({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="close out job"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>Greenwood Estate · manager entry · worked 2h 16m</WFT>} />
      
      <WFBody style={{ gap: 10 }}>
        <WFBox k="g3-who" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>
            ⓘ staff already left — log what was done & used to close the job.
          </WFT>
        </WFBox>

        <WFBox k="g3-odo" pad={10} radius={10} thick>
          <WFT size={11} color={wfInkSoft}>odometer leaving</WFT>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
            <WFH size={26}>48,224</WFH>
            <WFT size={11} color={wfInkSoft}>km · same as arrival (still here)</WFT>
          </div>
        </WFBox>

        <WFSection title="what was planted" action="+ add" />
        <WFBox k="g3-p1" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Lavandula 'Hidcote' 9cm</WFT>
            <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <WFBtn k="g3-p1m" size="sm" style={{ minWidth: 26 }}>−</WFBtn>
              <WFH size={18} style={{ minWidth: 24, textAlign: 'center' }}>18</WFH>
              <WFBtn k="g3-p1p" size="sm" style={{ minWidth: 26 }}>+</WFBtn>
            </div>
          </div>
          <WFT size={11} color={wfInkSoft}>planned 24 · planted 18 · 6 returning</WFT>
        </WFBox>
        <WFBox k="g3-p2" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <WFT size={13} style={{ fontWeight: 600, fontStyle: 'italic' }}>Buxus sempervirens 30cm</WFT>
            <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <WFT size={11} color={wfGreen}>12 ✓</WFT>
            </div>
          </div>
          <WFT size={11} color={wfInkSoft}>planned 12 · all in</WFT>
        </WFBox>

        <WFSection title="materials used" />
        <WFBox k="g3-m1" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={13} style={{ fontWeight: 600 }}>Mulch · bag</WFT>
              <WFT size={11} color={wfInkSoft}>brought 4 · used 3</WFT>
            </div>
            <WFH size={20}>3</WFH>
          </div>
        </WFBox>
        <WFBox k="g3-m2" pad={8} radius={8}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={13} style={{ fontWeight: 600 }}>Bone meal</WFT>
              <WFT size={11} color={wfInkSoft}>brought 2 · used 1</WFT>
            </div>
            <WFH size={20}>1</WFH>
          </div>
        </WFBox>

        <WFSection title="stored on-site" />
        <WFBox k="g3-s1" pad={8} radius={10} stroke={wfBlue} style={{ background: wfBlueSoft }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <WFT size={13} style={{ fontWeight: 600 }}>1 bag mulch · 1 sack bone meal</WFT>
              <WFT size={11} color={wfInkSoft}>left in shed · for next visit Wed</WFT>
            </div>
            <WFT size={11} color={wfBlue}>edit</WFT>
          </div>
        </WFBox>
        <WFBox k="g3-s2" pad={8} radius={8} stroke={wfInkFaint} dashed>
          <WFT size={13} color={wfInkSoft}>+ another item stored on-site</WFT>
        </WFBox>

        <WFSection title="crew here" action="edit" />
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          <WFPill fill={wfInk} color={wfPaper}>● Sam 2:16</WFPill>
          <WFPill fill={wfInk} color={wfPaper}>● Joe 2:16</WFPill>
          <WFPill>+ Pete (joined 10:30)</WFPill>
        </div>

        <WFBox k="g3-note" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>notes — what's left to do, customer feedback, photos…</WFT>
        </WFBox>

        <div style={{ display: 'flex', gap: 6 }}>
          <WFBtn k="g3-incomplete" size="md" style={{ flex: 1 }}>mark incomplete</WFBtn>
          <WFBtn k="g3-done" primary size="md" style={{ flex: 1 }}>complete & leave →</WFBtn>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 100, right: -130 }}>
            manager-only · staff don't see this
          </WFNote>
          <WFNote style={{ top: 230, right: -130 }}>
            planted ≠ planned → returning qty surfaces stock impact
          </WFNote>
          <WFNote style={{ top: 460, right: -130 }}>
            on-site storage = tomorrow's starting inventory
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            crew shown as confirmed list · individual leave-times come from G5/G6
          </WFNote>
        </>
      }
    </>);

}

// G4 — End-of-shift summary
function ScreenG4({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="shift summary"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>Tue 12 Mar · 8:42 → 17:04 · 8h 22m</WFT>} />
      
      <WFBody style={{ gap: 10 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <WFStat k="g4-s1" value="3" label="jobs" />
          <WFStat k="g4-s2" value="100" label="km driven" />
          <WFStat k="g4-s3" value="7h" label="on-site" />
        </div>

        <WFSection title="today's stops" />
        <WFCard k="g4-1" accent={wfGreen}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>Greenwood Estate</WFT>
            <WFT size={11} color={wfGreen}>complete</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>9:02 → 11:18 · 22 km · 30 plants in</WFT>
        </WFCard>
        <WFCard k="g4-2" accent={wfGreen}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>Marshfield</WFT>
            <WFT size={11} color={wfGreen}>complete</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>11:54 → 13:20 · 13 km · plant out</WFT>
        </WFCard>
        <WFCard k="g4-3" accent={wfAccent}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={13} style={{ fontWeight: 600 }}>St Anne's</WFT>
            <WFT size={11} color={wfAccent}>partial</WFT>
          </div>
          <WFT size={11} color={wfInkSoft}>14:08 → 16:42 · 35 km · rain stopped play</WFT>
        </WFCard>

        <WFSection title="distance log" />
        <WFBox k="g4-mi" pad={10} radius={10} stroke={wfInkFaint}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={11} color={wfInkSoft}>start depot</WFT>
            <WFT size={12} style={{ fontWeight: 600 }}>48,210</WFT>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <WFT size={11} color={wfInkSoft}>end home</WFT>
            <WFT size={12} style={{ fontWeight: 600 }}>48,272</WFT>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4, paddingTop: 4, borderTop: `1px dashed ${wfInkFaint}` }}>
            <WFT size={11} style={{ fontWeight: 600 }}>total</WFT>
            <WFT size={12} style={{ fontWeight: 600 }}>100 km</WFT>
          </div>
        </WFBox>

        <WFSection title="needs review" />
        <WFRow
          title="St Anne's · incomplete"
          meta="reschedule? · customer notified?"
          density={density}
          right={<WFPill color={wfAccent}>open</WFPill>} />
        
        <WFRow
          title="Greenwood · 6 plants returning"
          meta="store at depot or use Wed?"
          density={density}
          right={<WFT size={11}>›</WFT>} />
        

        <WFBtn k="g4-end" primary size="lg" style={{ marginTop: 6 }}>
          end shift · submit →
        </WFBtn>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 140, right: -130 }}>
            3 KPIs above the fold · jobs / miles / hours
          </WFNote>
          <WFNote style={{ top: 370, right: -130 }}>
            distance rolled up · per-stop deltas tappable
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            'needs review' = soft handoff to admin
          </WFNote>
        </>
      }
    </>);

}



// G5 — Crew member leaving (staff perspective). One simple confirm. Creates
// a JobEvent attached only to this person, with start/end and their rate at
// time of leaving.
function ScreenG5({ pattern, persona, density, annotated }) {
  return (
    <>
      <WFTopBar
        title="leaving"
        left={<WFIcon label="✕" size={22} color={wfInkSoft} />}
        sub={<WFT size={11} color={wfInkSoft}>job stays open — rest of crew continues</WFT>} />
      
      <WFBody style={{ gap: 14, justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div>
            <WFT size={11} color={wfInkSoft}>you're at</WFT>
            <WFH size={24}>Greenwood Estate</WFH>
            <WFT size={11} color={wfInkSoft}>hedge trim · with Joe + Pete</WFT>
          </div>

          <WFBox k="g5-summary" pad={12} radius={12} thick>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <WFT size={11} color={wfInkSoft}>on site since</WFT>
              <WFT size={13}>9:02</WFT>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 4 }}>
              <WFT size={11} color={wfInkSoft}>now</WFT>
              <WFT size={13}>11:18</WFT>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 4, paddingTop: 6, borderTop: `1px dashed ${wfInkFaint}` }}>
              <WFT size={11} style={{ fontWeight: 600 }}>your trip</WFT>
              <WFH size={22}>2h 16m</WFH>
            </div>
          </WFBox>

          <WFBox k="g5-rate" pad={8} radius={8} stroke={wfInkFaint} style={{ background: wfSurface }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <WFT size={11} color={wfInkSoft}>your rate</WFT>
              <WFT size={11} style={{ fontWeight: 600 }}>£18 / hr</WFT>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 2 }}>
              <WFT size={11} color={wfInkSoft}>this trip</WFT>
              <WFT size={11} style={{ fontWeight: 600 }}>£40.80</WFT>
            </div>
          </WFBox>

          <WFT size={11} color={wfInkSoft} style={{ textAlign: 'center', lineHeight: 1.4 }}>
            this logs a JobEvent just for you · the job stays open · your manager
            handles what was done at close-out.
          </WFT>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <WFBtn k="g5-confirm" primary size="lg">yes, I'm leaving now ✓</WFBtn>
          <WFBtn k="g5-cancel" size="md">cancel</WFBtn>
        </div>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 160, right: -130 }}>
            staff side — one big confirm, nothing else
          </WFNote>
          <WFNote style={{ top: 320, right: -130 }}>
            rate locked at this moment · stored on the JobEvent
          </WFNote>
        </>
      }
    </>);

}

// G6 — Manager event entry: log a JobEvent for someone (arrived / left /
// break start / break end). Manager picks crew + type + time.
function ScreenG6({ pattern, persona, density, annotated }) {
  const eventTypes = ['arrived', 'left', 'break start', 'break end'];
  return (
    <>
      <WFTopBar
        title="log event"
        left={<WFIcon label="‹" size={22} color={wfInkSoft} />}
        right={<WFT size={12} color={wfAccent} style={{ fontWeight: 600 }}>save</WFT>}
        sub={<WFT size={11} color={wfInkSoft}>Greenwood Estate · in progress</WFT>} />
      
      <WFBody style={{ gap: 12 }}>
        <WFSection title="who" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <WFBox k="g6-c1" pad={8} radius={8} fill={wfSurface}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <WFT size={13} style={{ fontWeight: 600 }}>● Sam</WFT>
                <WFT size={11} color={wfInkSoft}>on site since 9:02 · £18/hr</WFT>
              </div>
              <WFT size={14}>✓</WFT>
            </div>
          </WFBox>
          <WFBox k="g6-c2" pad={8} radius={8}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <WFT size={13} style={{ fontWeight: 600 }}>● Joe</WFT>
                <WFT size={11} color={wfInkSoft}>on site since 9:02 · £16/hr</WFT>
              </div>
            </div>
          </WFBox>
          <WFBox k="g6-c3" pad={8} radius={8}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <WFT size={13} style={{ fontWeight: 600 }}>● Pete</WFT>
                <WFT size={11} color={wfInkSoft}>arrived 10:30 · £14/hr</WFT>
              </div>
            </div>
          </WFBox>
          <WFBox k="g6-c4" pad={8} radius={8} stroke={wfInkFaint} dashed>
            <WFT size={13} color={wfInkSoft}>+ add someone not on the roster</WFT>
          </WFBox>
        </div>

        <WFSection title="event" />
        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
          {eventTypes.map((t, i) =>
          <WFPill key={i} fill={i === 1 ? wfInk : 'transparent'} color={i === 1 ? wfPaper : wfInk}>
              {t}
            </WFPill>
          )}
        </div>

        <WFSection title="when" />
        <div style={{ display: 'flex', gap: 6 }}>
          <WFInput k="g6-time" value="11:05" placeholder="time" style={{ flex: 1 }} />
          <WFBtn k="g6-now" size="md">now</WFBtn>
          <WFBtn k="g6-back" size="md">5 min ago</WFBtn>
        </div>

        <WFBox k="g6-note" pad={8} radius={8} stroke={wfInkFaint} dashed style={{ background: wfSurface }}>
          <WFT size={11} color={wfInkSoft}>note (optional) — reason, who told you, etc.</WFT>
        </WFBox>

        <WFBox k="g6-effect" pad={8} radius={8} stroke={wfAccent}>
          <WFT size={11} color={wfAccent} style={{ fontWeight: 600 }}>will log:</WFT>
          <WFT size={12} color={wfInk}>Sam · left · 11:05 · rate locked £18/hr</WFT>
        </WFBox>
      </WFBody>
      {annotated &&
      <>
          <WFNote style={{ top: 140, right: -130 }}>
            manager picks crew member from current roster
          </WFNote>
          <WFNote style={{ top: 380, right: -130 }}>
            event type chips · same JobEvent model on both sides
          </WFNote>
          <WFNote style={{ bottom: 130, right: -130 }}>
            preview shows what's about to be written before save
          </WFNote>
        </>
      }
    </>);

}


function PhoneWrapped({ label, note, Screen, activeTab = 0, hideNav = false, tall = false, height = null, tweaks }) {
  const { pattern, persona, density, annotated } = tweaks;
  return (
    <WFPhone label={label} note={note} density={density} annotated={annotated} persona={persona} tall={tall} height={height}>
      <Screen pattern={pattern} persona={persona} density={density} annotated={annotated} />
      {!hideNav && <WFNavStrip pattern={pattern} active={activeTab} persona={persona} />}
    </WFPhone>);

}

Object.assign(window, {
  ScreenA1, ScreenA2, ScreenA3, ScreenA4,
  ScreenB1, ScreenB2, ScreenB3, ScreenB4,
  ScreenC1, ScreenC2, ScreenC3, ScreenC4,
  ScreenD1, ScreenD2, ScreenD3, ScreenD4, ScreenD5,
  ScreenE1, ScreenE2,
  ScreenF1, ScreenF2, ScreenF3,
  ScreenG1, ScreenG2, ScreenG3, ScreenG4, ScreenG5, ScreenG6,
  ScreenL1, ScreenL2, ScreenL3,
  ScreenH1, ScreenH2, ScreenH3,
  ScreenI1, ScreenI2,
  ScreenJ1, ScreenJ2, ScreenJ3,
  ScreenK1, ScreenK2,
  WFNavStrip, PhoneWrapped, TABS_FIELD, TABS_ADMIN, tabsFor
});