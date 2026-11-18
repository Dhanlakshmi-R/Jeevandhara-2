# extracted_admin.md

## 1. Project Overview

**Product:** Jeevanadhara Admin Portal  
**Tagline:** Better Farming • Brighter Future  
**Purpose:** A separate, role-protected workspace for authorized administrators to monitor platform activity across new and existing users, manage accounts, review alerts and analytics, oversee market information, generate reports, and protect the system.

> **Mockup data:** All names, metrics, dates, locations, weather values, prices, and alerts shown in the reference image are illustrative placeholders, not live or verified data.

## 2. Visual Design System

- **Style:** Modern, premium agricultural SaaS administration dashboard.
- **Palette:** Deep forest green, near-black teal, emerald, and mint; blue for information, amber for warnings, red for critical states, and neutral tones for inactive states.
- **Surfaces:** Dark panels, thin teal/green borders, rounded cards, restrained gradients, and compact data visualizations.
- **Typography:** Clean sans-serif; clear page titles and readable tables.
- **Charts:** Label axes, units, legends, date ranges, and data freshness.
- **Imagery:** Subtle agricultural landscape accents; prioritize legibility on data-heavy pages.
- **Accessibility:** Pair status colors with text/icons, provide keyboard focus states, and label icon-only controls.

## 3. Shared Application Shell

### Navigation
1. Admin Dashboard
2. User Management
3. Activity Logs
4. Weather & Alerts
5. Crop Analytics
6. Price Forecast / Market Insights
7. Reports
8. Settings
9. Notifications
10. Profile & Security

### Shared header
- Page title and optional breadcrumbs.
- Search where relevant.
- Notification icon and unread count.
- Administrator avatar/account menu.
- Date-range selector and last-updated timestamp on data views.

### Shared interaction patterns
- Search, filters, sorting, pagination, and authorized export.
- Loading, empty, error, stale-data, and success states.
- Confirmation dialogs for high-impact actions.
- Server-side authorization for every protected operation; hiding a button is not sufficient.

## 4. Screen Specifications

## 4.1 Admin Dashboard — Overview

**Purpose:** Summarize platform health and highlight activity requiring attention.

- KPI cards: total users, new users in the selected period, active users, and total activities.
- User-growth chart comparing new and active users over time.
- User distribution by role: farmers, traders, agricultural assistants, and other configured roles.
- Recent activity table with timestamp, user, action, details, and link to the relevant record.
- Quick links to user management, activity logs, active alerts, and reports.
- Date-range selector and last-refresh time.

All totals and charts should use actual backend data and clearly reflect the selected period.

## 4.2 User Management

**Purpose:** Find and manage new and existing accounts.

- Search by name, user ID, or permitted contact fields.
- Filters for role, status, verification, registration date, and location.
- Tabs/filters for all users, farmers, traders, agricultural assistants, and other roles.
- Table columns: user ID, name, role, location, joined date, status, and actions.
- Authorized actions: view details, edit permitted fields, activate/suspend, review verification, or initiate account recovery.
- Add-user flow if account creation is part of the approved admin workflow.
- Confirm high-impact actions and record a reason where appropriate.

Prefer reversible deactivation/soft deletion over irreversible deletion when possible.

## 4.3 User Details & Activity Logs

**Purpose:** Review one account and its platform history.

- User summary: name, ID, role, account status, registration date, and relevant profile details.
- Activity table/timeline: timestamp, category, action, resource, outcome, and relevant metadata.
- Categories may include login/logout, profile updates, weather views, crop analysis, market views, marketplace activity, rental bookings, and support requests.
- Filters for date range, activity category, outcome, and resource.
- Account summary: last login and activity counts where available.

**Privacy:** Never show passwords, authentication tokens, recovery secrets, or unnecessary sensitive data. Mask contact details when full values are not needed. Restrict sensitive history to authorized roles and log administrator access to sensitive records.

## 4.4 Weather & Alerts Management

- Current conditions by selected location, with source and last-updated time.
- Forecast table with date, temperature, condition, and rainfall probability.
- Active alerts showing severity, affected region, issue time, expiry, message, and status.
- Alert states: Draft, Scheduled, Active, Expired, and Resolved.
- Authorized actions: create, edit, publish, expire, and resolve.
- Alert statistics by severity, region, and delivery status where available.
- Weather-based farming tips.

Clearly distinguish official warnings from general recommendations. Confirm broad alert publication and audit who changed or published each alert.

## 4.5 Crop Analytics & Reports

- Filters for crop, region, date range, analysis status, and quality category.
- Summary charts for quality distribution and analysis usage.
- Top crops by a clearly labelled metric, such as analysis volume.
- Report actions for crop-health summaries and trends.
- Individual analysis details only for authorized administrators.
- Show analysis timestamp, model/version, and confidence where available.

Do not hard-code sample quality scores as real results. Explain model uncertainty where relevant.

## 4.6 Market & Price Management

- Views for Market Prices and Price Forecast.
- Table fields: crop, market/location, price and unit, change, trend, source, and last-updated time.
- Filters for crop, location, and period.
- Historical price chart and visually distinct forecast values/ranges.
- Authorized workflows to review, flag, submit, or approve price updates if supported.
- Retain source attribution and change history.

Forecasts are estimates, not guaranteed prices. Never silently overwrite historical records.

## 4.7 Reports & Analytics

- Filters for report type, date range, region, role, and output format.
- Suggested reports: user activity, weather and alerts, crop analytics, transactions (if supported), system usage, and administrative audit history.
- Workflow: choose scope, preview fields, generate, show status, then view/download if authorized.
- Minimize personal data in exports.
- Log generation and download of sensitive reports.

## 4.8 Settings

Suggested groups:
- General settings and branding.
- Language, timezone, and support contacts.
- Data management and retention.
- Security policies and session settings.
- Roles and permissions.
- API/integration status.
- Backup and recovery.

Validate changes before saving, show clear success/failure feedback, and maintain a history of important changes. Never expose API secrets in the browser; store them securely server-side.

## 4.9 Notifications & Alerts

- Categories: All, System, User, Weather, Market, and Security.
- List fields: timestamp, category, summary, related record, severity, read state, and delivery/resolution status where supported.
- Actions: mark as read, open related record, search/filter, and resolve/dismiss when authorized.
- Dismissing an inbox notification must not erase a security audit event.

## 4.10 Profile & Security

- Administrator name, avatar, ID, role, and permitted contact details.
- Edit-profile action.
- Change password.
- Multi-factor authentication status/setup.
- Active sessions and sign-out-other-sessions controls where supported.
- Recent sign-in history and recovery options.
- Re-authentication for high-risk changes and audit records for sensitive actions.

Never display passwords or recovery secrets.

## 5. Recommended Roles and Permissions

| Role | Suggested access |
|---|---|
| Super Admin | Platform configuration, role management, and all approved admin areas |
| User Support Admin | User search, permitted profile details, and support workflows |
| Agriculture Content Admin | Agricultural resources and approved crop content |
| Weather Admin | Weather feeds and alert lifecycle |
| Market Data Admin | Market data review and approved price updates |
| Analyst / Auditor | Aggregate analytics, reports, and audit logs; no routine account changes |
| Read-only Admin | View assigned dashboards and records |

Use role-based access control and least privilege. Separate permissions for role changes, personal-data exports, account deletion, and broad alert publication. Avoid shared admin accounts.

## 6. Activity Monitoring and Audit Trail

Where appropriate, record:
- Unique event ID and timestamp/timezone.
- Actor/user ID.
- Event category and action.
- Target resource ID.
- Outcome and error category.
- Request/correlation ID.
- Limited source/session metadata when operationally justified.

Audit administrator actions such as permission changes, account status changes, alert publication, settings edits, and sensitive exports. Make logs append-only or tamper-evident, restrict access, define retention periods, and avoid collecting unnecessary personal data.

## 7. Suggested Reusable Components

- `AdminAppShell`, `AdminSidebar`, `AdminHeader`
- `MetricCard`, `DateRangePicker`, `SearchFilterBar`
- `DataTable`, `StatusBadge`, `ActivityTimeline`
- `UserDetailPanel`, `ChartCard`, `WeatherAlertCard`
- `ReportBuilder`, `NotificationList`, `PermissionMatrix`
- `ConfirmationDialog`, `ToastMessage`
- `LoadingState`, `EmptyState`, `ErrorState`

## 8. Functional Requirements

1. Require authentication and enforce role-based authorization on the server.
2. Support user search, filtering, pagination, and permitted account actions.
3. Show the correct account's activity history.
4. Filter activity by date, user, category, and outcome.
5. Record administrative actions in an audit trail.
6. Confirm high-impact actions and record actor, time, and reason where appropriate.
7. Manage weather alerts through clear lifecycle states.
8. Distinguish aggregate crop trends from individual analysis predictions.
9. Show market data units, sources, timestamps, and forecast labels.
10. Enforce permissions and privacy rules for reports and exports.
11. Validate settings changes and protect integration secrets.
12. Link notifications to relevant records where possible.
13. Provide secure admin account and session controls.
14. Handle loading, empty, error, and stale-data states on every data-driven screen.

## 9. Responsive Behaviour and Accessibility

- **Desktop:** Full sidebar, wide tables, multi-column charts.
- **Tablet:** Narrow/collapsible sidebar and fewer cards per row.
- **Mobile:** Collapsible navigation, stacked metrics, filter drawer, and horizontally scrollable tables where necessary.
- Keep critical alerts and security notices prominent.
- Support keyboard navigation, visible focus, accessible button names, readable contrast, labelled form fields, and text summaries for important charts.

## 10. Acceptance Checklist

- [ ] Admin accounts are separate from ordinary farmer/trader accounts.
- [ ] Backend authorization protects every admin operation.
- [ ] Dashboard metrics use actual data and a visible date range.
- [ ] User management supports search, filters, status, and authorized actions.
- [ ] User details show the correct activity history.
- [ ] Sensitive user information is restricted or masked.
- [ ] Admin actions are recorded in an audit trail.
- [ ] Weather alerts show severity, source, status, and timestamps.
- [ ] Crop analytics distinguish real results from mock values.
- [ ] Market views show units, source, freshness, and forecast status.
- [ ] Reports respect permissions and audit sensitive exports.
- [ ] Settings validate changes and protect secrets.
- [ ] Notifications link to the correct records.
- [ ] Profile includes appropriate security controls.
- [ ] Screens support loading, empty, error, and success states.
- [ ] Layout works on desktop, tablet, and mobile.
- [ ] UI is keyboard accessible and uses readable contrast.

## 11. Source Reference

This specification is based on the Jeevanadhara administrator UI concept image in the conversation. It documents visible screen concepts plus practical implementation recommendations. Confirm exact backend behaviour, integrations, policies, and permissions during implementation.
