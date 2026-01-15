import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetAllGroups = (familyId, enabled = true) => {
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
    queryKey: ["groups", "all", familyId],
    queryFn: () => apiRequestGet(apiEndpoint, `/group/${familyId}`, idToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 5,
    cacheTime: 1000 * 60 * 15,
  });

  return {
    groups: data?.data?.groups || [],
    isGroupsFetching: isFetching,
    isGroupsError: isError,
    groupsStatus: status,
    groupsError: error,
    groupsRefetch: refetch,
  };
};

export default useGetAllGroups;
