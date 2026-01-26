# Standardized Error Response Format

## Overview

All API endpoints now use a standardized error response format to provide consistent error handling across the application.

## Error Response Structure

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

## HTTP Status Codes

### 4XX Client Errors

#### 400 Bad Request
- `INVALID_USER_ID` - Invalid or missing user ID
- `INVALID_GROUP_DATA` - Invalid group data provided
- `GROUP_FAMILY_MISMATCH` - Group does not belong to specified family
- `INVALID_INPUT_LENGTH` - Input exceeds maximum allowed length
- `MEMBERSHIP_PENDING_REQUIRED` - Operation requires pending membership
- `MEMBERSHIP_ACTIVE_REQUIRED` - Operation requires active membership

#### 401 Unauthorized
- `INVALID_JWT` - Invalid JWT token
- `EXPIRED_JWT` - JWT token has expired
- `MISSING_JWT` - JWT token is missing

#### 403 Forbidden
- `ACCESS_DENIED` - Insufficient permissions
- `GROUP_PERMISSION_DENIED` - Permission denied for group operation
- `ADMIN_PRIVILEGES_REQUIRED` - Admin privileges required
- `MEMBER_PRIVILEGES_REQUIRED` - Member privileges required

#### 404 Not Found
- `USER_NOT_FOUND` - User not found
- `GROUP_NOT_FOUND` - Group not found
- `FAMILY_NOT_FOUND` - Family not found
- `MEMBERSHIP_NOT_FOUND` - Membership not found

#### 409 Conflict
- `GROUP_ALREADY_EXISTS` - Group already exists
- `GROUP_HAS_ACTIVE_QUEUES` - Cannot delete group with active queues
- `MEMBERSHIP_ALREADY_EXISTS` - User already a member
- `MEMBERSHIP_REQUEST_PENDING` - Pending request already exists

### 5XX Server Errors

#### 500 Internal Server Error
- `INTERNAL_SERVER_ERROR` - Internal server error
- `UNEXPECTED_ERROR` - An unexpected error occurred

## Group-Specific Error Codes

### Group Operations
- `GROUP_NOT_FOUND` - Group not found or does not exist
- `GROUP_ALREADY_EXISTS` - Attempting to create a group that already exists
- `INVALID_GROUP_DATA` - Invalid group data provided (empty name, invalid characters, etc.)
- `GROUP_FAMILY_MISMATCH` - Group does not belong to the specified family
- `GROUP_PERMISSION_DENIED` - User lacks permission to perform group operation
- `GROUP_HAS_ACTIVE_QUEUES` - Cannot delete group that has active queues
- `INVALID_INPUT_LENGTH` - Group name or description exceeds maximum length
- `FAMILY_NOT_FOUND` - Family not found or does not exist

## Queue-Specific Error Codes

### Queue Operations
- `QUEUE_NOT_FOUND` - Queue not found or does not exist
- `QUEUE_ALREADY_EXISTS` - Attempting to create a queue that already exists
- `INVALID_QUEUE_DATA` - Invalid queue data provided (empty name, invalid characters, etc.)
- `QUEUE_GROUP_MISMATCH` - Queue does not belong to the specified group
- `QUEUE_PERMISSION_DENIED` - User lacks permission to perform queue operation
- `QUEUE_HAS_ACTIVE_TICKETS` - Cannot delete queue that has active tickets
- `INVALID_INPUT_LENGTH` - Queue name or description exceeds maximum length

## Validation Rules

### Group Name Validation
- Required and cannot be empty
- Maximum length: 100 characters
- Cannot contain: `<`, `>`, `&`, `"`, `'`

### Group Description Validation
- Optional field
- Maximum length: 500 characters

### Queue Name Validation
- Required and cannot be empty
- Maximum length: 100 characters
- Cannot contain: `<`, `>`, `&`, `"`, `'`

### Queue Description Validation
- Optional field
- Maximum length: 500 characters

### Family Validation
- Family ID is required for all group and queue operations
- Family must exist before group or queue operations can be performed

### Queue-Group Relationship Validation
- Queue must belong to the specified group
- Group must exist before queue operations can be performed
- Queue operations validate group-family relationships

## Implementation Details

### Exception Hierarchy
All group and queue exceptions inherit from Python's base `Exception` class and follow the pattern:

```python
class GroupException(Exception):
    def __init__(self, message: str = "Default message"):
        self.message = message
        super().__init__(self.message)

class QueueException(Exception):
    def __init__(self, message: str = "Default message"):
        self.message = message
        super().__init__(self.message)
```

### Validation Helper
The `GroupValidationHelper` class provides centralized validation logic:
- `validate_group_name()` - Validates group name format and length
- `validate_group_description()` - Validates group description length
- `validate_family_exists()` - Ensures family exists
- `validate_group_family_relationship()` - Validates group-family relationship
- `validate_create_group_data()` - Comprehensive validation for group creation
- `validate_update_group_data()` - Comprehensive validation for group updates
- `validate_group_operation()` - General validation for group operations

The `QueueValidationHelper` class provides centralized validation logic:
- `validate_queue_name()` - Validates queue name format and length
- `validate_queue_description()` - Validates queue description length
- `validate_family_exists()` - Ensures family exists
- `validate_group_exists()` - Ensures group exists in family
- `validate_queue_exists()` - Ensures queue exists in group
- `validate_create_queue_data()` - Comprehensive validation for queue creation
- `validate_update_queue_data()` - Comprehensive validation for queue updates
- `validate_queue_operation()` - General validation for queue operations

### Exception Decorator
The `@exceptions_decorator` automatically catches and converts exceptions to standardized JSON responses with appropriate HTTP status codes.

## Migration Notes

### Breaking Changes
- Error responses now use `{"error": {"code": "...", "message": "..."}}` format instead of `{"message": "..."}`
- Some error messages may have changed to be more descriptive
- HTTP status codes are now more consistent and specific
- Queue endpoints now use standardized error handling with proper HTTP status codes
- Queue validation errors now use specific error codes instead of generic messages

### Backward Compatibility
- All existing endpoints continue to work
- Error handling is more robust and consistent
- Better error messages for debugging and user experience
- Queue operations now have comprehensive validation and error handling
- Queue-group relationship validation is enforced consistently