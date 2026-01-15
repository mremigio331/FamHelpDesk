import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestDelete } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

/**
 * Hook to delete a queue
 * @returns {Object} Mutation result with delete queue function and state
 */
const useDeleteQueue = () => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ familyId, groupId, queueId }) =>
      apiRequestDelete({
        apiEndpoint: `${apiEndpoint}/queue/${familyId}/${groupId}/${queueId}`,
        accessToken: idToken,
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: ["queues"] });
      queryClient.invalidateQueries({
        queryKey: ["queues", variables.familyId, variables.groupId],
      });
      queryClient.invalidateQueries({
        queryKey: ["queue", variables.queueId],
      });
    },
    onError: (error) => {
      console.error("Failed to delete queue:", error);
    },
  });

  return {
    deleteQueue: mutation.mutate,
    deleteQueueAsync: mutation.mutateAsync,
    isDeleting: mutation.isPending,
    isDeleteError: mutation.isError,
    deleteError: mutation.error,
    isDeleteSuccess: mutation.isSuccess,
    resetDeleteState: mutation.reset,
  };
};

export default useDeleteQueue;
