import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetUnreadNotificationsCount = (enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled && !!idToken && typeof idToken === "string" && idToken.length > 0,
    [enabled, idToken],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["unreadNotificationsCount"],
    queryFn: () => apiRequestGet(apiEndpoint, "/notifications/unread", idToken),
    enabled: isEnabled,
    refetchInterval: 1000 * 60 * 2, // Refetch every 2 minutes
    staleTime: 1000 * 60, // 1 minute
    cacheTime: 1000 * 60 * 5, // 5 minutes
  });

  return {
    unreadCount: data?.data?.unread_count || 0,
    isUnreadCountFetching: isFetching,
    isUnreadCountError: isError,
    unreadCountStatus: status,
    unreadCountError: error,
    unreadCountRefetch: refetch,
  };
};

export default useGetUnreadNotificationsCount;
