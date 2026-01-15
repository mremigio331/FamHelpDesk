import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useReviewMembershipRequest = (familyId) => {
  const queryClient = useQueryClient();
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const mutation = useMutation({
    mutationFn: ({ targetUserId, approved }) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/membership/${familyId}/review`,
        idToken,
        body: { target_user_id: targetUserId, approve: approved },
      }),
    onSuccess: () => {
      // Invalidate and refetch membership data
      queryClient.invalidateQueries({
        queryKey: ["familyMembershipRequests", familyId],
      });
      queryClient.invalidateQueries({ queryKey: ["familyMembers", familyId] });
    },
  });

  return {
    reviewMembership: mutation.mutate,
    isReviewing: mutation.isLoading,
    isReviewError: mutation.isError,
    reviewError: mutation.error,
  };
};

export default useReviewMembershipRequest;
