import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetMyFamilies = (enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled && !!idToken && typeof idToken === "string" && idToken.length > 0,
    [enabled, idToken],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["families", "mine"],
    queryFn: () => apiRequestGet(apiEndpoint, "/family/mine", idToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 5,
    cacheTime: 1000 * 60 * 15,
  });

  return {
    myFamilies: data?.data?.families || {},
    isMyFamiliesFetching: isFetching,
    isMyFamiliesError: isError,
    myFamiliesStatus: status,
    myFamiliesError: error,
    myFamiliesRefetch: refetch,
  };
};

export default useGetMyFamilies;
