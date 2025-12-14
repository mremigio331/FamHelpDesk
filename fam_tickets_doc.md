# Fam Help Desk – DynamoDB Design Document (Python-Normalized)

Fam Help Desk is a family-first help desk / ticketing system built as a learning project using a **single-table DynamoDB design**. The system supports multiple Families, Groups within Families, Queues owned by Groups, Tickets, Comments, and full auditing.

---

## Core Concepts

### Families
Families are the top-level isolation boundary. Each Family behaves like an independent ticketing system (similar to a company
n enterprise help desk tools). Friends may be invited to participate.

All data for a Family shares the same partition key.

---

## DynamoDB Design Principles

- Single-table design
- All items for a Family use `PK = FAMILY#{family_id}`
- Hierarchical `SK` values model containment
- Access patterns drive key structure
- Audit records are append-only and immutable
- Timestamps are stored as epoch seconds (`int`)
- All attribute names use Python-friendly `snake_case`

---

## Shared Base Model (Conceptual)

All PynamoDB models in this system will inherit from a **shared base model** that wraps `pynamodb.models.Model`.

### Responsibilities of the Base Model

The base model is responsible for:

- Defining the canonical primary keys:
  - `pk` (partition key)
  - `sk` (sort key)
- Centralizing table configuration:
  - table name
  - AWS region
  - optional local DynamoDB endpoint
- Providing shared helper utilities used across all models

### Shared Helper Functions (Conceptual)

The base model will expose reusable helpers such as:

- **UUID generation**
  - Generate unique identifiers for entities (families, groups, queues, tickets, comments)
- **Timestamp helpers**
  - Return current epoch time in seconds
- **Key builders**
  - Construct partition keys like `FAMILY#{family_id}`
  - Construct hierarchical sort keys by joining key segments
- **Safe access helpers**
  - Fetch an item and return `None` if it does not exist
  - Delete an item only if it exists
- **Serialization helpers**
  - Convert a model instance into a dictionary suitable for APIs or logging

### Design Intent

- All entity models should rely on the base model for shared behavior
- Entity-specific logic (key factories, validations) should live in each model
- Audit creation may either be triggered by the base model or by service-layer logic
- The base model should remain lightweight and dependency-free

---

## Entity Models

### Family (Metadata)

Represents the Family itself.

PK = FAMILY#{family_id}
SK = META

**Attributes**
- `family_id` (str)
- `family_name` (str)
- `family_description` (str)
- `creation_date` (int)
- `created_by` (str)

---

### Family Membership

Represents a user’s membership in a Family.

PK = FAMILY#{family_id}
SK = MEMBER#{user_id}

**Attributes**
- `family_id` (str)
- `user_id` (str)
- `status` (str) — `MEMBER | AWAITING | DECLINED`
- `is_admin` (bool)
- `request_date` (int)

---

## Groups

Groups represent sub-organizations within a Family.  
Groups own Queues and define which users can access them.

### Group (Metadata)

PK = FAMILY#{family_id}
SK = GROUP#{group_id}#META

**Attributes**
- `family_id` (str)
- `group_id` (str)
- `group_name` (str)
- `group_description` (str)
- `created_by` (str)
- `creation_date` (int)

---

### Group Membership

Represents a user’s membership in a Group.

PK = FAMILY#{family_id}
SK = GROUP#{group_id}#MEMBER#{user_id}

**Attributes**
- `family_id` (str)
- `group_id` (str)
- `user_id` (str)
- `status` (str) — `MEMBER | AWAITING | DECLINED`
- `is_admin` (bool)
- `request_date` (int)

---

## Queues

Queues are logical containers where Tickets are placed.
Queues are owned by a Group.

PK = FAMILY#{family_id}
SK = QUEUE#{queue_id}

**Attributes**
- `family_id` (str)
- `queue_id` (str)
- `queue_name` (str)
- `queue_description` (str)
- `creation_date` (int)

---

## Tickets

Tickets are the primary work items.
Each Ticket must belong to exactly one Queue.

### Status
- `OPEN`
- `RESOLVED`
- `CLOSED`

**Rule**
- Tickets cannot be reopened more than 30 days after being resolved.

### Severity
- `SEV_1` — affects the entire family (all members/groups are impacted; urgent for the whole family)
- `SEV_2` — affects multiple groups within the family (e.g., more than one household or sub-group, but not everyone)
- `SEV_2.5` — affects multiple groups, but can wait until family business hours (not urgent, but broad impact)
- `SEV_3` — affects a single group within the family (e.g., just the “cousins” group)
- `SEV_4` — affects an individual family member
- `SEV_5` — minor/personal—trivial or non-urgent (e.g., “why are you even cutting this?”)

---

### Ticket Item

PK = FAMILY#{family_id}
SK = QUEUE#{queue_id}#TICKET#{ticket_id}

**Attributes**
- `family_id` (str)
- `queue_id` (str)
- `ticket_id` (str)
- `title` (str)
- `description` (str | null)
- `severity` (str)
- `status` (str)
- `creation_date` (int)
- `resolved_date` (int | null)
- `closed_date` (int | null)
- `reopen_until` (int | null)
- `assigned_to` (str | null)

---

## Ticket Comments

Comments are stored as separate items to avoid hot updates.

PK = FAMILY#{family_id}
SK = QUEUE#{queue_id}#TICKET#{ticket_id}#COMMENT#{comment_id}

**Attributes**
- `family_id` (str)
- `queue_id` (str)
- `ticket_id` (str)
- `comment_id` (str)
- `comment_user` (str)
- `comment_body` (str)
- `comment_date` (int)
- `last_update` (int)

---

## Auditing

All entities generate audit records.
Audit records are append-only and immutable.

### Audit Item

PK = FAMILY#{family_id}
SK = AUDIT#{entity_type}#{entity_id}#TS#{timestamp}#ACTION#{action}

**Attributes**
- `family_id` (str)
- `entity_type` (str) — FAMILY, MEMBER, GROUP, QUEUE, TICKET, COMMENT
- `entity_id` (str)
- `action` (str) — CREATE | UPDATE | DELETE
- `actor_user_id` (str)
- `before` (map | null)
- `after` (map | null)
- `time` (int)

---

## Access Patterns

### Family
- Get Family metadata
- List Families for a user (via GSI)
- List members in a Family
- List pending Family invitations

### Groups
- List Groups in a Family
- List members in a Group
- Check Group membership for a user

### Queues
- List Queues in a Family
- Determine Queue ownership and access

### Tickets
- List Tickets in a Queue (sorted by creation_date)
- Get Ticket details
- List all OPEN Tickets in a Family (via GSI)
- Assign, resolve, and close Tickets
- Enforce reopen window rules

### Comments
- List comments for a Ticket
- Add new comments

### Auditing
- Retrieve audit history for an entity
- (Optional) retrieve all audits in a Family by time range

---

## Global Secondary Indexes

### GSI1 — Families by User

Used for home/dashboard views.

gsi1_pk = USER#{user_id}
gsi1_sk = FAMILY#{family_id}#STATUS#{status}

Applied to:
- Family Membership items

---

### GSI2 — Tickets by Family and Status

Used for Family-wide dashboards.

gsi2_pk = FAMILY#{family_id}#TICKETS
gsi2_sk = STATUS#{status}#CREATED#{creation_date}#SEV#{severity}#ID#{ticket_id}

Applied to:
- Ticket items

---

## Notes for PynamoDB Generation

- All models inherit from the shared base model
- Each entity should define deterministic key factories
- Enums should be constrained strings
- Audit records must never be updated or deleted
- Prefer explicit attributes over inferred meaning