---
name: frontend
description: Frontend design engineering guidelines based on the opencode frontend agent (Linear-inspired UI aesthetic, strict UI gotchas, animation rules, and a build→polish→test workflow). Use when building or reviewing UI components, layouts, interactions, animations, or Next.js/React frontend implementation work.
---

# Frontend

## Use

Apply a consistent set of UI/UX constraints for frontend work:

- Linear-inspired aesthetic (minimal, muted, subtle depth, crisp type, tight spacing)
- Accessibility and real-bug UI gotchas (iOS zoom, truncation, reduced motion, etc.)
- Purposeful animation defaults (timing + properties)
- Practical workflow: understand → plan → implement → polish → test

If you need the original opencode agent text as a source of truth, open `references/opencode-agent-frontend.md`.

## Design Language (Default)

Follow a Linear-inspired design language unless the user explicitly instructs otherwise:

- Minimal and focused; remove non-essential UI
- Subtle depth: thin borders, soft shadows, layered surfaces
- Muted palette: grays/off-whites with sparse accent colors
- Tight spacing: compact but breathable
- Crisp typography and hierarchy; prefer `font-variant-numeric: tabular-nums` for numbers
- Keyboard-first: shortcuts visible, command palette patterns where relevant
- Instant feedback: micro-animations and optimistic UI where safe
- Dark-mode aware (design should not break in dark mode)

## Critical UI Rules

These are implementation rules that prevent real-world bugs:

- Input font size: ensure `<input>` font-size is `>= 16px` (prevents iOS zoom)
- Touch: use `touch-action: manipulation` on tappable controls (reduces double-tap zoom issues)
- Flex truncation: ensure flex children that must truncate have `min-w-0`
- Numbers: use `font-variant-numeric: tabular-nums` for aligned comparisons
- Reduced motion: honor `prefers-reduced-motion`

Avoid:

- Animating layout: never animate `width`, `height`, `top`, `left`; animate `transform`/`opacity`
- `transition: all`; list properties explicitly
- Hardcoded colors for theming; use design tokens
- Inline styles for reusable patterns
- Undersized touch targets; aim for at least 44x44px interactive area

## Animation Defaults

- Exits faster than entrances (about 150ms out, 200-300ms in)
- Use `ease-out` for entrances; `ease-in` for exits
- Stagger list children by ~30-50ms
- Keep total animation under ~400ms

## Workflow

1. Understand user goals and constraints (existing design system, component API, a11y needs).
2. Pull in relevant companion skills if available:
   - `web-animation-design` for motion details
   - `emil-design-engineering` for UI polish, forms, touch, a11y
   - `vercel-composition-patterns` for scalable component APIs
   - `next-best-practices` for Next.js App Router/RSC patterns
   - `copywriting` for marketing copy, headlines, CTAs
   - `agent-browser` for browser automation and interaction testing
3. Plan component structure and composition patterns.
4. Implement with accessibility and performance in mind.
5. Polish: transitions, micro-interactions, focus states, and dark mode.
6. Test across viewports and interaction modes (keyboard + touch).
