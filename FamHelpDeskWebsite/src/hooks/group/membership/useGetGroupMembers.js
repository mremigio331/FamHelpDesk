import { useQuery } from "@tanstack/react-query";
import { useContext, useMemo } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestGet } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for getting all members of a group
 * Returns member list with user details and roles
 */
const useGetGroupMembers = (familyId, groupId, enabled = true) => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const isEnabled = useMemo(
    () =>
      enabled &&
      !!accessToken &&
      typeof accessToken === "string" &&
      accessToken.length > 0 &&
      !!familyId &&
      !!groupId,
    [enabled, accessToken, familyId, groupId],
  );

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["groupMembers", familyId, groupId],
    queryFn: () =>
      apiRequestGet(
        apiEndpoint,
        `/membership/${familyId}/${groupId}/members`,
        accessToken,
      ),
    enabled: isEnabled,
    keepPreviousData: true,
    staleTime: 1000 * 60 * 5, // 5 minutes
    cacheTime: 1000 * 60 * 15, // 15 minutes
  });

  return {
    members: data?.data?.members || [],
    memberCount: data?.data?.count || 0,
    isFetchingMembers: isFetching,
    isMembersError: isError,
    membersError: error,
    refetchMembers: refetch,
  };
};

export default useGetGroupMembers;
