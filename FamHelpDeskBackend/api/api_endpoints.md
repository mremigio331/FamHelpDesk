# Fam Help Desk API Endpoints

This document lists all API endpoints needed to fulfill the Fam Help Desk system requirements.

## Status Legend
- ✅ **CREATED** - Endpoint implemented and working
- 🔨 **IN_PROGRESS** - Currently being developed
- ⏳ **PENDING** - Not yet started
- ❌ **NOT IMPLEMENTED** - Intentionally not implemented for safety/security reasons

---

## Authentication & User Management

### User Profile
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | GET | `/user/profile/{user_id}` | Get a user's profile |
| ✅ CREATED | PUT | `/user/profile` | Update current user's profile |
| ✅ CREATED | GET | `/user/requester` | Get requester info (user ID from token) |

---

## Family Management

### Family CRUD
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | POST | `/family` | Create a new family (auto-creates default group & queue) |
| ✅ CREATED | GET | `/family/{family_id}` | Get family details |
| ✅ CREATED | PUT | `/family/{family_id}` | Update family details (name, description) |
| ❌ NOT IMPLEMENTED | DELETE | `/family/{family_id}` | Delete a family (admin only, must be empty) |
| ✅ CREATED | GET | `/family` | Get all families |

### Family Membership
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | GET | `/family/my-families` | Get all families the current user is a member of |
| ✅ CREATED | POST | `/membership/family/{family_id}/request` | Request membership to a family |
| ✅ CREATED | PUT | `/membership/family/{family_id}/review` | Review family membership request (admin only) |
| ⏳ PENDING | GET | `/family/{family_id}/members` | Get all members in a family |
| ⏳ PENDING | POST | `/family/{family_id}/members` | Invite a user to join the family |
| ⏳ PENDING | DELETE | `/family/{family_id}/members/{user_id}` | Remove a member from the family |
| ⏳ PENDING | GET | `/family/{family_id}/members/pending` | Get pending family invitations |

### Family Notification Settings
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | GET | `/family/{family_id}/notification-settings` | Get notification settings for current user in this family |
| ✅ CREATED | PUT | `/family/{family_id}/notification-settings` | Update notification settings for current user in this family |

---

## Group Management

### Group CRUD
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | POST | `/group/{family_id}` | Create a new group (auto-creates default queue) |
| ✅ CREATED | GET | `/group/{family_id}` | Get all groups in a family |
| ✅ CREATED | GET | `/group/{family_id}/my-groups` | Get groups the current user is a member of |
| ⏳ PENDING | GET | `/group/{family_id}/{group_id}` | Get group details |
| ⏳ PENDING | PUT | `/group/{family_id}/{group_id}` | Update group details (name, description) |
| ⏳ PENDING | DELETE | `/group/{family_id}/{group_id}` | Delete a group (admin only, must have no queues or all queues empty) |

### Group Membership
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | POST | `/membership/{family_id}/group/{group_id}/request` | Request membership to a group |
| ✅ CREATED | PUT | `/membership/{family_id}/group/{group_id}/review` | Review group membership request (admin only) |
| ⏳ PENDING | GET | `/group/{family_id}/{group_id}/members` | Get all members in a group |
| ⏳ PENDING | POST | `/group/{family_id}/{group_id}/members` | Add a member to the group |
| ⏳ PENDING | PUT | `/group/{family_id}/{group_id}/members/{user_id}` | Update member role (promote/demote admin) |
| ⏳ PENDING | DELETE | `/group/{family_id}/{group_id}/members/{user_id}` | Remove a member from the group |

---

## Queue Management

### Queue CRUD
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | POST | `/queue/{family_id}/{group_id}` | Create a new queue in a group |
| ⏳ PENDING | GET | `/queue/{family_id}/{group_id}` | Get all queues for a group |
| ⏳ PENDING | GET | `/queue/{family_id}` | Get all queues across all groups in a family |
| ⏳ PENDING | GET | `/queue/{family_id}/{group_id}/{queue_id}` | Get queue details |
| ⏳ PENDING | PUT | `/queue/{family_id}/{group_id}/{queue_id}` | Update queue details (name, description) |
| ⏳ PENDING | DELETE | `/queue/{family_id}/{group_id}/{queue_id}` | Delete a queue (admin only, must be empty or all tickets closed) |

---

## Ticket Management

### Ticket CRUD
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | POST | `/ticket/{family_id}/{queue_id}` | Create a new ticket |
| ⏳ PENDING | GET | `/ticket/{family_id}/{queue_id}` | Get all tickets in a queue |
| ⏳ PENDING | GET | `/ticket/{family_id}` | Get all tickets in a family (with filtering) |
| ⏳ PENDING | GET | `/ticket/{family_id}/{queue_id}/{ticket_id}` | Get ticket details |
| ⏳ PENDING | PUT | `/ticket/{family_id}/{queue_id}/{ticket_id}` | Update ticket (title, description, severity, assigned_to) |
| ⏳ PENDING | DELETE | `/ticket/{family_id}/{queue_id}/{ticket_id}` | Delete a ticket (admin only) |

### Ticket Status Management
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | PUT | `/ticket/{family_id}/{queue_id}/{ticket_id}/assign` | Assign ticket to a user |
| ⏳ PENDING | PUT | `/ticket/{family_id}/{queue_id}/{ticket_id}/resolve` | Mark ticket as resolved |
| ⏳ PENDING | PUT | `/ticket/{family_id}/{queue_id}/{ticket_id}/close` | Close a ticket |
| ⏳ PENDING | PUT | `/ticket/{family_id}/{queue_id}/{ticket_id}/reopen` | Reopen a ticket (within 30 days of resolution) |

### Ticket Filtering & Search
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | GET | `/ticket/{family_id}/search?q={query}` | Search tickets by title/description |
| ⏳ PENDING | GET | `/ticket/{family_id}/my-tickets` | Get tickets assigned to current user |
| ⏳ PENDING | GET | `/ticket/{family_id}/open` | Get all open tickets in a family |

---

## Comment Management

### Comments
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | POST | `/comment/{family_id}/{queue_id}/{ticket_id}` | Add a comment to a ticket |
| ⏳ PENDING | GET | `/comment/{family_id}/{queue_id}/{ticket_id}` | Get all comments for a ticket |
| ⏳ PENDING | PUT | `/comment/{family_id}/{queue_id}/{ticket_id}/{comment_id}` | Update a comment |
| ⏳ PENDING | DELETE | `/comment/{family_id}/{queue_id}/{ticket_id}/{comment_id}` | Delete a comment |

---

## Audit & History

### Audit Trails
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | GET | `/audit/{family_id}` | Get audit history for a family |
| ⏳ PENDING | GET | `/audit/{family_id}/{entity_type}/{entity_id}` | Get audit history for a specific entity |
| ⏳ PENDING | GET | `/user/audit` | Get user profile audit history |

---

## Notifications

### User Notifications
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ✅ CREATED | GET | `/notifications` | Get all notifications for the current user (requester) |
| ✅ CREATED | PUT | `/notifications/{notification_id}/acknowledge` | Acknowledge a notification (user can only acknowledge their own) |
| ✅ CREATED | PUT | `/notifications/acknowledge-all` | Acknowledge all notifications for the current user |
| ✅ CREATED | GET | `/notifications/unread` | Get unread notifications count for the current user |

---

## Dashboard & Analytics (Optional/Future)

### Statistics
| Status | Method | Path | Description |
|--------|--------|------|-------------|
| ⏳ PENDING | GET | `/stats/{family_id}` | Get family-wide statistics (ticket counts, etc.) |
| ⏳ PENDING | GET | `/stats/{family_id}/{group_id}` | Get group statistics |
| ⏳ PENDING | GET | `/stats/{family_id}/{queue_id}` | Get queue statistics |

## Summary
### Current Status
- **Created**: 20 endpoints
- **Pending**: 51 endpoints
- **Not Implemented**: 1 endpoint (family deletion for safety)

### Priority Order (Recommended Implementation)
1. **Family endpoints** (GET, PUT, DELETE family)
### Priority Order (Recommended Implementation)
1. **Family endpoints** (GET, PUT, DELETE family)
2. **Queue endpoints** (CRUD operations)
3. **Ticket endpoints** (CRUD and status management)
4. **Comment endpoints** (CRUD)
5. **Membership endpoints** (family and group members)
6. **Notifications endpoints** (get notifications, acknowledge)
7. **Search & filtering** (ticket search, my tickets, open tickets)
8. **Audit endpoints** (audit history)
9. **Statistics/Dashboard** (analytics)
Based on the UI doc requirements, the most critical endpoints to implement next are:
1. `GET /queue/{family_id}/{group_id}` - For populating queue dropdown when creating tickets
2. `POST /ticket/{family_id}/{queue_id}` - For creating tickets
3. `GET /family/{family_id}/members` - For populating assign-to dropdown
4. `GET /ticket/{family_id}` - For displaying ticket lists with filters
