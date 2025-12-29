import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetUnreadNotificationsCount = (enabled = true) => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!accessToken &&
      typeof accessToken === "string" &&
      accessToken.length > 0,
    [enabled, accessToken],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["unreadNotificationsCount"],
    queryFn: () =>
      apiRequestGet(apiEndpoint, "/notifications/unread", accessToken),
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
