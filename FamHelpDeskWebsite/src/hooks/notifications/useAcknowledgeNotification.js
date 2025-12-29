import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { apiRequestPut } from "../../api/apiRequest";
import { useApi } from "../../provider/ApiProvider";

const useAcknowledgeNotification = () => {
  const { accessToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (notificationId) =>
      apiRequestPut({
        apiEndpoint: `${apiEndpoint}/notifications/${notificationId}/acknowledge`,
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
    acknowledgeNotification: mutation.mutate,
    acknowledgeNotificationAsync: mutation.mutateAsync,
    isAcknowledging: mutation.isLoading,
    isAcknowledgeError: mutation.isError,
    acknowledgeError: mutation.error,
    isAcknowledgeSuccess: mutation.isSuccess,
  };
};

export default useAcknowledgeNotification;
