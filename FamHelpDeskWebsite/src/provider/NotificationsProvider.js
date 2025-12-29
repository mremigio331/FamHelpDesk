import React, { createContext, useContext, useMemo } from "react";
import useGetUnreadNotificationsCount from "../hooks/notifications/useGetUnreadNotificationsCount";
import { UserAuthenticationContext } from "./UserAuthenticationProvider";

export const NotificationsContext = createContext();

const NotificationsProvider = ({ children }) => {
  const { isAuthenticated } = useContext(UserAuthenticationContext);

  // Only fetch unread count when user is authenticated
  const {
    unreadCount,
    isUnreadCountFetching,
    isUnreadCountError,
    unreadCountRefetch,
  } = useGetUnreadNotificationsCount(isAuthenticated === true);

  console.log(unreadCount, isUnreadCountFetching);

  const value = useMemo(
    () => ({
      unreadCount,
      isUnreadCountFetching,
      isUnreadCountError,
      unreadCountRefetch,
    }),
    [
      unreadCount,
      isUnreadCountFetching,
      isUnreadCountError,
      unreadCountRefetch,
    ],
  );

  return (
    <NotificationsContext.Provider value={value}>
      {children}
    </NotificationsContext.Provider>
  );
};

export const useNotifications = () => {
  const context = useContext(NotificationsContext);
  if (context === undefined) {
    throw new Error(
      "useNotifications must be used within a NotificationsProvider",
    );
  }
  return context;
};

export default NotificationsProvider;
