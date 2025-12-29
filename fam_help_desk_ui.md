# Fam Help Desk UI

The following breaks down how I am invisioning the UI for Fam Help Desk to look. This doc lays out the UI for both the IOS App and the Website. Endless said otherwise the following will say what both the app and webiste will do

## Unauthenticated Home

When not authenticated the logo of Fam Help Desk will appear with a log in screen. The user will have the option to either sign in or create an account. The user will have the option to create their own user name and password or use Google to authenticate.

Once the app is fully built out the unathenticate home will give a description of what the app is for with some screenshots

## Authenticated Home

The user's homepage will show all the Families the user is a member of. Each faimly will have a quick link to the faimiles home page


## Family Home

Each family is a stand alone ticket system. Families have different groups that a user can be a member of. Each group will have at least one queue where their tickets will show up in. 

The family home page will by default show all tickets still open for the family.

### iOS App
* Each ticket will be it's own card in a list
* The list card will show the title, the status, requestor, assigned group, and assigned user
* The user can then click on a ticket to view more info on the ticket

#### iOS Filtering & Sorting Approach

The iOS app will have filtering and sorting built right into the top nav bar. Users will see a filter button (funnel icon) and a search icon. When filters are active, there will be a badge showing how many filters are currently applied (like "3" if 3 filters are active).

**Search Implementation**
When the user taps the search icon, a search bar will slide down from the top. The search will be real-time as the user types (with debounce to avoid too many calls). Below the search bar it will show "X results". There will be an "X" button to clear the search and dismiss the bar. The search will look across both ticket title and description.

**Filter Sheet (Modal Presentation)**
When the user taps the filter button, a bottom sheet or full-screen modal will pop up (depends on how complex the filters get). This will use SwiftUI's `.sheet()` modifier with medium detent for compact filters. The filter sheet will have different sections in a grouped list:
  
  1. **Status Section**
     - Use a segmented picker or checkboxes
     - Options: All, Open, Resolved, Closed
     - Allow multi-select (e.g., show both Open and Resolved)
  
  2. **Severity Section**
     - Use checkboxes for multi-select
     - Show all severity levels (SEV_1 through SEV_5)
     - Use color-coded indicators next to each option
  
  3. **Queue Section**
     - Dropdown/Picker showing all queues in the family
     - Option for "All Queues"
  
  4. **Assigned To Section**
     - Picker with options:
       - All Tickets
       - Assigned to Me
       - Unassigned
       - Specific User (searchable list if family is large)
  
  5. **Assigned Group Section**
     - Picker showing all groups
     - Option for "All Groups"
  
  6. **Date Range Section**
     - Preset options: Today, Last 7 Days, Last 30 Days, Custom
     - If Custom: show DatePicker for start and end dates

* **Bottom action bar** in filter sheet:
  - "Clear All" button (secondary/ghost style) on left
  - "Apply Filters" button (primary style) on right
  - Show count of active filters on Apply button

**Sort Implementation**
* Add a **sort button** (arrows icon) next to filter button in navigation bar
* Tapping presents a **small menu/action sheet** with sort options:
  - Created Date (Newest First) ← default
  - Created Date (Oldest First)
  - Last Updated (Newest First)
  - Last Updated (Oldest First)
  - Severity (High to Low)
  - Severity (Low to High)
  - Title (A-Z)
  - Title (Z-A)
* Show current sort option with a checkmark
* Menu dismisses automatically on selection

**Active Filter Indicators**
* Show **filter chips** below the navigation bar when filters are active
* Each chip shows filter type and value (e.g., "Status: Open", "Severity: SEV_1")
* Tapping "X" on a chip removes that specific filter
* Include "Clear All" chip at the end if multiple filters active
* Chips scroll horizontally if needed

**Summary Dashboard Cards (Above Ticket List)**
* **Horizontal scrolling row** of compact stat cards:
  - Total Open (number)
  - Assigned to Me (number)
  - High Priority (SEV_1 + SEV_2 count)
  - Resolved Today (number)
* Each card is tappable and applies that filter
* Use SF Symbols icons for visual clarity
* Cards have subtle background colors matching their category

**Ticket List Behavior**
* Tickets filter/sort **in real-time** as criteria change
* Show **"No tickets match your filters"** empty state with illustration
* Include quick action to clear filters from empty state
* Maintain scroll position when returning from ticket detail (where possible)
* Use **pull-to-refresh** to reload ticket data

**Performance Considerations**
* Filter and sort **locally** on device when possible
* If ticket count is very large (>500), consider server-side filtering with pagination
* Cache filter preferences locally using UserDefaults or SwiftData
* Restore last-used filters when returning to family view

**Visual Design (SwiftUI)**
* Use native iOS components: `Picker`, `Toggle`, `DatePicker`, `TextField`
* Follow iOS Human Interface Guidelines for filter sheets
* Use `.searchable()` modifier for search bar (iOS 15+)
* Animations: smooth transitions when filters apply (fade/slide)
* Haptic feedback when filters are applied or cleared

**Alternative: Compact Filter Bar (For Simpler Filtering)**
If you want **always-visible** filters instead of a modal:
* Add a **horizontal scrolling filter bar** below navigation
* Each filter type is a tappable chip/button that expands options
* Example: [Status ▼] [Severity ▼] [Assigned To ▼] [Sort ▼]
* Tapping expands a dropdown menu below the chip
* More compact but less discoverable than dedicated filter sheet

### Website
The website will use a table layout for tickets (similar to enterprise help desk systems like Jira/ServiceNow). The table will have these columns:
  - Ticket ID (clickable link)
  - Title
  - Status (with colored badges: Open=blue, Resolved=green, Closed=gray)
  - Severity (SEV_1 through SEV_5, with visual indicators - SEV_1 in red, descending to SEV_5 in gray)
  - Assigned To (user display name or "Unassigned")
  - Assigned Group
  - Created Date
  - Last Updated
The website will have filtering for Status (Open, Resolved, Closed), Severity, Queue, Assigned Group, Assigned User, and Date ranges. Users will be able to sort on all columns.
* Include a **search bar** to search across ticket titles and descriptions
At the top there will be a summary dashboard with cards showing Total Open Tickets, My Assigned Tickets, High Severity Tickets (SEV_1 and SEV_2), and Recently Updated. For large ticket lists, pagination will kick in (20-50 tickets per page). There will be a prominent "Create Ticket" button in the top right. On mobile, the table will switch to a card layout similar to the iOS app.

## Authenticated Home - Website Enhancements

For the authenticated home page on the website, the main container should have a max width of 1200px. The welcome section will be centered with the user's display name. Below the greeting, consider adding a quick stats row showing things like "You have X open tickets assigned to you", "X families need your attention", and "X pending invitations".

### My Families Section
The families will be shown in a grid layout instead of a single column - 3 columns on desktop, 2 on tablet, and 1 on mobile. Each family card will show:
  - Family icon/avatar (if available) or default icon
  - Family name (prominent)
  - Description (truncated if long)
  - Member status badge (Member/Pending)
  - Quick stats:
    - Number of open tickets in this family
    - Number of groups you're in
    - Your role (Member/Admin)
  - "View Family" button/clickable card
  - Three-dot menu for quick actions (Leave Family, Manage Settings - if admin)
* **Action buttons** (already have Create button ✓):
  - Add "Join Family" button for entering a family by invite code
  - Keep the Create Family button
  - Keep the refresh button

### Quick Actions Panel
Add a section between Welcome and My Families:
* **Recent Activity** (optional, for later):
  - Last 5 tickets you created or commented on
  - Recent family invitations
  - Recent mentions
* **Shortcuts**:
  - "Create New Ticket"
  - "View All My Tickets" (across all families)
  - "Pending Invitations"

### Visual Design
* Use **Ant Design components** consistently (you're already using this ✓)
* Color scheme:
  - Family cards: white background with subtle border and shadow on hover
  - Status badges: Green (Member), Orange (Pending), Red (Declined)
  - Primary action buttons: Blue (Ant Design primary)
* **Empty states** (already implemented ✓):
  - Keep the friendly "no families yet" message
  - Add an illustration or icon
  - Emphasize the "Create Family" action

### Responsive Behavior
* Desktop (>1200px): Full 3-column family grid, sidebar for quick actions
* Tablet (768px-1200px): 2-column family grid
* Mobile (<768px): Single column, stack everything, use bottom navigation if needed 

---

## Family Navigation Structure

When a user enters a Family from the home page, they'll need quick access to Tickets, Groups, and Queues.

### iOS App - Bottom Tab Navigation

The iOS app will have a bottom tab bar with three tabs:

**Tab 1: Tickets** (Default)
* Icon: `ticket.fill` or `list.bullet`
* Shows all tickets for the family
* Includes filter/sort/search capabilities
* Summary dashboard cards at top
* This is the primary view users will see

**Tab 2: Groups**
* Icon: `person.3.fill` or `folder.fill`
* Shows all groups in the family (grid or list)
* Quick access to create group (if admin)
* Each group card tappable to GroupDetailView

**Tab 3: Queues**
* Icon: `tray.2.fill` or `rectangle.stack.fill`
* Shows **all queues across all groups** in the family
* Organized by group (sectioned list) or flat list with group badges
* Allows quick navigation to any queue
* Filter by: All Queues, My Groups' Queues, Specific Group

**Top Navigation Bar** (above tabs)
* Family name as title
* Back button to return to home/families list
* Family settings icon (gear) - for admins
* User profile button (top right)

**Benefits of Bottom Tabs**
* Always visible - easy to switch between tickets, groups, and queues
* Native iOS pattern
* Thumb-friendly on all iPhone sizes
* Clear separation of concerns

### Website - Side Navigation

Within FamilyPage, use a **left sidebar navigation** with the main content area.

**Sidebar Structure** (fixed, ~250px width)

**Family Header**
* Family icon/avatar
* Family name
* Family description (truncated with tooltip)

**Navigation Items**
1. **Overview/Dashboard** (optional)
   * Icon: dashboard/home
   * Family-wide stats and activity

2. **Tickets** (default/primary)
   * Icon: ticket
   * Badge showing open ticket count
   * Active state when viewing tickets

3. **Groups**
   * Icon: people/folder
   * Shows count of groups
   * Expandable sub-menu showing list of groups (optional)
   * Active state when viewing groups list or specific group

4. **Queues**
   * Icon: inbox/stacks
   * Shows count of queues
   * Optionally expandable to show all queues
   * Active state when viewing queues

5. **Members** (optional separate section)
   * Icon: person
   * List all family members
   * Invite members

**Bottom of Sidebar**
* Family Settings (for admins)
* Leave Family option

**Main Content Area** (remaining space)
* Shows content based on sidebar selection
* Tickets view, Groups list, Queue list, etc.
* Full filtering and controls

**Responsive Behavior**
* **Desktop (>1024px)**: Sidebar always visible, fixed width
* **Tablet (768px-1024px)**: Collapsible sidebar with hamburger menu
* **Mobile (<768px)**: Hidden sidebar, hamburger menu opens drawer, or switch to bottom tabs like iOS

**Benefits of Sidebar**
* More screen space for content
* Always visible navigation (on desktop)
* Can show hierarchical structure (groups → queues)
* Standard web app pattern
* Room for additional sections as app grows

---

## Groups Management

Groups are sub-organizations within a Family that own Queues and define which users can access them. They sit hierarchically under families.

### Navigation to Groups

**iOS App**
The user will tap the "Groups" tab in the bottom navigation. This will show all groups in a List or Grid. There will be a "+ Create Group" button in the top nav bar (only visible to family admins). If there are many groups, a search bar will let users filter by name.

**Website**
* Click **"Groups"** in the left sidebar
* Main content area shows groups in a **grid layout**
  - 2-3 columns on desktop
  - 1-2 columns on tablet/mobile
* Add a **"Create Group"** button at the top right (visible only to family admins)
* Breadcrumb: Family Name > Groups

### Group List Display

**Both Platforms**
Each group card/row will show the group icon (or a default if not customized), the group name, a description (truncated if it's long), member count (like "5 members"), queue count (like "3 queues"), and the user's membership status with a badge (green for Member, orange for Pending, blue for Admin). There will also be quick stats showing open tickets in this group's queues and unassigned tickets. The main action will be "View Group", and there will be a three-dot menu for Edit, Leave Group, and Delete (if admin).

**Filtering/Sorting Groups**
* **Website**: Add filter/sort bar above group grid
  - Filter by: My Groups, All Groups, Groups I Admin
  - Sort by: Name, Member Count, Created Date, Open Tickets
* **iOS**: Use segmented control or filter sheet
  - Segments: All, My Groups, Admin

### Group Detail View

Shows comprehensive information about a specific group.

**Layout (Both Platforms)**

1. **Header Section**
   * Group icon/avatar (editable by admins)
   * Group name (prominent)
   * Group description
   * Edit button (for admins only)

2. **Stats Row**
   * Total Members
   * Total Queues
   * Open Tickets
   * Created Date

3. **Queues Section** (primary focus)
   * Title: "Queues" with "+ Create Queue" button (for group admins)
   * List/Grid of queues owned by this group
   * Each queue card shows:
     - Queue name
     - Queue description
     - Open ticket count
     - Unassigned ticket count
     - "View Queue" action
   * Empty state: "No queues yet. Create one to start organizing tickets."

4. **Members Section**
   * Title: "Members" with "+ Add Member" button (for group admins)
   * List of members with:
     - User display name
     - User avatar/initials
     - Status (Member, Pending, Admin)
     - Role in group
     - Remove button (for admins, can't remove self)
   * Show pending invitations separately
   * Search bar if member count is large (>10)

5. **Settings Section** (admin only)
   * Button to access group settings
   * Shows: Rename, Change Description, Delete Group

**iOS Specific**
* Use List with sections
* Pull-to-refresh for data
* Swipe actions on members (Remove, Make Admin)

**Website Specific**
* Use Ant Design Tabs for Queues/Members/Settings
* Table view for members with action columns
* Modal for editing group details

### Create Group Flow

When creating a group, the user will tap/click the "+ Create Group" button from the Family Detail page. The form will have a Group Name field (required, max 100 characters, must be unique within the family), a Group Description field (optional, max 500 characters), and an Initial Members picker (optional, multi-select from family members). The creator will automatically be added as an admin.

**iOS**
* Present as sheet with `.medium` or `.large` detent
* Form validation with inline errors
* "Cancel" and "Create" buttons in navigation bar

**Website**
* Modal dialog using Ant Design Modal
* Form validation with Ant Design Form component
* "Cancel" and "Create Group" buttons at bottom

**After Creation**
* Navigate to newly created GroupDetailView
* Show success toast/alert
* Refresh family's group list

### Group Settings (Admin Only)

Accessible from GroupDetailView → Settings button

**Editable Settings**
1. **Basic Information**
   * Group name
   * Group description
   * Group icon/avatar (future enhancement)

2. **Member Management**
   * Add members from family
   * Remove members
   * Promote/demote admins
   * Set default member permissions

3. **Queue Management**
   * Create new queue
   * Delete queues (only if no tickets or all tickets closed)
   * Reorder queues (display order)

4. **Danger Zone**
   * Delete Group
     - Only if all queues are empty or deleted
     - Confirmation required
     - Shows warning about impact
     - Cannot delete if it's the last group in family

**iOS**
* Present as separate SettingsView with Form
* Sections for each category
* Destructive actions in red

**Website**
* Settings tab in GroupDetailView
* Sections with Ant Design Card components
* Confirmation modals for destructive actions

---

## Queue Management

Queues are logical containers where tickets are placed. Each queue is owned by exactly one group.

### Navigation to Queues

**iOS App - Queues Tab**
* Tap **"Queues"** tab in the bottom navigation
* Shows **all queues across all groups** in the family
* Two display options:
  1. **Sectioned List** (recommended): Group queues by their parent group
     - Section header shows group name
     - Queues listed under each group
     - Collapsible sections
  2. **Flat List**: All queues with group name shown as a badge on each queue card

**Website - Queues Sidebar Item**
* Click **"Queues"** in the left sidebar
* Main content area shows all queues
* Options:
  1. **Grid layout** with group filters at top
  2. **Grouped cards**: Queues organized by group in expandable sections
  3. **Sidebar sub-menu**: Expand "Queues" in sidebar to show hierarchical list (Groups → Queues)

**From Group Detail View (Both Platforms)**
* When viewing a specific group, queues section lists only that group's queues
* Tapping a queue navigates to QueueDetailView

**From Ticket Filters (Both Platforms)**
* Users can filter tickets by queue across all groups
* Clicking queue name in filter navigates to that queue's view

### Queue List Display

Within GroupDetailView, queues are shown as cards/rows.

**Each Queue Card Shows**
* **Queue icon** (default: inbox icon)
* **Queue name**
* **Queue description** (truncated)
* **Ticket counts**:
  - Open tickets (prominent)
  - Resolved tickets
  - Total tickets
* **Assigned members** (avatars of group members who typically handle this queue)
* **Quick actions**:
  - "View Queue" (main action)
  - "Create Ticket" (opens create ticket form pre-filled with this queue)
  - Three-dot menu: Edit, Delete (if admin)

**iOS**
* List with NavigationLink
* Swipe actions: Create Ticket, Edit, Delete

**Website**
* Grid layout (2 columns)
* Hover shows quick stats
* Click anywhere on card to view queue

### Queue Detail View

Shows all tickets in a specific queue with full filtering and sorting capabilities.

**Layout**

1. **Header Section**
   * Queue icon
   * Queue name (prominent)
   * Queue description
   * Group badge (shows which group owns this queue)
   * Edit button (for group admins)

2. **Stats Row**
   * Open Tickets
   * Resolved Tickets
   * Avg Resolution Time
   * Oldest Open Ticket

3. **Quick Actions**
   * **"+ Create Ticket"** button (primary action)
   * Filter button
   * Sort button
   * Search

4. **Ticket List** (main content)
   * Same ticket list as Family Home but filtered to this queue
   * All the same filtering/sorting capabilities
   * **iOS**: Card-based list with all filter options
   * **Website**: Table view with inline filters

5. **Queue Settings** (admin only, accessed via button)
   * Edit queue name/description
   * Assign default handlers
   * Set queue-specific rules (future)
   * Delete queue

**Pre-applied Filters**
* Queue filter is locked to current queue (shown as a locked chip)
* Users can still apply additional filters (status, severity, assigned to, etc.)
* Breadcrumb navigation shows: Family → Group → Queue

### Create Queue Flow

**Trigger**
* From GroupDetailView, tap/click "+ Create Queue" button
* Only group admins can create queues

**Form Fields**
1. **Queue Name** (required)
   * Text input
   * Character limit: 100
   * Validation: Must be unique within group

2. **Queue Description** (optional)
   * Text area
   * Character limit: 500
   * Helpful tip: "Describe what types of tickets go in this queue"

3. **Default Assignees** (optional)
   * Multi-select from group members
   * These users will be suggested when assigning tickets in this queue

**iOS**
* Sheet presentation
* Form with sections
* "Cancel" and "Create" buttons

**Website**
* Modal dialog
* Ant Design Form
* "Cancel" and "Create Queue" buttons

**After Creation**
* Navigate to QueueDetailView or stay in GroupDetailView
* Show success message
* Refresh group's queue list

### Queue Settings (Admin Only)

Accessible from QueueDetailView → Settings button

**Editable Settings**
1. **Basic Information**
   * Queue name
   * Queue description
   * Queue icon (future)

2. **Assignment Rules** (future enhancement)
   * Default assignees
   * Round-robin assignment
   * Auto-assignment based on ticket severity

3. **Notifications** (future)
   * Notify on new ticket
   * Notify on unassigned ticket
   * Escalation rules

4. **Danger Zone**
   * Delete Queue
     - Only if no open tickets
     - Options: 
       - Delete queue and move all resolved/closed tickets to another queue
       - Delete queue only if completely empty
     - Confirmation required with ticket count displayed

**iOS**
* Settings view with Form
* Destructive section at bottom

**Website**
* Settings tab or separate page
* Organized in collapsible sections
* Confirmation modals for deletion

### Queue-Specific Filtering

When viewing tickets in a queue context:

**Lock Queue Filter**
* The queue filter is automatically applied and shown as a non-removable chip
* Visual indicator: different chip style (locked icon, can't be dismissed)

**Additional Filters Available**
* All standard filters still work (status, severity, assigned to, date range, etc.)
* Filter combinations are preserved when navigating away and back

**Breadcrumb Context**
* **iOS**: Navigation bar shows "< [Group Name]" back button, title shows queue name
* **Website**: Breadcrumb trail: "Family Name > Group Name > Queue Name"
* Clicking breadcrumb parts navigates back to that level

### Group and Queue Permissions

**Family Admins**
* Can create, edit, and delete any group
* Can create, edit, and delete any queue
* Can manage all members

**Group Admins**
* Can edit their group settings
* Can add/remove group members
* Can create, edit, and delete queues in their group
* Can manage queue settings
* Cannot delete the group if they didn't create it (unless also family admin)

**Group Members**
* Can view group and queue details
* Can create tickets in group's queues
* Can see other members
* Cannot edit group/queue settings
* Can leave the group

**Non-members**
* Cannot see groups they're not in (unless family admin)
* Cannot access queues in groups they're not in
* Cannot create tickets in those queues

### Empty States

**Group with No Queues**
* Illustration/icon
* "This group doesn't have any queues yet"
* If admin: "Create your first queue to start organizing tickets" with create button
* If member: "Ask a group admin to create queues"

**Queue with No Tickets**
* Illustration/icon
* "No tickets in this queue yet"
* "Create your first ticket" button
* Helpful tip about what this queue is for (from description)

**No Groups in Family**
* Illustration/icon
* "This family doesn't have any groups yet"
* If family admin: "Groups help organize your tickets. Create one to get started" with create button
* If member: "Ask a family admin to create groups"

---

## Creating Tickets

Tickets are the core work items in the system. Any family member can create a ticket.

### Access Points for Creating Tickets

The primary way to create a ticket will be from the top navigation bar - a "+" button on iOS and a "Create Ticket" button on the website (both always visible when you're in a family).
   
2. **From Queue View**
   * "+ Create Ticket" button prominently displayed in queue detail view
   * Pre-fills the queue selection with current queue

3. **From Empty States**
   * When a queue has no tickets, show "Create your first ticket" button
   
4. **Quick Actions** (optional enhancement)
   * iOS: Long-press on app icon shows "Create Ticket" quick action
   * Website: Keyboard shortcut (e.g., Cmd+N or Ctrl+N)

### Create Ticket Flow

**Trigger**
* Tap/click "Create Ticket" button from anywhere in the family context

**Presentation**
* **iOS**: Full-screen sheet (`.sheet()` with `.large` detent) or NavigationStack
* **Website**: Modal dialog (Ant Design Modal, medium-large size ~600-700px width)

### Form Fields

**1. Ticket Title** (required)
This will be a text input with the placeholder "Brief description of the issue". Max 200 characters, minimum 3 characters. The field will auto-focus when the form opens.

**2. Description** (optional)
A multi-line text area with the placeholder "Provide additional details about the issue (optional)". Max 2000 characters, supports line breaks. On iOS this will be an expandable text editor, on the website it will be a rich text area with auto-resize.

**3. Group** (required)
A dropdown/picker showing all the groups the user is a member of. It will show the group name with member count. When a group is selected, this triggers the queue loading.

**4. Queue** (required, dependent on Group)
A dropdown/picker showing all queues for the selected group. This will be disabled until a group is selected. When the group is selected, the app will make a GET request to `/api/families/{family_id}/groups/{group_id}/queues` to fetch the queues. There will be a loading spinner while fetching. The dropdown will show queue name with description (truncated) and open ticket count. If the user is coming from a queue view, this will be pre-filled and disabled.

**5. Severity** (required)
A dropdown/picker or segmented control for severity level. The options will be SEV_1 through SEV_5 with color indicators (SEV_1 in red for critical, down to SEV_5 in gray for minimal). The default will be SEV_4. Each option will show a color indicator and brief description.

**6. Assign To** (optional)
A searchable dropdown/picker showing all family members. The default is "Unassigned". When the form opens, it will fetch `/api/families/{family_id}/members`. Each member will show with their avatar/initials and display name. On iOS, if there are more than 10 members it will use a NavigationLink to a searchable list, otherwise just a Picker. On the website it will use Ant Design Select with search functionality. This field can be left unassigned.

### Form Layout

**iOS**
The form will be a full-screen sheet with a navigation bar. Nav bar will have "Cancel" on the left, "Create Ticket" as the title, and "Create" on the right (disabled until the form is valid). The form will be scrollable with sections for Details (title and description), Assignment (group and queue pickers - queue is disabled until group is selected and shows loading when fetching), Priority (severity picker), and Assignee (NavigationLink to user selection or picker). All the form controls will use native SwiftUI components.

**Website**
The form will be in a modal dialog (medium-large, around 600-700px width). The header will say "Create Ticket" with a close X button. The form body will use Ant Design Form with vertical layout - title input, description text area, then group and queue in the same row (2 columns), then severity dropdown with colored badges, and finally the assign to searchable select with avatars. The footer will have Cancel and Create Ticket buttons.

### Form Validation

**Client-side Validation**
The title is required (minimum 3 characters, maximum 200). Group and Queue are required - must select from the list. Queue is only enabled after group selection. Severity is required and defaults to SEV_4. Assign To is optional.

**Real-time Feedback**
On iOS, the "Create" button in the nav bar will be disabled until the form is valid. On the website, the "Create Ticket" button will be disabled until valid. Inline error messages will show up for invalid fields when the user leaves the field (on blur). Required fields will have an asterisk.

### API Integration

**1. Load Groups** (on form open)
Hit `GET /api/families/{family_id}/groups/my-groups` to get the list of groups the user is a member of. Cache this in local state/memory for the session.

**2. Load Queues** (when group selected)
Hit `GET /api/families/{family_id}/groups/{group_id}/queues` when the group selection changes. Show a loading state while fetching. Clear the previous queue selection when the group changes. If queues fail to load, show an error message.

**3. Load Family Members** (on form open)
Hit `GET /api/families/{family_id}/members` to get all family members. Cache this for the session.

**4. Create Ticket** (on form submit)
Hit `POST /api/families/{family_id}/queues/{queue_id}/tickets` with the ticket title, description (optional), severity, and assigned_to (optional). The response will be the newly created ticket object. If creation fails, display an error message.

### Form Behavior

**Group → Queue Dependency**
The queue dropdown is disabled until a group is selected. When the group changes, the current queue selection gets cleared, a loading spinner shows in the queue dropdown, queues are fetched for the new group, and then the queue dropdown gets enabled when queues are loaded. If the user is coming from a queue view, the group and queue will be pre-filled and locked/disabled.

**Submission Flow**
When the user clicks "Create", the app will validate all required fields, show a loading state on the button (spinner + disable), make the API call to create the ticket, and then on success dismiss the form, show a success toast ("Ticket created successfully"), navigate to the ticket detail view or refresh the ticket list, and clear the form state. On error, it will show an error message (toast or inline), re-enable the button, and keep the form data intact so the user can try again.

**Cancel Behavior**
On iOS there will be a "Cancel" button in the nav bar. On the website there will be a "Cancel" button in the footer or an X in the header. If the form has data in it, the app will show a confirmation: "Discard unsaved changes?". If the form is empty, it will dismiss immediately.

### Post-Creation Actions

**iOS**
After creating a ticket, the sheet will dismiss with a smooth animation, show a success toast at the bottom, and either navigate to the ticket detail view or return to the ticket list with the new ticket at the top (marked as "New"). There will be haptic success feedback.

**Website**
The modal will close, and a success notification will pop up in the top right (Ant Design notification). The app can either redirect to the ticket detail page, stay on the current page and refresh the ticket list, or show a "View Ticket" link in the success notification. The ticket count in the sidebar/dashboard will get updated.

### Pre-filled Context

When creating ticket from different contexts:

**From Queue View**
* Group: Pre-filled with queue's parent group (locked)
* Queue: Pre-filled with current queue (locked)

**From Group View**
* Group: Pre-filled with current group (can be changed)
* Queue: Empty, user must select from this group's queues

**From Tickets Tab (Generic)**
* All fields empty, user must select everything

### Error States

**No Groups Available**
* Show alert: "You must be a member of at least one group to create tickets"
* Disable "Create Ticket" button
* Or show empty state in form

**Selected Group Has No Queues**
* Show message in queue dropdown: "This group has no queues. Contact a group admin."
* Cannot proceed until different group selected

**API Errors**
* Failed to load groups: Show retry button
* Failed to load queues: Show retry button, allow group re-selection
* Failed to create ticket: Show error message, keep form data, allow retry

### Accessibility

**iOS**
* All form fields have labels and accessibility identifiers
* Use `.accessibilityLabel()` and `.accessibilityHint()`
* Support VoiceOver navigation
* Proper focus management

**Website**
* Proper ARIA labels on all form fields
* Keyboard navigation support (Tab, Enter, Esc)
* Screen reader announcements for loading states
* Focus trap within modal

### Future Enhancements (Optional)

* **Attachments**: Allow users to attach images/files
* **Templates**: Save ticket templates for common issues
* **Auto-assignment**: Smart suggestions based on queue's default assignees
* **Duplicate detection**: Warn if similar ticket exists
* **Draft saving**: Save in-progress tickets as drafts
* **Bulk creation**: Create multiple tickets at once 

