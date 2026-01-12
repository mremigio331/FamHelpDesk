import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for requesting membership to a group
 * Allows users to request to join a group
 */
const useRequestGroupMembership = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId }) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/${groupId}/request`,
        accessToken,
        body: {},
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({
        queryKey: [
          "groupMembershipRequests",
          variables.familyId,
          variables.groupId,
        ],
      });
      queryClient.invalidateQueries({
        queryKey: ["groupMembers", variables.familyId, variables.groupId],
      });
      // Also invalidate user's groups since they may now have access
      queryClient.invalidateQueries({ queryKey: ["groups", "mine"] });
    },
    onError: (error) => {
      console.error("Failed to request group membership:", error);
    },
  });

  return {
    requestMembership: mutation.mutate,
    requestMembershipAsync: mutation.mutateAsync,
    isRequestingMembership: mutation.isPending,
    isRequestError: mutation.isError,
    requestError: mutation.error,
    isRequestSuccess: mutation.isSuccess,
    requestedMembership: mutation.data?.data?.membership || null,
    resetRequestState: mutation.reset,
  };
};

export default useRequestGroupMembership;
