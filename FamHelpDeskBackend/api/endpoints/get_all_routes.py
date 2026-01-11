from api.endpoints.fam_help_desk import home
from api.endpoints.user import get_requester, get_user_profile, update_user_profile
from api.endpoints.family import (
    create_family,
    get_all_families,
    get_my_families,
    get_family,
    update_family,
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
from api.endpoints.membership.family_membership import (
    family_request_membership,
    family_review_membership,
    get_family_membership_requests,
    get_family_members,
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
from constants.api import (
    HOME_TAG,
    HOME_PATH,
    USER_PATH,
    USER_TAG,
    FAMILY_TAG,
    FAMILY_PATH,
    GROUP_TAG,
    GROUP_PATH,
    QUEUE_TAG,
    QUEUE_PATH,
    GROUP_MEMBERSHIP_TAG,
    FAMILY_MEMBERSHIP_TAG,
    MEMBERSHIP_PATH,
    NOTIFICATIONS_TAG,
    NOTIFICATIONS_PATH,
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
    app.include_router(home.router, prefix=HOME_PATH, tags=[HOME_TAG])

    app.include_router(get_requester.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(get_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(update_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])

    app.include_router(create_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_all_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_my_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(update_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])

    app.include_router(create_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(get_all_groups.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(get_my_groups.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(update_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])
    app.include_router(delete_group.router, prefix=GROUP_PATH, tags=[GROUP_TAG])

    app.include_router(create_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(get_queues.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(get_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(update_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])
    app.include_router(delete_queue.router, prefix=QUEUE_PATH, tags=[QUEUE_TAG])

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

    return app
