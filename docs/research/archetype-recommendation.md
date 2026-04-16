# Archetype Recommendation

## Pick: Timeline-explorer with side-by-side A/B (+ GitHub) panes

## Why

The story Dolt tells is intrinsically **multi-actor and time-ordered**: two
clones tick forward independently, a GitHub ref in the middle advances
whenever either side pushes, and the key moments (diff preview, fast-forward
pull, merge commit, conflict table) are specific points on that timeline.

The four explainer moments that **must** land:

1. "The GitHub repo looks empty — but isn't." You need a GitHub pane to
   show `refs/heads/main` frozen at README while `refs/dolt/data`
   advances. A narrative-chapters format can't show that liveness.
2. "Row-level diff." The diff preview with `<` / `>` / `+` markers is a
   static table, perfect for a timeline step.
3. "Non-fast-forward rejection, then pull-and-merge." This is a
   causal relationship between two timelines — clone B pushes, clone A's
   push is rejected. Only side-by-side shows the causality.
4. "Conflict as a SQL table." The `base | ours | theirs` three-column
   visual is the explainer's money shot. Timeline positioning lets it
   land at the right narrative moment, after the divergence is set up.

## Why not the alternatives

- **Narrative chapters** (prose + occasional figures): too linear to
  represent two repos evolving in parallel. The reader loses track of
  which clone holds which state.
- **Side-by-side comparison** (git vs dolt, static): captures the
  vocabulary mapping (`git commit` ↔ `dolt commit`) but misses the
  distributed-workflow narrative entirely. Works as a **secondary**
  reference panel, not the spine.
- **Tracker** (dashboard of current states): nothing to track over
  time for a read-once explainer. Better suited to a running system.

## Concrete shape

Three columns down the page: **Clone A** / **GitHub (refs)** / **Clone B**.
Rows are timeline steps. Each cell shows the relevant state (current HEAD,
a snippet of output, the table contents after the step). A scrubber or
step-button advances the whole timeline. The `dolt conflicts cat` moment
gets a full-width expand that overlays all three columns for emphasis.

Budget this as a ~7-step timeline: init → commit → push → clone →
concurrent-edits (split timeline) → conflict → resolve.
