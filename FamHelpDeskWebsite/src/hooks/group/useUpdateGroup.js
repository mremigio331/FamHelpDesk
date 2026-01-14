import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

/**
 * Hook for updating an existing group
 * Allows updating group name and description
 */
const useUpdateGroup = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ family_id, group_id, group_name, group_description }) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/group/edit`,
        accessToken,
        body: {
          family_id,
          group_id,
          group_name,
          group_description,
        },
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: ["groups"] });
      queryClient.invalidateQueries({
        queryKey: ["groups", "all", variables.family_id],
      });
      queryClient.invalidateQueries({ queryKey: ["groups", "mine"] });
    },
    onError: (error) => {
      console.error("Failed to update group:", error);
    },
  });

  return {
    updateGroup: mutation.mutate,
    updateGroupAsync: mutation.mutateAsync,
    isUpdating: mutation.isPending,
    isUpdateError: mutation.isError,
    updateError: mutation.error,
    isUpdateSuccess: mutation.isSuccess,
    updatedGroup: mutation.data?.data?.group || null,
    resetUpdateState: mutation.reset,
  };
};

export { useUpdateGroup };
export default useUpdateGroup;
