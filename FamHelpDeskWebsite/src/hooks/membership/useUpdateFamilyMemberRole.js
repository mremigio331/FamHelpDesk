import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";
import { message } from "antd";

/**
 * Hook for updating family member roles (admin/member)
 * Allows family admins to promote members to admin or demote admins to regular members
 */
const useUpdateFamilyMemberRole = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async ({ targetUserId, isAdmin }) => {
      return apiRequestPut(
        apiEndpoint,
        `/membership/${familyId}/members/role`,
        idToken,
        {
          target_user_id: targetUserId,
          is_admin: isAdmin,
        },
      );
    },
    onSuccess: (data, variables) => {
      // Invalidate family members query to refresh the list
      queryClient.invalidateQueries(["familyMembers", familyId]);

      const action = variables.isAdmin ? "promoted to admin" : "demoted to member";
      message.success(`Member successfully ${action}`);
    },
    onError: (error) => {
      console.error("Failed to update member role:", error);
      message.error("Failed to update member role");
    },
  });

  // Helper functions for common operations
  const promoteToAdmin = (targetUserId) => {
    return mutation.mutate({ targetUserId, isAdmin: true });
  };

  const demoteFromAdmin = (targetUserId) => {
    return mutation.mutate({ targetUserId, isAdmin: false });
  };

  const promoteToAdminAsync = async (targetUserId) => {
    return mutation.mutateAsync({ targetUserId, isAdmin: true });
  };

  const demoteFromAdminAsync = async (targetUserId) => {
    return mutation.mutateAsync({ targetUserId, isAdmin: false });
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

export default useUpdateFamilyMemberRole;
