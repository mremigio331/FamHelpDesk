class MembershipNotFound(Exception):
    def __init__(self, message: str = "Membership not found."):
        super().__init__(message)


class MembershipAlreadyExistsAsMember(Exception):
    def __init__(self, message: str = "User is already a member of the family."):
        super().__init__(message)


class MembershipRequestPendingExists(Exception):
    def __init__(self, message: str = "A pending membership request already exists."):
        super().__init__(message)


class MembershipPendingRequired(Exception):
    def __init__(
        self, message: str = "Operation requires a pending membership request."
    ):
        super().__init__(message)


class MembershipActiveRequired(Exception):
    def __init__(self, message: str = "Operation requires an active membership."):
        super().__init__(message)


class AdminPrivilegesRequired(Exception):
    def __init__(self, message: str = "Only admins can perform this action."):
        super().__init__(message)


class MemberPrivilegesRequired(Exception):
    def __init__(self, message: str = "Only active members can perform this action."):
        super().__init__(message)
