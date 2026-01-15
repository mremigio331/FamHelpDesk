import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPost } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

/**
 * Hook to create a new queue
 * @returns {Object} Mutation result with create queue function and state
 */
const useCreateQueue = () => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (queueData) =>
      apiRequestPost({
        apiEndpoint: `${apiEndpoint}/queue/create`,
        accessToken: idToken,
        body: queueData,
      }),
    onSuccess: (data, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: ["queues"] });
      queryClient.invalidateQueries({
        queryKey: ["queues", variables.family_id, variables.group_id],
      });
    },
    onError: (error) => {
      console.error("Failed to create queue:", error);
    },
  });

  return {
    createQueue: mutation.mutate,
    createQueueAsync: mutation.mutateAsync,
    isCreating: mutation.isPending,
    isCreateError: mutation.isError,
    createError: mutation.error,
    isCreateSuccess: mutation.isSuccess,
    createdQueue: mutation.data?.data?.queue || null,
    resetCreateState: mutation.reset,
  };
};

export default useCreateQueue;
