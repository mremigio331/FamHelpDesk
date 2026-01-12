import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../../api/apiRequest";
import { useApi } from "../../../provider/ApiProvider";

/**
 * Hook for updating group member roles (admin only)
 * Allows group admins to promote members to admin or demote admins to regular members
 */
const useUpdateGroupMemberRole = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId, targetUserId, isAdmin }) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/${groupId}/members/role`,
        accessToken,
        body: {
          target_user_id: targetUserId,
          is_admin: isAdmin,
        },
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({
        queryKey: ["groupMembers", variables.familyId, variables.groupId],
      });
      // Invalidate groups queries as role changes may affect permissions
      queryClient.invalidateQueries({ queryKey: ["groups"] });
    },
    onError: (error) => {
      console.error("Failed to update member role:", error);
    },
  });

  // Helper functions for easier usage
  const promoteToAdmin = (familyId, groupId, targetUserId) => {
    return mutation.mutate({ familyId, groupId, targetUserId, isAdmin: true });
  };

  const demoteFromAdmin = (familyId, groupId, targetUserId) => {
    return mutation.mutate({ familyId, groupId, targetUserId, isAdmin: false });
  };

  const promoteToAdminAsync = (familyId, groupId, targetUserId) => {
    return mutation.mutateAsync({
      familyId,
      groupId,
      targetUserId,
      isAdmin: true,
    });
  };

  const demoteFromAdminAsync = (familyId, groupId, targetUserId) => {
    return mutation.mutateAsync({
      familyId,
      groupId,
      targetUserId,
      isAdmin: false,
    });
  };

  return {
    updateMemberRole: mutation.mutate,
    updateMemberRoleAsync: mutation.mutateAsync,
    promoteToAdmin,
    demoteFromAdmin,
    promoteToAdminAsync,
    demoteFromAdminAsync,
    isUpdatingRole: mutation.isPending,
    isUpdateRoleError: mutation.isError,
    updateRoleError: mutation.error,
    isUpdateRoleSuccess: mutation.isSuccess,
    updatedMember: mutation.data?.data?.membership || null,
    resetUpdateRoleState: mutation.reset,
  };
};

export default useUpdateGroupMemberRole;
