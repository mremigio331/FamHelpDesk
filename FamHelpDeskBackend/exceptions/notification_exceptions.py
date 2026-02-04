class MissingNotificationArn(Exception):
    def __init__(self, message: str = "Missing the Notification arn."):
        super().__init__(message)
