import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useCreateGroup = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (groupData) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/group`,
        accessToken,
        body: groupData,
      }),
    onSuccess: () => {
      // Invalidate groups queries to refetch the updated list
      queryClient.invalidateQueries(["groups"]);
    },
  });

  return {
    createGroup: mutation.mutate,
    createGroupAsync: mutation.mutateAsync,
    isCreating: mutation.isLoading,
    isCreateError: mutation.isError,
    createError: mutation.error,
    isCreateSuccess: mutation.isSuccess,
    createdGroup: mutation.data?.data?.group || null,
  };
};

export default useCreateGroup;
