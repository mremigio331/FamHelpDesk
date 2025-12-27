import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetMyFamilies = (enabled = true) => {
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
    queryKey: ["families", "mine"],
    queryFn: () => apiRequestGet(apiEndpoint, "/family/mine", accessToken),
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
