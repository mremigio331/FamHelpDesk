import os

STAGE = os.getenv("STAGE", "dev").lower()
API_METRICS_NAMESPACE = f"FamHelpDesk-{STAGE.upper()}"


ENDPOINT = "Endpoint"
REQUEST_MEMORY_ALLOCATED_KB = "RequestMemoryAllocatedKB"
REQUEST_MEMORY_FREED_KB = "RequestMemoryFreedKB"

# Order Metrics Constants
ORDER_CREATED_METRIC = "OrderCreated"
ORDER_CONFIRMED_METRIC = "OrderConfirmed"
ITEM_CONFIRMED_METRIC = "ItemConfirmed"
FAMILY_ID_DIMENSION = "FamilyId"

# Ticket Metrics Constants
TICKET_CREATED_METRIC = "TicketCreated"
TICKET_RESOLVED_METRIC = "TicketResolved"
TICKET_COMMENT_METRIC = "TicketComment"
TICKET_STATUS_CHANGED_METRIC = "TicketStatusChanged"

# APNs Client Constants
APNS_SEND_NOTIFICATION = "APNsSendNotification"
APNS_SUCCESS = "APNsSuccess"
APNS_EXCEPTION = "APNsException"
ENVIRONMENT_DIMENSION = "Environment"
