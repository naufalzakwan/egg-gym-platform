<style>
    .eq-editor { width: min(100%, 1180px); margin: 0 auto; }
    .eq-editor .eq-card { padding: 20px; border: 1px solid rgba(107,114,128,.28); border-radius: 14px; background: linear-gradient(145deg, var(--panel), rgba(32,31,31,.88)); box-shadow: var(--shadow-card); }
    .eq-editor .eq-card__head { display: flex; align-items: flex-start; gap: 12px; margin-bottom: 18px; }
    .eq-editor .eq-card__icon { display: grid; place-items: center; width: 34px; height: 34px; flex: 0 0 34px; border: 1px solid rgba(250,204,21,.22); border-radius: 9px; background: rgba(250,204,21,.07); color: var(--accent); }
    .eq-editor .eq-card__icon svg { width: 17px; height: 17px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
    .eq-editor .eq-card__title { color: var(--text); font-size: 15px; line-height: 1.2; }
    .eq-editor .eq-card__sub { color: #8993a4; font-size: 11px; }
    .eq-editor .eq-field, .eq-editor .field { gap: 6px; }
    .eq-editor .eq-field label, .eq-editor .field label { color: var(--text-secondary); font-size: 11px; letter-spacing: .15px; }
    .eq-editor input:not([type="checkbox"]):not([type="hidden"]), .eq-editor select { min-height: 42px; padding: 9px 12px; border-radius: 8px; border-color: rgba(107,114,128,.32); background: #292929; }
    .eq-editor textarea { padding: 11px 12px; border-radius: 8px; border-color: rgba(107,114,128,.32); background: #292929; }
    .eq-editor input:focus, .eq-editor select:focus, .eq-editor textarea:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(250,204,21,.09); }
    .eq-editor .eq-help, .eq-editor .help { color: #7d8797; font-size: 10px; line-height: 1.45; }
    .eq-editor .eq-guide-grid { grid-template-areas: "benefits flow" "safety safety"; align-items: start; }
    .eq-editor .eq-list { padding: 14px; border: 1px solid rgba(107,114,128,.25); border-radius: 10px; background: rgba(19,19,19,.42); }
    .eq-editor .eq-list[data-list-name="key_benefits_text"] { grid-area: benefits; }
    .eq-editor .eq-list[data-list-name="usage_flow_text"] { grid-area: flow; }
    .eq-editor .eq-list[data-list-name="safety_notes_text"] { grid-area: safety; }
    .eq-editor .eq-list > label { font-size: 12px; }
    .eq-editor .eq-list__row { grid-template-columns: 24px minmax(0,1fr) 32px; gap: 7px; }
    .eq-editor .eq-list__number { width: 24px; height: 24px; font-size: 10px; }
    .eq-editor .eq-list__row input { min-height: 38px !important; padding: 8px 10px !important; }
    .eq-editor .eq-list__remove { display: grid; place-items: center; width: 32px; height: 32px; padding: 0; font-size: 0; }
    .eq-editor .eq-list__remove::before { content: ''; width: 13px; height: 14px; background: currentColor; clip-path: polygon(18% 15%,32% 15%,38% 0,62% 0,68% 15%,82% 15%,82% 25%,76% 25%,72% 100%,28% 100%,24% 25%,18% 25%); }
    .eq-editor .eq-list__add { min-height: 34px; padding: 7px 10px; font-size: 11px; }
    .eq-editor .eq-movement__rows { display: grid; gap: 10px; margin-bottom: 10px; }
    .eq-editor .eq-movement__row { display: grid; grid-template-columns: 28px minmax(0,1fr) minmax(0,1fr) 34px; gap: 10px; align-items: end; padding: 12px; border: 1px solid rgba(107,114,128,.25); border-radius: 10px; background: rgba(19,19,19,.42); }
    .eq-editor .eq-movement__row .eq-list__number { align-self: center; }
    .eq-editor .eq-movement__remove { margin-bottom: 5px; }
    .eq-editor .eq-upload { grid-template-columns: minmax(280px, 1.05fr) minmax(260px, .95fr); align-items: stretch; }
    .eq-editor .eq-upload__preview { width: 100%; max-width: 520px; aspect-ratio: 16/9; }
    .eq-editor .eq-upload__details { display: grid; gap: 10px; padding: 14px; border: 1px solid rgba(107,114,128,.25); border-radius: 10px; background: rgba(19,19,19,.35); align-content: center; }
    .eq-editor .eq-file-meta { display: grid; grid-template-columns: 82px 1fr; gap: 6px 10px; font-size: 11px; }
    .eq-editor .eq-file-meta dt { color: #7d8797; }
    .eq-editor .eq-file-meta dd { margin: 0; color: var(--text-secondary); overflow-wrap: anywhere; }
    .eq-editor .eq-toggle-row { min-height: 58px; padding: 11px 14px; }
    .eq-editor .eq-form__footer { position: sticky; bottom: 12px; z-index: 20; padding: 10px; border: 1px solid rgba(107,114,128,.3); border-radius: 11px; background: rgba(24,24,24,.94); backdrop-filter: blur(8px); box-shadow: 0 8px 24px rgba(0,0,0,.34); }
    .eq-description-wrap { position: relative; }
    .eq-character-count { position: absolute; right: 10px; bottom: 8px; color: #737d8c; font-size: 10px; pointer-events: none; }
    @media (max-width: 760px) {
        .eq-editor { width: 100%; }
        .eq-editor .eq-card { padding: 16px; }
        .eq-editor .eq-guide-grid { grid-template-columns: 1fr; grid-template-areas: "benefits" "safety" "flow"; }
        .eq-editor .eq-upload { grid-template-columns: 1fr; }
        .eq-editor .eq-upload__preview { max-width: none; }
        .eq-editor .eq-list__row { grid-template-columns: 24px minmax(0,1fr) 34px; }
        .eq-editor .eq-movement__row { grid-template-columns: 28px minmax(0,1fr) 34px; align-items: center; }
        .eq-editor .eq-movement__row .eq-field { grid-column: 2; }
        .eq-editor .eq-movement__remove { grid-column: 3; grid-row: 1 / span 2; margin-bottom: 0; }
        .eq-editor .eq-form__footer { bottom: 6px; }
        .eq-editor .eq-form__footer .btn { flex: 1; }
    }
</style>
