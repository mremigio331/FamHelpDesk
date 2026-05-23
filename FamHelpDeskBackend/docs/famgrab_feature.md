# FamGrab Feature

## Overview

FamGrab is a per-family feature that allows members to request items (food, drinks, snacks, etc.) and have other family members fulfill those requests. It introduces a fun, lightweight economy using a fake currency called **Embolecs**.

The inspiration: a pregnant family member who could use a hand getting food brought to her — but the feature is for everyone in the family.

## How It Works

1. **Monthly Allowance** — Every family member receives 50 Embolecs at the start of each month.
2. **Create a Request** — A user creates a "Grab Request" containing one or more items they want (e.g., "iced coffee from Starbucks", "a bag of chips from the store"). Each request has a total Embolec cost set by the requestor.
3. **Claim a Request** — Another family member can claim the request, signaling they'll fulfill it.
4. **Complete the Request** — The claimer marks the request as completed once they've delivered the items.
5. **Confirm Delivery** — The original requestor confirms receipt. Upon confirmation, the Embolecs transfer from the requestor to the claimer.
6. **Negative Balances Allowed** — Users can spend more Embolecs than they have. Balances can go negative. This keeps things low-friction and avoids blocking requests.

## Request Lifecycle

```
OPEN → CLAIMED → COMPLETED → CONFIRMED
                     ↓
                  CANCELLED (at any point before CONFIRMED)
```

| Status    | Description                                      |
|-----------|--------------------------------------------------|
| OPEN      | Request created, waiting for someone to claim it |
| CLAIMED   | A family member has claimed the request          |
| COMPLETED | Claimer has delivered the items                  |
| CONFIRMED | Requestor confirmed delivery; Embolecs transfer  |
| CANCELLED | Request was cancelled before confirmation        |

---

## Data Models

All models follow the existing single-table DynamoDB design with `pk` and `sk`.

---

### 1. Embolec Balance (`EmbolecBalanceModel`)

Tracks each user's current Embolec balance within a family.

| Field              | Type   | Description                                      |
|--------------------|--------|--------------------------------------------------|
| `pk`               | String | `FAMILY#{family_id}`                             |
| `sk`               | String | `EMBOLEC_BALANCE#{user_id}`                      |
| `family_id`        | String | The family this balance belongs to               |
| `user_id`          | String | The user who owns this balance                   |
| `balance`          | Number | Current Embolec balance (can be negative)        |
| `last_refresh_date`| Number | Epoch timestamp of last monthly refresh          |
| `total_earned`     | Number | Lifetime Embolecs earned from fulfilling requests|
| `total_spent`      | Number | Lifetime Embolecs spent on requests              |

**Key Design Notes:**
- Balance is per-user, per-family (a user in multiple families has separate balances).
- `last_refresh_date` is used to determine if the monthly 50 Embolec refresh has been applied.
- Negative balances are allowed by design.

---

### 2. Embolec Transaction (`EmbolecTransactionModel`)

An append-only ledger of all Embolec movements.

| Field              | Type   | Description                                          |
|--------------------|--------|------------------------------------------------------|
| `pk`               | String | `FAMILY#{family_id}`                                 |
| `sk`               | String | `EMBOLEC_TXN#{transaction_id}`                       |
| `transaction_id`   | String | Unique ID for this transaction                       |
| `family_id`        | String | The family this transaction belongs to               |
| `from_user_id`     | String | User who sent Embolecs (or `SYSTEM` for monthly refresh) |
| `to_user_id`       | String | User who received Embolecs                           |
| `amount`           | Number | Number of Embolecs transferred                       |
| `transaction_type` | String | Enum: `MONTHLY_REFRESH`, `GRAB_PAYMENT`              |
| `grab_request_id`  | String | (nullable) Associated Grab Request ID                |
| `created_at`       | Number | Epoch timestamp of when the transaction occurred     |
| `note`             | String | (nullable) Optional description                      |

**Key Design Notes:**
- Transactions are immutable (append-only). No updates or deletes.
- `MONTHLY_REFRESH` transactions have `from_user_id = "SYSTEM"`.
- `GRAB_PAYMENT` transactions link back to the Grab Request that triggered them.

---

### 3. Grab Request (`GrabRequestModel`)

A single request from a user asking for items to be brought to them.

| Field              | Type   | Description                                          |
|--------------------|--------|------------------------------------------------------|
| `pk`               | String | `FAMILY#{family_id}`                                 |
| `sk`               | String | `GRAB_REQUEST#{request_id}`                          |
| `request_id`       | String | Unique ID for this request                           |
| `family_id`        | String | The family this request belongs to                   |
| `requestor_id`     | String | User who created the request                         |
| `claimer_id`       | String | (nullable) User who claimed the request              |
| `status`           | String | Enum: `OPEN`, `CLAIMED`, `COMPLETED`, `CONFIRMED`, `CANCELLED` |
| `embolec_cost`     | Number | Total Embolecs offered for fulfilling this request   |
| `title`            | String | Short summary of the request (e.g., "Lunch run")     |
| `note`             | String | (nullable) Additional details or instructions        |
| `created_at`       | Number | Epoch timestamp of creation                          |
| `claimed_at`       | Number | (nullable) Epoch timestamp when claimed              |
| `completed_at`     | Number | (nullable) Epoch timestamp when marked completed     |
| `confirmed_at`     | Number | (nullable) Epoch timestamp when requestor confirmed  |
| `cancelled_at`     | Number | (nullable) Epoch timestamp when cancelled            |
| `cancelled_by`     | String | (nullable) User who cancelled                        |
| `proof_photo_key`  | String | (nullable) S3 object key for delivery confirmation photo |

**Key Design Notes:**
- A request belongs to a family (scoped under `FAMILY#{family_id}`).
- Only one user can claim a request at a time.
- The `embolec_cost` is set by the requestor at creation time.
- `proof_photo_key` stores the S3 object key for the optional delivery confirmation photo.

---

### 4. Grab Request Item (`GrabRequestItemModel`)

Individual items within a Grab Request. A request can have one or many items.

| Field              | Type   | Description                                          |
|--------------------|--------|------------------------------------------------------|
| `pk`               | String | `FAMILY#{family_id}`                                 |
| `sk`               | String | `GRAB_REQUEST#{request_id}#ITEM#{item_id}`           |
| `item_id`          | String | Unique ID for this item                              |
| `request_id`       | String | Parent Grab Request ID                               |
| `family_id`        | String | The family this belongs to                           |
| `name`             | String | Item name (e.g., "Iced Latte")                       |
| `quantity`         | Number | How many of this item (default: 1)                   |
| `note`             | String | (nullable) Special instructions (e.g., "oat milk")   |

**Key Design Notes:**
- Items are nested under their parent request via the hierarchical sort key pattern (`GRAB_REQUEST#{request_id}#ITEM#{item_id}`).
- Querying all items for a request uses a `begins_with` on the SK: `GRAB_REQUEST#{request_id}#ITEM#`.
- Items are created with the request and are immutable after creation.

---

## Access Patterns

| Access Pattern                              | Key Condition                                                    |
|---------------------------------------------|------------------------------------------------------------------|
| Get user's Embolec balance in a family      | `pk = FAMILY#{family_id}`, `sk = EMBOLEC_BALANCE#{user_id}`      |
| List all Grab Requests for a family         | `pk = FAMILY#{family_id}`, `sk begins_with GRAB_REQUEST#` (filter out items) |
| Get a specific Grab Request                 | `pk = FAMILY#{family_id}`, `sk = GRAB_REQUEST#{request_id}`      |
| Get items for a Grab Request                | `pk = FAMILY#{family_id}`, `sk begins_with GRAB_REQUEST#{request_id}#ITEM#` |
| Get a request + all its items               | `pk = FAMILY#{family_id}`, `sk begins_with GRAB_REQUEST#{request_id}` |
| List transactions for a family              | `pk = FAMILY#{family_id}`, `sk begins_with EMBOLEC_TXN#`        |
| Get all balances in a family                | `pk = FAMILY#{family_id}`, `sk begins_with EMBOLEC_BALANCE#`    |
| Get presigned upload URL for delivery photo | API call — generates S3 presigned PUT URL for `{family_id}/{request_id}/{photo_id}` |
| Get presigned download URL for delivery photo | API call — generates S3 presigned GET URL using stored `proof_photo_key` |

---

## Monthly Refresh Logic

- When a user's balance is read, check `last_refresh_date`.
- If the current month/year differs from the month/year of `last_refresh_date`, add 50 Embolecs to the balance, update `last_refresh_date`, and write a `MONTHLY_REFRESH` transaction.
- This is a lazy refresh — it happens on read, not via a scheduled job.

---

## Delivery Photo Confirmation (S3)

The claimer can optionally upload a photo as proof of delivery when marking a request as completed. This gives the requestor visual confirmation before they approve the transfer.

### S3 Bucket Structure

Photos are stored in a dedicated S3 bucket (or a prefix within the existing app bucket):

```
famgrab-photos/
  └── {family_id}/
      └── {request_id}/
          └── {photo_id}.jpg
```

**Key path**: `{family_id}/{request_id}/{photo_id}.jpg`

This key is stored in the `proof_photo_key` field on the Grab Request.

### Upload Flow

1. **Claimer marks request as completed** — the client requests a presigned upload URL from the API.
2. **API generates a presigned S3 PUT URL** — scoped to the correct key path, with a short TTL (e.g., 5 minutes) and a max content-length constraint.
3. **Client uploads the photo directly to S3** — using the presigned URL (no photo data passes through the API).
4. **API updates the Grab Request** — sets `proof_photo_key` and transitions status to `COMPLETED`.

### Viewing Flow

1. **Requestor opens the completed request** — the client requests a presigned download URL from the API.
2. **API generates a presigned S3 GET URL** — short TTL (e.g., 15 minutes).
3. **Client displays the photo** — using the presigned URL.

### API Endpoints

| Method | Path                                                        | Description                          |
|--------|-------------------------------------------------------------|--------------------------------------|
| POST   | `/family/{family_id}/grab/{request_id}/photo/upload-url`    | Get a presigned PUT URL for upload   |
| GET    | `/family/{family_id}/grab/{request_id}/photo`               | Get a presigned GET URL for viewing  |

### Security & Access Control

- Only the **claimer** of a request can upload a photo.
- Only the **requestor** and **claimer** can view the photo (or family admins).
- Presigned URLs are short-lived to limit exposure.
- The S3 bucket has public access blocked; all access goes through presigned URLs.
- Content-type is restricted to image types (`image/jpeg`, `image/png`, `image/heic`).
- A max file size (e.g., 10 MB) is enforced via the presigned URL's content-length condition.

### Infrastructure Notes

- The S3 bucket needs a lifecycle rule to delete photos after a retention period (e.g., 90 days) to manage storage costs.
- CORS must be configured on the bucket to allow direct uploads from the web frontend.
- The iOS app uses the same presigned URL approach — no SDK-level S3 access needed on the client.

---

## Tipping

When confirming delivery, the requestor can optionally add a tip on top of the original `embolec_cost`. This rewards claimers who go above and beyond.

### How It Works

1. Requestor confirms delivery and is prompted: "Want to add a tip?"
2. Requestor enters a tip amount (minimum 1 Embolec, no maximum).
3. The total transfer becomes `embolec_cost + tip_amount`.
4. A single `GRAB_PAYMENT` transaction is recorded with the full amount, and the `tip_amount` is stored on the Grab Request for display purposes.

### Data Model Changes

Add to `GrabRequestModel`:

| Field         | Type   | Description                                    |
|---------------|--------|------------------------------------------------|
| `tip_amount`  | Number | (nullable) Bonus Embolecs added at confirmation |

Add a new transaction type:

- `transaction_type` enum gains no new value — tips are rolled into the `GRAB_PAYMENT` transaction. The breakdown is visible on the request itself.

---

## Leaderboard

A family-level leaderboard showing who's earned the most Embolecs by fulfilling requests. This adds a fun, competitive element.

### What It Shows

- **Top Earners** — Ranked by `total_earned` from the Embolec Balance model.
- **Most Requests Fulfilled** — Ranked by count of requests where user was the claimer and status = `CONFIRMED`.
- **Current Month Stats** — Earnings and fulfillments for the current month only.

### API Endpoint

| Method | Path                                      | Description                          |
|--------|-------------------------------------------|--------------------------------------|
| GET    | `/family/{family_id}/grab/leaderboard`    | Get family leaderboard rankings      |

### Query Approach

- **All-time earnings**: Read all `EMBOLEC_BALANCE#` records for the family, sort by `total_earned` descending.
- **Monthly stats**: Query `EMBOLEC_TXN#` records for the family, filter by `created_at` within the current month and `transaction_type = GRAB_PAYMENT`, aggregate by `to_user_id`.
- **Fulfillment count**: Query `GRAB_REQUEST#` records, filter by `status = CONFIRMED`, count by `claimer_id`.

### Caching Consideration

Leaderboard queries scan multiple records. For families with heavy usage, consider caching the result (e.g., in a dedicated leaderboard record updated on each confirmation, or a short TTL cache at the API layer).

---

## Push Notifications

FamGrab integrates with the existing notification system to keep family members informed about request activity.

### Notification Types

Add to `FamliyNotificationType` enum:

| Type                      | Trigger                                    | Recipients                          |
|---------------------------|--------------------------------------------|-------------------------------------|
| `GRAB_REQUEST_CREATED`    | New Grab Request posted                    | All family members (except requestor) |
| `GRAB_REQUEST_CLAIMED`    | Someone claims a request                   | Requestor                           |
| `GRAB_REQUEST_COMPLETED`  | Claimer marks as completed                 | Requestor                           |
| `GRAB_REQUEST_CONFIRMED`  | Requestor confirms delivery                | Claimer                             |
| `GRAB_REQUEST_CANCELLED`  | Request is cancelled                       | Requestor or Claimer (the other party) |

### Integration Pattern

Follows the existing async notification architecture:

```python
notification_helper.create_notification_async(
    notification_type=FamliyNotificationType.GRAB_REQUEST_CREATED,
    request_id=request_id,
    user_id=requestor_id,
    family_id=family_id
)
```

A new `GrabNotificationHelper` in `helpers/notification_helpers/` will:
1. Determine recipients based on notification type.
2. Check per-user notification settings (new boolean flags on `FamilyNotificationSettings`).
3. Craft messages and call `create_notification()` for each recipient.

### Notification Settings

Add to `FamilyNotificationSettings`:

| Field                          | Type | Default | Description                        |
|--------------------------------|------|---------|------------------------------------|
| `grab_request_created`         | Bool | `True`  | Notify when new requests are posted |
| `grab_request_updates`         | Bool | `True`  | Notify on claim/complete/confirm/cancel |

---

## Request History

Users can browse past Grab Requests with filtering and pagination.

### API Endpoint

| Method | Path                                      | Description                          |
|--------|-------------------------------------------|--------------------------------------|
| GET    | `/family/{family_id}/grab/requests`       | List requests with filters           |

### Query Parameters

| Param        | Type   | Description                                         |
|--------------|--------|-----------------------------------------------------|
| `status`     | String | (optional) Filter by status: `OPEN`, `CLAIMED`, `COMPLETED`, `CONFIRMED`, `CANCELLED` |
| `user_role`  | String | (optional) `requestor` or `claimer` — filter to requests where the current user played that role |
| `start_date` | Number | (optional) Epoch timestamp — only requests created after this date |
| `end_date`   | Number | (optional) Epoch timestamp — only requests created before this date |
| `limit`      | Number | (optional) Page size (default: 20, max: 50)         |
| `last_key`   | String | (optional) Pagination cursor (DynamoDB LastEvaluatedKey, base64-encoded) |

### Query Strategy

- Base query: `pk = FAMILY#{family_id}`, `sk begins_with GRAB_REQUEST#` with a filter to exclude items (SK must not contain `#ITEM#`).
- Filters applied server-side on `status`, `requestor_id`/`claimer_id`, and `created_at` range.
- Results sorted by `created_at` descending (most recent first).

### GSI Consideration

If request volume grows large, a GSI with `family_id` as PK and `created_at` as SK would allow efficient time-range queries without scanning. For now, the main table query with filters should be sufficient for family-sized data.

---

## Embolec Economy & Inflation

### The Concern

With 50 Embolecs refreshed per user per month, the total supply grows linearly with family size and time. In a family of 6, that's 300 new Embolecs entering the system monthly. If people aren't spending them, balances accumulate and the currency loses meaning — "why bother fulfilling a request for 10 Embolecs when I already have 400?"

### Why It's Probably Fine (For Now)

This is a family fun currency, not a real economy. A few reasons inflation may not matter much:

1. **Small groups** — Families are typically 3–10 people. The total supply stays manageable.
2. **Spending is the point** — The system incentivizes spending (making requests). Hoarding Embolecs doesn't get you anything.
3. **Negative balances allowed** — Heavy requestors will go negative, which naturally drains supply from the system (they owe future labor).
4. **Social pressure** — In a family, people will notice if someone never fulfills requests. The currency is a nudge, not the only motivator.

### Options If Inflation Becomes a Problem

If balances start feeling meaningless, here are some levers to pull (roughly ordered from lightest to heaviest):

| Strategy                  | How It Works                                                      | Tradeoff                              |
|---------------------------|-------------------------------------------------------------------|---------------------------------------|
| **Cap balance**           | Don't refresh if balance is already above a threshold (e.g., 75) | Simple, but punishes savers           |
| **Decay / tax**           | Reduce balances by a small % each month before refresh            | Encourages spending, feels punitive   |
| **Reduced refresh**       | Lower the monthly amount (e.g., 30) or make it configurable per family | Easy to tune, less generous           |
| **Earn-to-refresh**       | Only get the full 50 if you fulfilled at least N requests last month | Rewards active members, adds complexity |
| **Dynamic pricing**       | Suggest Embolec costs based on average family balance             | Smart but over-engineered for a family app |
| **Seasonal resets**       | Reset everyone to 50 at some interval (quarterly?)                | Nuclear option, people lose progress  |

### Recommendation

Start with the current design (flat 50/month, no cap). Monitor via the leaderboard — if all-time balances are climbing with no spending, the simplest fix is a **conditional refresh**: skip the refresh if the user's balance is already ≥ 75 (or whatever the family admin sets). This is one `if` statement and zero new infrastructure.

---

## Future Considerations

- **Request expiration**: Auto-cancel requests that stay OPEN for too long (e.g., 24 hours).
- **Recurring requests**: Let users schedule repeating Grab Requests (e.g., "coffee every Monday").
- **Item templates**: Save frequently requested items for quick reuse.
- **Family admin controls**: Let admins configure monthly refresh amount, max request cost, etc.
- **Dispute resolution**: Handle cases where requestor refuses to confirm a legitimate delivery.
