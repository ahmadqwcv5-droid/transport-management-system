# Concept C — Field Ledger / سجل الميدان

**Identity:** editorial, orderly, tactile, transparent, durable.

Field Ledger translates the physical dispatch book into a modern operational
system. Numbered rows, strong rules, and restrained paper surfaces make dense
facts easy to audit without resembling a generic card dashboard. The
code-native mark is an abstract ledger with a route column.

## Palette and type

| Role | Name | Hex |
|---|---|---|
| Canvas | Dispatch stock | `#F0EEE6` |
| Surface | Ledger leaf | `#FBFAF5` |
| Strong surface | Filed paper | `#E7E4D9` |
| Ink | Forest ink | `#1E2C27` |
| Muted | Pencil grey | `#657069` |
| Rule | Register line | `#C8C7BC` |
| Primary | Registry green | `#245B49` |
| Secondary | Carbon blue | `#476B87` |
| Warning | Brass marker | `#C39A3C` |
| Danger | Oxide red | `#B64A36` |
| Success | Stamp green | `#397650` |

- Arabic: bundled Noto Sans Arabic, with generous line height for long labels.
- Latin: bundled Noto Sans; numbered labels create hierarchy without a second
  display font.

## Interaction language

- Wide numbered sidebar and section rules instead of a floating icon rail.
- Square ledger surfaces, compact rows, and a deliberate movement manifest.
- Tables/lists are the primary grammar; cards are used only for grouped tasks.
- Map is framed like one operational sheet inside the larger record.
- Forms use explicit labels and strong baseline/focus rules.
- Motion: 180 ms row selection, 260 ms progress settlement, and 120–180 ms
  stamped notification entry. Reduced motion commits the new row immediately.
- Mobile becomes a custody/work-order card with numbered facts and one action.

## Evidence

- [Dashboard Arabic 1440](concept_c_dashboard_1440_ar.png)
- [Dashboard English 1440](concept_c_dashboard_1440_en.png)
- [Driver Today Arabic 390](concept_c_driver_today_390_ar.png)
- [Driver My Truck Arabic 390](concept_c_driver_truck_390_ar.png)
- [Components and motion](concept_c_components_motion_ar.png)
- [Reduced motion](concept_c_components_reduced_motion_ar.png)
- [Tablet Arabic 768](concept_c_dashboard_768_ar.png)
- [Narrow Arabic 360](concept_c_dashboard_360_ar.png)

## Accessibility and implementation risk

Rules, numbering, labels, and icons make state independent of color. Light
paper surfaces maintain strong text contrast. Risk is **medium**: the dense
editorial system is flexible for lists and reports, but long English labels and
complex dialogs need disciplined responsive truncation and line wrapping.
