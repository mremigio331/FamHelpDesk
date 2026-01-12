import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for reviewing group membership requests (admin only)
 * Allows group admins to approve or reject membership requests
 */
const useReviewGroupMembership = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId, targetUserId, approve }) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/${groupId}/review`,
        accessToken,
        body: {
          target_user_id: targetUserId,
          approve: approve,
        },
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
      // Invalidate groups queries as membership changes may affect group access
      queryClient.invalidateQueries({ queryKey: ["groups"] });
    },
    onError: (error) => {
      console.error("Failed to review membership request:", error);
    },
  });

  // Helper functions for easier usage
  const approveMembership = (familyId, groupId, targetUserId) => {
    return mutation.mutate({ familyId, groupId, targetUserId, approve: true });
  };

  const rejectMembership = (familyId, groupId, targetUserId) => {
    return mutation.mutate({ familyId, groupId, targetUserId, approve: false });
  };

  const approveMembershipAsync = (familyId, groupId, targetUserId) => {
    return mutation.mutateAsync({
      familyId,
      groupId,
      targetUserId,
      approve: true,
    });
  };

  const rejectMembershipAsync = (familyId, groupId, targetUserId) => {
    return mutation.mutateAsync({
      familyId,
      groupId,
      targetUserId,
      approve: false,
    });
  };

  return {
    reviewMembership: mutation.mutate,
    reviewMembershipAsync: mutation.mutateAsync,
    approveMembership,
    rejectMembership,
    approveMembershipAsync,
    rejectMembershipAsync,
    isReviewingMembership: mutation.isPending,
    isReviewError: mutation.isError,
    reviewError: mutation.error,
    isReviewSuccess: mutation.isSuccess,
    reviewedMembership: mutation.data?.data?.membership || null,
    resetReviewState: mutation.reset,
  };
};

export default useReviewGroupMembership;
