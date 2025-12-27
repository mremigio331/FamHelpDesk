import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useCreateFamily = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (familyData) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/family`,
        accessToken,
        body: familyData,
      }),
    onSuccess: () => {
      // Invalidate families queries to refetch the updated list
      queryClient.invalidateQueries(["families"]);
    },
  });

  return {
    createFamily: mutation.mutate,
    createFamilyAsync: mutation.mutateAsync,
    isCreating: mutation.isLoading,
    isCreateError: mutation.isError,
    createError: mutation.error,
    isCreateSuccess: mutation.isSuccess,
    createdFamily: mutation.data?.data?.family || null,
  };
};

export default useCreateFamily;
