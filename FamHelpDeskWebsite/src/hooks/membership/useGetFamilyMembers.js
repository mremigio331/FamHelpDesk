import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useGetFamilyMembers = (familyId, enabled = true) => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!accessToken &&
      typeof accessToken === "string" &&
      accessToken.length > 0 &&
      !!familyId,
    [enabled, accessToken, familyId],
  );

  const { data, isFetching, isError, status, error, refetch } = useQuery({
    queryKey: ["familyMembers", familyId],
    queryFn: () =>
      apiRequestGet(
        apiEndpoint,
        `/membership/${familyId}/members`,
        accessToken,
      ),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 5, // 5 minutes
    cacheTime: 1000 * 60 * 30, // 30 minutes
  });

  return {
    members: data?.data?.members || [],
    memberCount: data?.data?.count || 0,
    isFetchingMembers: isFetching,
    isMembersError: isError,
    membersStatus: status,
    membersError: error,
    membersRefetch: refetch,
  };
};

export default useGetFamilyMembers;
