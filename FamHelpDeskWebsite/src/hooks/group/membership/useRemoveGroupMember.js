import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestDelete } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for removing members from a group
 * Allows group admins to remove members or members to remove themselves
 */
const useRemoveGroupMember = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId, targetUserId }) =>
      apiRequestDelete({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/${groupId}/members/${targetUserId}`,
        accessToken,
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({
        queryKey: ["groupMembers", variables.familyId, variables.groupId],
      });
      // Invalidate groups queries as member removal may affect group access
      queryClient.invalidateQueries({ queryKey: ["groups"] });
    },
    onError: (error) => {
      console.error("Failed to remove group member:", error);
    },
  });

  return {
    removeMember: mutation.mutate,
    removeMemberAsync: mutation.mutateAsync,
    isRemovingMember: mutation.isPending,
    isRemoveMemberError: mutation.isError,
    removeMemberError: mutation.error,
    isRemoveMemberSuccess: mutation.isSuccess,
    removedMember: mutation.data?.data?.membership || null,
    resetRemoveMemberState: mutation.reset,
  };
};

export default useRemoveGroupMember;
