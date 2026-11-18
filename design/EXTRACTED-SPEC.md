# EXTRACTED-SPEC.md

## 1. Project Overview

**Product name:** Jeevanadhara\
**Tagline:** Better Farming • Brighter Future\
**Product type:** Smart farming and farmer-support web dashboard\
**Primary goal:** Give farmers one place to monitor weather, assess crop
health, find traders, track market prices, rent equipment, browse
agricultural resources, and access voice-based assistance.

## 2. Visual Design System

-   **Overall style:** Modern agricultural SaaS dashboard with a dark,
    premium interface.
-   **Primary palette:** Deep forest green, near-black teal, emerald
    green, and mint green.
-   **Accent colors:** Sky blue for weather, orange for warnings, red
    for negative price movement, purple for marketplace features, and
    magenta for support.
-   **Backgrounds:** Dark teal panels with subtle gradients; selected
    areas use photographic farmland, crops, and sunrise imagery.
-   **Components:** Rounded cards, thin colored borders, pill-shaped
    buttons, small status badges, circular score indicators, and compact
    data rows.
-   **Typography:** Clean sans-serif type with clear page headings,
    readable card titles, and compact supporting text.
-   **Layout:** Persistent left sidebar, top header with
    search/profile/notifications, and a responsive card-based main
    workspace.
-   **Imagery:** Realistic farm landscapes, farmers, crops, agricultural
    machinery, produce, and weather illustrations.
-   **Accessibility considerations:** Maintain strong text/background
    contrast, pair colors with icons or labels, provide visible focus
    states, and use descriptive labels for icon-only controls.

## 3. Global Application Shell

### Sidebar navigation

The left sidebar includes the Jeevanadhara logo and the following
destinations:

1.  Dashboard
2.  Trader Matching
3.  Crop Quality Analysis
4.  Weather & Alerts
5.  Price Forecast
6.  Tools Renting
7.  Marketplace
8.  ICAR Resources
9.  Voice Assistant
10. Profile

A Help & Support destination is also represented in the screen concepts.

### Global header

-   Page title and contextual greeting where appropriate.
-   Search control on inner screens.
-   Notification icon with unread-count badge.
-   User profile/avatar control.
-   Optional quick-access voice assistant control on the dashboard.
-   Active navigation item highlighted with a green background and icon.

### Shared interaction patterns

-   Card-based content groups with clear headings.
-   Primary actions shown as prominent rounded buttons.
-   Secondary actions shown as text links or outlined buttons.
-   Loading, empty, error, and success states should be designed for
    every data-driven section.
-   On narrow screens, collapse the sidebar into a menu and stack
    content cards vertically.

## 4. Screen Specifications

## 4.1 Dashboard

**Purpose:** Provide a high-level daily overview of the farmer's
activities and conditions.

### Header and greeting

-   Farm landscape hero banner.
-   Personalized greeting, e.g. "Good Morning, Ramesh!"
-   Short daily summary.
-   Quick voice interaction, notifications, and profile access.

### Weather summary

-   Current temperature and condition.
-   Location.
-   Today, tomorrow, and day-after forecast summaries.
-   Rain probability.
-   Action: **View 7-Day Forecast**.

### Weather alert card

-   High-priority alert with weather illustration.
-   Alert message and date.
-   Practical precaution text.
-   Action: **View Details**.

### AI Voice Assistant card

-   Assistant avatar and short introduction.
-   Microphone/voice waveform indicator.
-   Action: **Tap to Speak**.

### Recommended Traders

Show trader cards with: - Trader or business name. - Profile or farming
image. - Location and distance. - Price per kilogram. - Available
quantity. - Rating. - Best-match badge where applicable. - Actions:
**View All** and **View More Traders**.

### Crop Quality Analysis preview

-   Crop photograph with visual detection overlay.
-   Health label such as **Healthy**.
-   Quality score shown as a circular progress indicator.
-   Summary indicators for health, disease, cleanliness, and grade.
-   Action: **View Report**.

### Live Crop Price Forecast

Show produce rows with: - Crop name and thumbnail. - Current price per
kilogram. - Positive or negative percentage movement. - Short trend
summary. - Action: **View All**.

### Explore More Services

Service cards for: - Tools Renting - Marketplace - ICAR Resources - Crop
Calendar - Help & Support

Each card includes an icon, brief description, and relevant call to
action.

### Promotional card

-   Farming-themed image.
-   Headline: "Grow More With Confidence".
-   Supporting copy about smarter tools, better decisions, and higher
    yields.
-   Action: **Let's Grow**.

## 4.2 Weather & Alerts

**Purpose:** Help farmers understand current and upcoming weather and
respond to risks.

### Current weather panel

-   Current temperature and weather condition.
-   Location.
-   Forecast summaries for today, tomorrow, and the day after.
-   Rain probabilities.
-   Action: **View 7-Day Forecast**.

### Seven-day forecast table

Suggested columns: - Date - Temperature - Condition - Rain probability

Use weather icons and readable values for each day.

### Active alerts

Display alert cards with: - Severity indicator. - Alert title. - Date or
expected time window. - Short description and recommended precautions. -
Action: **View Details**.

The design may distinguish high-severity alerts from informational tips,
without relying on color alone.

### Weather-based farming tips

-   Contextual recommendations based on forecast conditions.
-   Action: **View Tips**.

## 4.3 Trader Matching

**Purpose:** Help farmers compare potential buyers and contact suitable
traders.

### Search and filters

-   Search by location or trader name.
-   Search action.
-   Filter control.
-   Tabs or views for **Nearby Traders** and **Top Rated**.

### Trader results

Each result should include: - Trader name and avatar/image. - Rating. -
Location and distance. - Offered price per kilogram. - Available
quantity. - Contact action.

### Why Choose Us panel

Highlight trust factors such as: - Verified traders. - Best market
prices. - Secure transactions. - Wide variety.

### Supporting promotional content

A small farmer-focused information card may promote local farmer support
or the value of comparing traders.

## 4.4 Crop Quality Analysis

**Purpose:** Assess an uploaded crop image and present an understandable
quality report.

### Input and analysis

-   **Upload Image** control.
-   **Live Analysis** option, if camera support is implemented.
-   Preview of the selected crop image.
-   Detection overlay or bounding box when supported.

### Results

-   Quality score, illustrated with a circular gauge.
-   Overall label such as **Healthy**.
-   Health status.
-   Disease status.
-   Cleanliness status.
-   Grade.

### Analysis report

Include relevant metadata such as crop type, analysis date, and
confidence when these values are available from the actual analysis
system.

### Actions

-   **Download Report**
-   Option to upload another image or run another analysis.

**Important:** Scores and classifications must come from the analysis
result; do not hard-code the example score of 92% as a real prediction.

## 4.5 Live Crop Price Forecast

**Purpose:** Help farmers compare current prices and understand possible
price movements.

### Controls

-   Crop selector.
-   Location selector.
-   Time-range filters such as 7 Days, 30 Days, 3 Months, and 6 Months.

### Price chart

-   Time-series line chart.
-   Date labels on the horizontal axis.
-   Price per kilogram on the vertical axis.
-   Current or latest price summary.
-   Expected trend summary.

### Market insights

-   Short notes about demand, seasonal factors, or market conditions
    when supported by data.
-   Clear distinction between observed prices and predicted prices.

**Important:** Label predictions as estimates and display the data
source and last-updated time where available.

## 4.6 Tools Renting

**Purpose:** Let farmers find and book agricultural equipment.

### Categories

-   All Tools
-   Tractors
-   Harvesters
-   Irrigation
-   Other equipment

### Equipment cards

Each card should include: - Equipment photograph. - Equipment name. -
Rental rate and unit, such as per day. - Location or distance. -
Availability information. - **Book Now** action.

### Why Rent panel

Potential benefits: - Cost effective. - Well maintained. - Verified
owners. - Easy booking.

### Promotional banner

A short message encouraging farmers to rent the right tools for their
needs.

## 4.7 Marketplace

**Purpose:** Provide a searchable catalogue of farming supplies.

### Search and filters

-   Search field for seeds, fertilizers, and other products.
-   Search action.
-   Category filters such as All, Seeds, Fertilizers, Pesticides, and
    Equipment.
-   Cart shortcut.

### Product cards

Each product card should include: - Product image. - Product name. -
Price and unit. - Rating where available. - **Add to Cart** action.

### Product details

A full product view should provide description, seller,
stock/availability, pricing, and applicable delivery details.

**Important:** Use real catalogue data for prices, ratings, and
availability; example values in the visual are placeholders.

## 4.8 ICAR Resources

**Purpose:** Provide access to credible agricultural learning materials.

### Resource navigation

-   Guides & Articles
-   Videos
-   Schemes

### Resource cards

Each card should include: - Thumbnail or illustration. - Resource
title. - Short description. - Relevant category. - **Read More** action.

### Example topic areas

-   Organic farming practices.
-   Soil health management.
-   Crop disease management.
-   Government schemes and farmer support.

### ICAR identity panel

A visual panel may reinforce the agricultural knowledge and research
theme. Use official logos only when permitted and available.

## 4.9 Voice Assistant

**Purpose:** Give farmers a simple voice-first way to ask farming
questions.

### Main interaction

-   Assistant avatar.
-   Welcome message.
-   Brief explanation of supported topics.
-   Large **Tap to Speak** button.
-   Microphone and waveform visual feedback.

### Suggested quick prompts

-   "What's the weather today?"
-   "Best price for tomato?"
-   "Crop care tips"

### Interaction states

-   Ready to listen.
-   Listening.
-   Processing.
-   Response available.
-   Microphone permission denied.
-   Network or service error.

Show a text transcript and a readable assistant response alongside voice
interaction. Ask permission before using the microphone.

## 4.10 Profile

**Purpose:** Let the farmer view and manage personal and farm details.

### Profile summary

-   Profile photograph/avatar.
-   Farmer name.
-   Location.
-   Edit-profile action.

### Personal information

Suggested fields: - Name - Phone - Email - Location - Farm size - Crops
grown

### Account controls

-   **Edit Profile**
-   **Change Password**

### Farm summary

Small metric cards may show: - Total land - Number of crops - Active
traders

These values must reflect the user's actual saved data.

## 4.11 Help & Support

**Purpose:** Help users resolve common issues and contact support.

### FAQ section

Use expandable questions covering topics such as: - Getting started. -
Weather and alerts. - Trader matching. - Crop quality analysis. -
Contacting support.

### Contact Us panel

Provide configured support channels such as: - Phone - Email - Live chat
or support messaging

Only publish verified contact information.

### Support message form

Suggested fields: - Name - Contact details - Issue category - Message -
Submit action

Show submission success or failure feedback and avoid displaying private
contact details unnecessarily.

## 5. Suggested Reusable Components

-   `AppShell`
-   `SidebarNavigation`
-   `TopHeader`
-   `PageTitle`
-   `SearchBar`
-   `NotificationButton`
-   `WeatherSummaryCard`
-   `WeatherAlertCard`
-   `TraderCard`
-   `CropQualityScore`
-   `StatusIndicator`
-   `PriceTrendCard`
-   `PriceLineChart`
-   `EquipmentCard`
-   `ProductCard`
-   `ResourceCard`
-   `VoiceAssistantPanel`
-   `ProfileInformationCard`
-   `EmptyState`
-   `LoadingState`
-   `ErrorState`
-   `ConfirmationDialog`
-   `ToastNotification`

## 6. Functional Requirements

1.  Sidebar navigation must open the corresponding screen and indicate
    the active destination.
2.  Search and filter controls must update their respective results.
3.  Trader cards must expose a working contact flow.
4.  Crop image upload must validate file type and size and show
    upload/analysis status.
5.  Crop analysis must display actual returned results and handle
    failures gracefully.
6.  Weather screens must display sourced weather data and timestamps.
7.  Price charts must distinguish historical values from forecasts.
8.  Equipment booking must show availability and booking confirmation.
9.  Marketplace cart actions must update cart state and show feedback.
10. Resource links must open valid resource details or external sources.
11. Voice interaction must request microphone permission and expose text
    alternatives.
12. Profile edits must validate input and persist only after successful
    submission.
13. Support forms must validate required fields and confirm successful
    submission.
14. All data-driven screens must support loading, empty, error, and
    success states.

## 7. Responsive Behaviour

-   **Desktop:** Persistent sidebar with multi-column dashboard cards.
-   **Tablet:** Narrower sidebar and reduced grid columns.
-   **Mobile:** Collapsible navigation, single-column cards, stacked
    forms, and full-width primary actions.
-   Keep charts readable on small screens and allow tables to scroll
    horizontally when necessary.
-   Preserve essential alerts, prices, and crop-quality results when
    content is rearranged.

## 8. Data and Integration Notes

The reference visuals contain illustrative farmer names, weather values,
trader offers, crop scores, prices, and alert messages. Treat these as
**mock/example content**, not verified live information.

Potential integrations, depending on implementation scope: - Weather
service for current conditions and forecasts. - Backend/API for users,
profiles, traders, and bookings. - Crop-analysis model or service. -
Market-price data provider. - Product catalogue and cart service. -
Agricultural resource links. - Speech-to-text and text-to-speech
services. - Notification and support services.

Keep API credentials on the server, validate all user input, and provide
clear messages when an integration is unavailable.

## 9. Acceptance Checklist

-   [ ] The application has consistent Jeevanadhara branding.
-   [ ] All listed screens are reachable from navigation.
-   [ ] The dashboard provides an overview of weather, alerts, traders,
    crop quality, prices, and services.
-   [ ] Weather alerts are visually distinct and include actionable
    details.
-   [ ] Trader results include price, location, availability, and
    contact options.
-   [ ] Crop quality results are based on real analysis output.
-   [ ] Price charts identify units, date ranges, and forecast status.
-   [ ] Equipment rental and marketplace actions provide clear feedback.
-   [ ] ICAR resources open useful, valid content.
-   [ ] Voice Assistant offers accessible text-based alternatives.
-   [ ] Profile and support forms validate and handle errors.
-   [ ] Layout adapts to desktop, tablet, and mobile.
-   [ ] Mock data is clearly separated from live data.
-   [ ] Interactive controls have accessible labels, keyboard support,
    and visible focus states.

## 10. Source Reference

This specification was extracted from the supplied Jeevanadhara
dashboard and multi-screen UI concept images. It documents visible
design patterns and inferred screen behaviour; implementation details
and backend integrations must be confirmed against the actual project
code.
