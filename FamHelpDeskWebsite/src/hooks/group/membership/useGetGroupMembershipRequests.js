import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for getting pending membership requests for a group
 * Returns list of users who have requested to join the group
 */
const useGetGroupMembershipRequests = (familyId, groupId, enabled = true) => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!accessToken &&
      typeof accessToken === "string" &&
      accessToken.length > 0 &&
      !!familyId &&
      !!groupId,
    [enabled, accessToken, familyId, groupId],
  );

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["groupMembershipRequests", familyId, groupId],
    queryFn: () =>
      apiRequestGet(
        apiEndpoint,
        `/membership/${familyId}/${groupId}/requests`,
        accessToken,
      ),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 2, // 2 minutes (requests change more frequently)
    cacheTime: 1000 * 60 * 10, // 10 minutes
  });

  return {
    requests: data?.data?.requests || [],
    requestCount: data?.data?.count || 0,
    isFetchingRequests: isFetching,
    isRequestsError: isError,
    requestsError: error,
    refetchRequests: refetch,
  };
};

export default useGetGroupMembershipRequests;
