import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetUserProfileById = (userId, enabled = true) => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!accessToken &&
      typeof accessToken === "string" &&
      accessToken.length > 0 &&
      !!userId,
    [enabled, accessToken, userId],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["userProfile", userId],
    queryFn: () =>
      apiRequestGet(apiEndpoint, `/user/profile/${userId}`, accessToken),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 10,
    cacheTime: 1000 * 60 * 30,
  });

  return {
    userProfile: data?.data?.user_profile || null,
    isUserFetching: isFetching,
    isUserError: isError,
    userStatus: status,
    userError: error,
    userRefetch: refetch,
  };
};

export default useGetUserProfileById;
