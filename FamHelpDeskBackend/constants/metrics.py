import os

STAGE = os.getenv("STAGE", "dev").lower()
API_METRICS_NAMESPACE = f"FamHelpDesk-{STAGE.upper()}"


ENDPOINT = "Endpoint"
REQUEST_MEMORY_ALLOCATED_KB = "RequestMemoryAllocatedKB"
REQUEST_MEMORY_FREED_KB = "RequestMemoryFreedKB"

# APNs Client Constants
APNS_SEND_NOTIFICATION = "APNsSendNotification"
APNS_SUCCESS = "APNsSuccess"
APNS_EXCEPTION = "APNsException"
ENVIRONMENT_DIMENSION = "Environment"
