import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useCreateGroup = () => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (groupData) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/group`,
        idToken,
        body: groupData,
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
      console.error("Failed to create group:", error);
    },
  });

  return {
    createGroup: mutation.mutate,
    createGroupAsync: mutation.mutateAsync,
    isCreating: mutation.isPending,
    isCreateError: mutation.isError,
    createError: mutation.error,
    isCreateSuccess: mutation.isSuccess,
    createdGroup: mutation.data?.data?.group || null,
    resetCreateState: mutation.reset,
  };
};

export default useCreateGroup;
