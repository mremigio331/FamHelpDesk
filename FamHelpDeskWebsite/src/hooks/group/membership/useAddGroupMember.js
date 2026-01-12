import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for adding members directly to a group (admin only)
 * Allows group admins to add users to the group without requiring a membership request
 */
const useAddGroupMember = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId, targetUserId, makeAdmin = false }) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/${groupId}/members`,
        accessToken,
        body: {
          target_user_id: targetUserId,
          make_admin: makeAdmin,
        },
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({
        queryKey: ["groupMembers", variables.familyId, variables.groupId],
      });
      queryClient.invalidateQueries({
        queryKey: [
          "groupMembershipRequests",
          variables.familyId,
          variables.groupId,
        ],
      });
      // Invalidate groups queries as new member may affect group visibility
      queryClient.invalidateQueries({ queryKey: ["groups"] });
    },
    onError: (error) => {
      console.error("Failed to add group member:", error);
    },
  });

  // Helper function for adding member as admin
  const addMemberAsAdmin = (familyId, groupId, targetUserId) => {
    return mutation.mutate({
      familyId,
      groupId,
      targetUserId,
      makeAdmin: true,
    });
  };

  const addMemberAsAdminAsync = (familyId, groupId, targetUserId) => {
    return mutation.mutateAsync({
      familyId,
      groupId,
      targetUserId,
      makeAdmin: true,
    });
  };

  return {
    addMember: mutation.mutate,
    addMemberAsync: mutation.mutateAsync,
    addMemberAsAdmin,
    addMemberAsAdminAsync,
    isAddingMember: mutation.isPending,
    isAddMemberError: mutation.isError,
    addMemberError: mutation.error,
    isAddMemberSuccess: mutation.isSuccess,
    addedMember: mutation.data?.data?.membership || null,
    resetAddMemberState: mutation.reset,
  };
};

export default useAddGroupMember;
