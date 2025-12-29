import { useState, useCallback, useMemo } from "react";
import useGetNotifications from "../../hooks/notifications/useGetNotifications";
import useAcknowledgeNotification from "../../hooks/notifications/useAcknowledgeNotification";
import useAcknowledgeAllNotifications from "../../hooks/notifications/useAcknowledgeAllNotifications";

const useNotificationsPage = () => {
  const [showAll, setShowAll] = useState(false);

  // Fetch notifications based on filter
  const {
    notifications,
    totalCount,
    isNotificationsFetching,
    isNotificationsError,
    notificationsError,
    notificationsRefetch,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useGetNotifications(50, showAll ? null : false, true);

  const {
    acknowledgeNotification,
    isAcknowledging,
    isAcknowledgeError,
    acknowledgeError,
  } = useAcknowledgeNotification();

  const {
    acknowledgeAllNotifications,
    isAcknowledgingAll,
    isAcknowledgeAllError,
    acknowledgeAllError,
  } = useAcknowledgeAllNotifications();

  const handleToggleShowAll = useCallback(() => {
    setShowAll((prev) => !prev);
  }, []);

  const handleAcknowledge = useCallback(
    (notificationId) => {
      acknowledgeNotification(notificationId);
    },
    [acknowledgeNotification],
  );

  const handleAcknowledgeAll = useCallback(() => {
    acknowledgeAllNotifications();
  }, [acknowledgeAllNotifications]);

  const handleLoadMore = useCallback(() => {
    if (hasNextPage && !isFetchingNextPage) {
      fetchNextPage();
    }
  }, [hasNextPage, isFetchingNextPage, fetchNextPage]);

  return {
    notifications,
    totalCount,
    showAll,
    isNotificationsFetching,
    isNotificationsError,
    notificationsError,
    notificationsRefetch,
    handleToggleShowAll,
    handleAcknowledge,
    isAcknowledging,
    isAcknowledgeError,
    acknowledgeError,
    handleAcknowledgeAll,
    isAcknowledgingAll,
    isAcknowledgeAllError,
    acknowledgeAllError,
    handleLoadMore,
    hasNextPage,
    isFetchingNextPage,
  };
};

export default useNotificationsPage;
