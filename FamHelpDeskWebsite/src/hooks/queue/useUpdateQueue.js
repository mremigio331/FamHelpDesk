import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

/**
 * Hook to update an existing queue
 * @returns {Object} Mutation result with update queue function and state
 */
const useUpdateQueue = () => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (queueData) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/queue/update`,
        accessToken: idToken,
        body: queueData,
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: ["queues"] });
      queryClient.invalidateQueries({
        queryKey: ["queues", variables.family_id, variables.group_id],
      });
      queryClient.invalidateQueries({
        queryKey: ["queue", variables.queue_id],
      });
    },
    onError: (error) => {
      console.error("Failed to update queue:", error);
    },
  });

  return {
    updateQueue: mutation.mutate,
    updateQueueAsync: mutation.mutateAsync,
    isUpdating: mutation.isPending,
    isUpdateError: mutation.isError,
    updateError: mutation.error,
    isUpdateSuccess: mutation.isSuccess,
    updatedQueue: mutation.data?.data?.queue || null,
    resetUpdateState: mutation.reset,
  };
};

export default useUpdateQueue;
