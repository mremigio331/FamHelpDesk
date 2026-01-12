import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestDelete } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useDeleteGroup = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId }) =>
      apiRequestDelete({
        apiEndpoint: `${apiEndpoint}/group/${familyId}/${groupId}`,
        accessToken,
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: ["groups"] });
      queryClient.invalidateQueries({
        queryKey: ["groups", "all", variables.familyId],
      });
      queryClient.invalidateQueries({ queryKey: ["groups", "mine"] });
    },
    onError: (error) => {
      console.error("Failed to delete group:", error);
    },
  });

  return {
    deleteGroup: mutation.mutate,
    deleteGroupAsync: mutation.mutateAsync,
    isDeleting: mutation.isPending,
    isDeleteError: mutation.isError,
    deleteError: mutation.error,
    isDeleteSuccess: mutation.isSuccess,
    resetDeleteState: mutation.reset,
  };
};

export default useDeleteGroup;
