import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetMyGroups = (familyId, enabled = true) => {
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
    queryKey: ["groups", "mine", familyId],
    queryFn: () =>
      apiRequestGet(apiEndpoint, `/group/${familyId}/mine`, idToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 5,
    cacheTime: 1000 * 60 * 15,
  });

  return {
    myGroups: data?.data?.groups || {},
    isMyGroupsFetching: isFetching,
    isMyGroupsError: isError,
    myGroupsStatus: status,
    myGroupsError: error,
    myGroupsRefetch: refetch,
  };
};

export default useGetMyGroups;
