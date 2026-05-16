import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestDelete } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";
import { message } from "antd";

/**
 * Hook for removing members from a family
 * Allows family admins to remove members or members to remove themselves
 */
const useRemoveFamilyMember = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async ({ targetUserId }) => {
      return apiRequestDelete(
        apiEndpoint,
        `/membership/${familyId}/members/${targetUserId}`,
        idToken,
      );
    },
    onSuccess: () => {
      // Invalidate family members query to refresh the list
      queryClient.invalidateQueries(["familyMembers", familyId]);
      message.success("Member successfully removed from family");
    },
    onError: (error) => {
      console.error("Failed to remove family member:", error);
      message.error("Failed to remove member from family");
    },
  });

  return {
    removeMember: mutation.mutate,
    removeMemberAsync: mutation.mutateAsync,
    isRemoving: mutation.isPending,
    isRemoveError: mutation.isError,
    removeError: mutation.error,
    isRemoveSuccess: mutation.isSuccess,
    removedMember: mutation.data?.data?.membership || null,
    resetRemoveState: mutation.reset,
  };
};

export default useRemoveFamilyMember;
