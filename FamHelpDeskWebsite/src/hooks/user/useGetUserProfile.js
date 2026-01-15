import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetUserProfile = (enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  console.log("idToken", idToken);
  console.log("apiEndpoint", apiEndpoint);
  const isEnabled = useMemo(
    () =>
      enabled && !!idToken && typeof idToken === "string" && idToken.length > 0,
    [enabled, idToken],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["userProfile"],
    queryFn: () => apiRequestGet(apiEndpoint, "/user/profile", idToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 10, // 10 minutes: prevents refetch if data is fresh
    cacheTime: 1000 * 60 * 30, // 30 minutes: keeps data in cache
  });

  return {
    userProfile: data?.data.user_profile || null,
    isUserFetching: isFetching,
    isUserError: isError,
    userStatus: status,
    userError: error,
    userRefetch: refetch,
  };
};

export default useGetUserProfile;
