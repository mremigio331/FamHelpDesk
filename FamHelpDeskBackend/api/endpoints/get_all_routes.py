from api.endpoints.fam_help_desk import home
from api.endpoints.user import (
    get_requester,
    get_user_profile,
    update_user_profile,
    delete_user_profile,
)
from api.endpoints.family import (
    create_family,
    get_all_families,
    get_my_families,
    get_family,
    update_family,
)
from api.endpoints.family.get_family_notification_settings import (
    router as get_family_notification_settings_router,
)
from api.endpoints.family.update_family_notification_settings import (
    router as update_family_notification_settings_router,
)
from api.endpoints.group import (
    create_group,
    get_all_groups,
    get_my_groups,
    update_group,
    delete_group,
)
from api.endpoints.queue import (
    create_queue,
    get_queues,
    get_queue,
    update_queue,
    delete_queue,
)
from api.endpoints.ticket.create_ticket import router as create_ticket_router
from api.endpoints.ticket.update_ticket import router as update_ticket_router
from api.endpoints.ticket.get_ticket import router as get_ticket_router
from api.endpoints.ticket.get_tickets import router as get_tickets_router
from api.endpoints.ticket.create_comment import router as create_comment_router
from api.endpoints.ticket.update_comment import router as update_comment_router
from api.endpoints.ticket.delete_comment import router as delete_comment_router
from api.endpoints.ticket.get_comments import router as get_comments_router
from api.endpoints.membership.family_membership import (
    family_request_membership,
    family_review_membership,
    get_family_membership_requests,
    get_family_members,
    get_active_members,
    update_family_member_role,
    remove_family_member,
)
from api.endpoints.membership.group_membership import (
    group_request_membership,
    group_review_membership,
    get_group_membership_requests,
    get_group_members,
    add_group_member,
    remove_group_member,
    update_group_member_role,
    get_group_members_with_roles,
)
from api.endpoints.notifications import (
    get_notifications,
    get_unread_count,
    acknowledge_notification,
    acknowledge_all,
)
from api.endpoints.notifications.get_settings import router as get_settings_router
from api.endpoints.notifications.update_settings import router as update_settings_router
from api.endpoints.devices.register_device import router as register_device_router
from api.endpoints.devices.unregister_device import router as unregister_device_router
from api.endpoints.devices.get_device import router as get_device_router
from api.endpoints.devices.enable_device import router as enable_device_router
from api.endpoints.devices.disable_device import router as disable_device_router
from api.endpoints.grab.get_balance import router as grab_get_balance_router
from api.endpoints.grab.create_request import router as grab_create_request_router
from api.endpoints.grab.get_request import router as grab_get_request_router
from api.endpoints.grab.list_requests import router as grab_list_requests_router
from api.endpoints.grab.claim_request import router as grab_claim_request_router
from api.endpoints.grab.complete_request import router as grab_complete_request_router
from api.endpoints.grab.confirm_request import router as grab_confirm_request_router
from api.endpoints.grab.cancel_request import router as grab_cancel_request_router
from api.endpoints.grab.claim_items import router as grab_claim_items_router
from api.endpoints.grab.complete_items import router as grab_complete_items_router
from api.endpoints.grab.confirm_items import router as grab_confirm_items_router
from api.endpoints.grab.cancel_items import router as grab_cancel_items_router
from api.endpoints.grab.upload_photo_url import router as grab_upload_photo_url_router
from api.endpoints.grab.upload_pickup_photo_url import (
    router as grab_upload_pickup_photo_url_router,
)
from api.endpoints.grab.save_pickup_photo import (
    router as grab_save_pickup_photo_router,
)
from api.endpoints.grab.get_photo_url import router as grab_get_photo_url_router
from api.endpoints.grab.get_pickup_photo_url import (
    router as grab_get_pickup_photo_url_router,
)
from api.endpoints.grab.get_leaderboard import router as grab_get_leaderboard_router
from api.endpoints.grab.get_transactions import router as grab_get_transactions_router
from api.endpoints.grab.submit_reviews import router as grab_submit_reviews_router
from api.endpoints.grab.get_review_profile import (
    router as grab_get_review_profile_router,
)
from constants.api import (
    GRAB_PATH,
    GRAB_TAG,
    DEVICES_PATH,
    DEVICES_TAG,
    FAMILY_MEMBERSHIP_TAG,
    FAMILY_PATH,
    FAMILY_TAG,
    GROUP_MEMBERSHIP_TAG,
    GROUP_PATH,
    GROUP_TAG,
    HOME_PATH,
    HOME_TAG,
    MEMBERSHIP_PATH,
    NOTIFICATIONS_PATH,
    NOTIFICATIONS_TAG,
    QUEUE_PATH,
    QUEUE_TAG,
    TICKET_COMMENTS_TAG,
    TICKET_PATH,
    TICKET_TAG,
    USER_PATH,
    USER_TAG,
)
from fastapi import FastAPI


def get_all_routes(app: FastAPI) -> FastAPI:
    """
    Registers all API routes with the FastAPI application.

    Args:
        app (FastAPI): The FastAPI application instance.

    Returns:
        FastAPI: The updated FastAPI application instance with all routes registered.
    """
    # Home routes
    app.include_router(home.router, prefix=HOME_PATH, tags=[HOME_TAG])

    # Family routes
    app.include_router(create_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_all_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_my_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(update_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])

    # Family Membership routes
    app.include_router(
        family_request_membership.router,
        prefix=MEMBERSHIP_PATH,
        tags=[FAMILY_MEMBERSHIP_TAG],
    )
    app.include_router(
        family_review_membership.router,
        prefix=MEMBERSHIP_PATH,
        tags=[FAMILY_MEMBERSHIP_TAG],
    )
    app.include_router(
        get_family_membership_requests.router,
        prefix=MEMBERSHIP_PATH,
        tags=[FAMILY_MEMBERSHIP_TAG],
    )
    app.include_router(
        get_family_members.router, prefix=MEMBERSHIP_PATH, tags=[FAMILY_MEMBERSHIP_TAG]
    )
    app.include_router(
        get_active_members.router, prefix=MEMBERSHIP_PATH, tags=[FAMILY_MEMBERSHIP_TAG]
    )
    app.include_router(
        update_family_member_role.router,
        prefix=MEMBERSHIP_PATH,
        tags=[FAMILY_MEMBERSHIP_TAG],
    )
    app.include_router(
        remove_family_member.router,
        prefix=MEMBERSHIP_PATH,
        tags=[FAMILY_MEMBERSHIP_TAG],
    )

    # Group routes
    app.include_router(create_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(get_all_groups.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(get_my_groups.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(update_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(delete_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])

    # Group Membership routes
    app.include_router(
        group_request_membership.router,
        prefix=MEMBERSHIP_PATH,
        tags=[GROUP_MEMBERSHIP_TAG],
    )
    app.include_router(
        group_review_membership.router,
        prefix=MEMBERSHIP_PATH,
        tags=[GROUP_MEMBERSHIP_TAG],
    )
    app.include_router(
        get_group_membership_requests.router,
        prefix=MEMBERSHIP_PATH,
        tags=[GROUP_MEMBERSHIP_TAG],
    )
    app.include_router(
        get_group_members.router, prefix=MEMBERSHIP_PATH, tags=[GROUP_MEMBERSHIP_TAG]
    )
    app.include_router(
        add_group_member.router, prefix=MEMBERSHIP_PATH, tags=[GROUP_MEMBERSHIP_TAG]
    )
    app.include_router(
        remove_group_member.router, prefix=MEMBERSHIP_PATH, tags=[GROUP_MEMBERSHIP_TAG]
    )
    app.include_router(
        update_group_member_role.router,
        prefix=MEMBERSHIP_PATH,
        tags=[GROUP_MEMBERSHIP_TAG],
    )
    app.include_router(
        get_group_members_with_roles.router,
        prefix=MEMBERSHIP_PATH,
        tags=[GROUP_MEMBERSHIP_TAG],
    )

    # Notifications routes
    app.include_router(
        get_notifications.router, prefix=NOTIFICATIONS_PATH, tags=[NOTIFICATIONS_TAG]
    )
    app.include_router(
        get_unread_count.router, prefix=NOTIFICATIONS_PATH, tags=[NOTIFICATIONS_TAG]
    )
    app.include_router(
        acknowledge_notification.router,
        prefix=NOTIFICATIONS_PATH,
        tags=[NOTIFICATIONS_TAG],
    )
    app.include_router(
        acknowledge_all.router, prefix=NOTIFICATIONS_PATH, tags=[NOTIFICATIONS_TAG]
    )
    app.include_router(
        get_settings_router, prefix=NOTIFICATIONS_PATH, tags=[NOTIFICATIONS_TAG]
    )
    app.include_router(
        update_settings_router, prefix=NOTIFICATIONS_PATH, tags=[NOTIFICATIONS_TAG]
    )
    app.include_router(
        get_family_notification_settings_router,
        prefix=FAMILY_PATH,
        tags=[FAMILY_TAG],
    )
    app.include_router(
        update_family_notification_settings_router,
        prefix=FAMILY_PATH,
        tags=[FAMILY_TAG],
    )

    # Queue routes
    app.include_router(create_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(get_queues.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(get_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(update_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(delete_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])

    # Ticket routes
    app.include_router(create_ticket_router, prefix=TICKET_PATH, tags=[TICKET_TAG])
    app.include_router(update_ticket_router, prefix=TICKET_PATH, tags=[TICKET_TAG])
    app.include_router(get_ticket_router, prefix=TICKET_PATH, tags=[TICKET_TAG])
    app.include_router(get_tickets_router, prefix=TICKET_PATH, tags=[TICKET_TAG])

    # Ticket Comments routes
    app.include_router(
        create_comment_router, prefix=TICKET_PATH, tags=[TICKET_COMMENTS_TAG]
    )
    app.include_router(
        update_comment_router, prefix=TICKET_PATH, tags=[TICKET_COMMENTS_TAG]
    )
    app.include_router(
        delete_comment_router, prefix=TICKET_PATH, tags=[TICKET_COMMENTS_TAG]
    )
    app.include_router(
        get_comments_router, prefix=TICKET_PATH, tags=[TICKET_COMMENTS_TAG]
    )

    # User routes
    app.include_router(get_requester.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(get_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(update_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(delete_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])

    # Devices routes
    app.include_router(register_device_router, prefix=DEVICES_PATH, tags=[DEVICES_TAG])
    app.include_router(
        unregister_device_router, prefix=DEVICES_PATH, tags=[DEVICES_TAG]
    )
    app.include_router(get_device_router, prefix=DEVICES_PATH, tags=[DEVICES_TAG])
    app.include_router(enable_device_router, prefix=DEVICES_PATH, tags=[DEVICES_TAG])
    app.include_router(disable_device_router, prefix=DEVICES_PATH, tags=[DEVICES_TAG])

    # FamGrab routes
    app.include_router(grab_get_balance_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_create_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_get_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_list_requests_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_claim_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_complete_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_confirm_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_cancel_request_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_claim_items_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_complete_items_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_confirm_items_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_cancel_items_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_upload_photo_url_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(
        grab_upload_pickup_photo_url_router, prefix=GRAB_PATH, tags=[GRAB_TAG]
    )
    app.include_router(grab_save_pickup_photo_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_get_photo_url_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(
        grab_get_pickup_photo_url_router, prefix=GRAB_PATH, tags=[GRAB_TAG]
    )
    app.include_router(grab_get_leaderboard_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_get_transactions_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(grab_submit_reviews_router, prefix=GRAB_PATH, tags=[GRAB_TAG])
    app.include_router(
        grab_get_review_profile_router, prefix=GRAB_PATH, tags=[GRAB_TAG]
    )

    return app
