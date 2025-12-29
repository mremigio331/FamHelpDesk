import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetMyGroups = (enabled = true) => {
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
    queryKey: ["groups", "mine"],
    queryFn: () => apiRequestGet(apiEndpoint, "/group/mine", accessToken),
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
