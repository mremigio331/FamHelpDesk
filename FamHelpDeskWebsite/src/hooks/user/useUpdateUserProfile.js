import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useUpdateUserProfile = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (updateData) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/user/profile`,
        accessToken,
        body: updateData,
      }),
    onSuccess: () => {
      // Invalidate and refetch user profile
      queryClient.invalidateQueries(["userProfile"]);
    },
  });

  return {
    updateProfile: mutation.mutate,
    updateProfileAsync: mutation.mutateAsync,
    isUpdating: mutation.isLoading,
    isUpdateError: mutation.isError,
    updateError: mutation.error,
    isUpdateSuccess: mutation.isSuccess,
  };
};

export default useUpdateUserProfile;
