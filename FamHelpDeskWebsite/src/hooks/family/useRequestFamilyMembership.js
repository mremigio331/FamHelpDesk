import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useRequestFamilyMembership = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId }) => {
      return apiRequestPost({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/request`,
        accessToken,
        body: {},
      });
    },
    onSuccess: () => {
      // Invalidate relevant queries
      queryClient.invalidateQueries(["families", "my"]);
    },
  });

  return {
    requestFamilyMembership: mutation.mutate,
    isRequesting: mutation.isLoading,
    isRequestSuccess: mutation.isSuccess,
    isRequestError: mutation.isError,
    requestError: mutation.error,
    requestData: mutation.data,
  };
};

export default useRequestFamilyMembership;
