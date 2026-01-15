import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

/**
 * Hook to fetch all queues for a specific group
 * @param {string} familyId - The family ID
 * @param {string} groupId - The group ID
 * @param {boolean} enabled - Whether the query should be enabled
 * @returns {Object} Query result with queues data and state
 */
const useGetQueues = (familyId, groupId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!idToken &&
      typeof idToken === "string" &&
      idToken.length > 0 &&
      !!familyId &&
      !!groupId,
    [enabled, idToken, familyId, groupId],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["queues", familyId, groupId],
    queryFn: () =>
      apiRequestGet(apiEndpoint, `/queue/${familyId}/${groupId}`, idToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 5, // 5 minutes
    cacheTime: 1000 * 60 * 15, // 15 minutes
  });

  return {
    queues: data?.data?.queues || [],
    isQueuesFetching: isFetching,
    isQueuesError: isError,
    queuesStatus: status,
    queuesError: error,
    queuesRefetch: refetch,
  };
};

export default useGetQueues;
