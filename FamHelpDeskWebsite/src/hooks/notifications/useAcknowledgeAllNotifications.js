import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useAcknowledgeAllNotifications = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: () =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/notifications/acknowledge-all`,
        accessToken,
        body: {},
      }),
    onSuccess: () => {
      // Invalidate and refetch notifications and unread count
      queryClient.invalidateQueries(["notifications"]);
      queryClient.invalidateQueries(["unreadNotificationsCount"]);
    },
  });

  return {
    acknowledgeAllNotifications: mutation.mutate,
    acknowledgeAllNotificationsAsync: mutation.mutateAsync,
    isAcknowledgingAll: mutation.isLoading,
    isAcknowledgeAllError: mutation.isError,
    acknowledgeAllError: mutation.error,
    isAcknowledgeAllSuccess: mutation.isSuccess,
  };
};

export default useAcknowledgeAllNotifications;
