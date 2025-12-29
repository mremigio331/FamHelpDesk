import { useInfiniteQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetNotifications = (limit = 50, viewed = null, enabled = true) => {
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

  const {
    data,
    isFetching,
    isError,
    status,
    error,
    refetch,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ["notifications", limit, viewed],
    queryFn: ({ pageParam = null }) => {
      let url = `/notifications?limit=${limit}`;
      if (viewed !== null) {
        url += `&viewed=${viewed}`;
      }
      if (pageParam) {
        url += `&next_token=${encodeURIComponent(pageParam)}`;
      }
      return apiRequestGet(apiEndpoint, url, accessToken);
    },
    enabled: isEnabled,
    getNextPageParam: (lastPage) => {
      // Return the next_token if it exists, otherwise return undefined to stop pagination
      return lastPage?.data?.next_token || undefined;
    },
    staleTime: 1000 * 60 * 5, // 5 minutes
    cacheTime: 1000 * 60 * 30, // 30 minutes
  });

  // Flatten all pages of notifications into a single array
  const notifications = useMemo(() => {
    if (!data?.pages) return [];
    return data.pages.flatMap((page) => page.data.notifications || []);
  }, [data]);

  const totalCount = useMemo(() => {
    if (!data?.pages) return 0;
    return data.pages.reduce((acc, page) => acc + (page.data.count || 0), 0);
  }, [data]);

  return {
    notifications,
    totalCount,
    isNotificationsFetching: isFetching,
    isNotificationsError: isError,
    notificationsStatus: status,
    notificationsError: error,
    notificationsRefetch: refetch,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  };
};

export default useGetNotifications;
