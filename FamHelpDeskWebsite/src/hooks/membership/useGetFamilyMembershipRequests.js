import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetFamilyMembershipRequests = (familyId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!idToken &&
      typeof idToken === "string" &&
      idToken.length > 0 &&
      !!familyId,
    [enabled, idToken, familyId],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["familyMembershipRequests", familyId],
    queryFn: () =>
      apiRequestGet(apiEndpoint, `/membership/${familyId}/requests`, idToken),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 5, // 5 minutes
    cacheTime: 1000 * 60 * 30, // 30 minutes
  });

  return {
    requests: data?.data?.requests || [],
    requestCount: data?.data?.count || 0,
    isFetchingRequests: isFetching,
    isRequestsError: isError,
    requestsStatus: status,
    requestsError: error,
    requestsRefetch: refetch,
  };
};

export default useGetFamilyMembershipRequests;
