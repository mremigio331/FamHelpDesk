import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useContext } from "react";
import { UserAuthenticationContext } from "../provider/UserAuthenticationProvider";
import { useApi } from "../provider/ApiProvider";
import {
  getBalance,
  createRequest,
  listRequests,
  getRequest,
  claimRequest,
  completeRequest,
  confirmRequest,
  cancelRequest,
  claimItems,
  completeItems,
  confirmItems,
  cancelItems,
  getUploadUrl,
  getPhotoUrl,
  getLeaderboard,
  getTransactions,
  getReviewHistory,
} from "../api/famgrab";

// Query hooks

export const useBalance = (familyId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "balance", familyId],
    queryFn: () => getBalance(apiEndpoint, familyId, idToken),
    enabled: enabled && !!idToken && !!familyId,
    staleTime: 1000 * 60 * 2,
  });

  return {
    balance: data?.data || null,
    isBalanceFetching: isFetching,
    isBalanceError: isError,
    balanceError: error,
    refetchBalance: refetch,
  };
};

export const useRequests = (familyId, params = {}, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "requests", familyId, params],
    queryFn: () => listRequests(apiEndpoint, familyId, idToken, params),
    enabled: enabled && !!idToken && !!familyId,
    staleTime: 1000 * 30,
  });

  return {
    requests: data?.data?.requests || [],
    lastKey: data?.data?.last_key || null,
    isRequestsFetching: isFetching,
    isRequestsError: isError,
    requestsError: error,
    refetchRequests: refetch,
  };
};

export const useRequest = (familyId, requestId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "request", familyId, requestId],
    queryFn: () => getRequest(apiEndpoint, familyId, requestId, idToken),
    enabled: enabled && !!idToken && !!familyId && !!requestId,
    staleTime: 1000 * 30,
  });

  return {
    request: data?.data || null,
    isRequestFetching: isFetching,
    isRequestError: isError,
    requestError: error,
    refetchRequest: refetch,
  };
};

export const useLeaderboard = (familyId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "leaderboard", familyId],
    queryFn: () => getLeaderboard(apiEndpoint, familyId, idToken),
    enabled: enabled && !!idToken && !!familyId,
    staleTime: 1000 * 60 * 5,
  });

  return {
    leaderboard: data?.data?.leaderboard || [],
    isLeaderboardFetching: isFetching,
    isLeaderboardError: isError,
    leaderboardError: error,
    refetchLeaderboard: refetch,
  };
};

export const useTransactions = (familyId, params = {}, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "transactions", familyId, params],
    queryFn: () => getTransactions(apiEndpoint, familyId, idToken, params),
    enabled: enabled && !!idToken && !!familyId,
    staleTime: 1000 * 60 * 2,
  });

  return {
    transactions: data?.data?.transactions || [],
    lastKey: data?.data?.last_key || null,
    isTransactionsFetching: isFetching,
    isTransactionsError: isError,
    transactionsError: error,
    refetchTransactions: refetch,
  };
};

export const useReviewHistory = (familyId, userId, params = {}, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "reviews", familyId, userId, params],
    queryFn: () => getReviewHistory(apiEndpoint, familyId, userId, idToken, params),
    enabled: enabled && !!idToken && !!familyId && !!userId,
    staleTime: 1000 * 60 * 2,
  });

  return {
    reviews: data?.data?.reviews || [],
    averageRating: data?.data?.average_rating || 0,
    totalReviewCount: data?.data?.total_review_count || 0,
    lastKey: data?.data?.last_key || null,
    isReviewsFetching: isFetching,
    isReviewsError: isError,
    reviewsError: error,
    refetchReviews: refetch,
  };
};

// Mutation hooks

export const useCreateRequest = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (body) =>
      createRequest(apiEndpoint, familyId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "balance", familyId]);
    },
  });

  return {
    createRequest: mutation.mutate,
    createRequestAsync: mutation.mutateAsync,
    isCreating: mutation.isPending,
    isCreateError: mutation.isError,
    createError: mutation.error,
    isCreateSuccess: mutation.isSuccess,
  };
};

export const useClaimRequest = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (requestId) =>
      claimRequest(apiEndpoint, familyId, requestId, idToken),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
    },
  });

  return {
    claimRequest: mutation.mutate,
    claimRequestAsync: mutation.mutateAsync,
    isClaiming: mutation.isPending,
    isClaimError: mutation.isError,
    claimError: mutation.error,
  };
};

export const useCompleteRequest = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      completeRequest(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
    },
  });

  return {
    completeRequest: mutation.mutate,
    completeRequestAsync: mutation.mutateAsync,
    isCompleting: mutation.isPending,
    isCompleteError: mutation.isError,
    completeError: mutation.error,
  };
};

export const useConfirmRequest = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      confirmRequest(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
      queryClient.invalidateQueries(["famgrab", "balance", familyId]);
      queryClient.invalidateQueries(["famgrab", "leaderboard", familyId]);
    },
  });

  return {
    confirmRequest: mutation.mutate,
    confirmRequestAsync: mutation.mutateAsync,
    isConfirming: mutation.isPending,
    isConfirmError: mutation.isError,
    confirmError: mutation.error,
  };
};

export const useCancelRequest = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (requestId) =>
      cancelRequest(apiEndpoint, familyId, requestId, idToken),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
    },
  });

  return {
    cancelRequest: mutation.mutate,
    cancelRequestAsync: mutation.mutateAsync,
    isCancelling: mutation.isPending,
    isCancelError: mutation.isError,
    cancelError: mutation.error,
  };
};

export const useGetUploadUrl = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      getUploadUrl(apiEndpoint, familyId, requestId, idToken, body),
  });

  return {
    getUploadUrl: mutation.mutate,
    getUploadUrlAsync: mutation.mutateAsync,
    isGettingUploadUrl: mutation.isPending,
    uploadUrlError: mutation.error,
  };
};

export const usePhotoUrl = (familyId, requestId, enabled = true) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();

  const { data, isFetching, isError, error, refetch } = useQuery({
    queryKey: ["famgrab", "photo", familyId, requestId],
    queryFn: () => getPhotoUrl(apiEndpoint, familyId, requestId, idToken),
    enabled: enabled && !!idToken && !!familyId && !!requestId,
    staleTime: 1000 * 60 * 10,
  });

  return {
    photoUrl: data?.data?.url || null,
    isPhotoFetching: isFetching,
    isPhotoError: isError,
    photoError: error,
    refetchPhoto: refetch,
  };
};

// Item-level mutation hooks

export const useClaimItems = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      claimItems(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
      queryClient.invalidateQueries(["famgrab", "balance", familyId]);
    },
  });

  return {
    claimItems: mutation.mutate,
    claimItemsAsync: mutation.mutateAsync,
    isClaimingItems: mutation.isPending,
    isClaimItemsError: mutation.isError,
    claimItemsError: mutation.error,
  };
};

export const useCompleteItems = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      completeItems(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
    },
  });

  return {
    completeItems: mutation.mutate,
    completeItemsAsync: mutation.mutateAsync,
    isCompletingItems: mutation.isPending,
    isCompleteItemsError: mutation.isError,
    completeItemsError: mutation.error,
  };
};

export const useConfirmItems = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      confirmItems(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
      queryClient.invalidateQueries(["famgrab", "balance", familyId]);
      queryClient.invalidateQueries(["famgrab", "leaderboard", familyId]);
    },
  });

  return {
    confirmItems: mutation.mutate,
    confirmItemsAsync: mutation.mutateAsync,
    isConfirmingItems: mutation.isPending,
    isConfirmItemsError: mutation.isError,
    confirmItemsError: mutation.error,
  };
};

export const useCancelItems = (familyId) => {
  const { idToken } = useContext(UserAuthenticationContext);
  const { apiEndpoint } = useApi();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: ({ requestId, body }) =>
      cancelItems(apiEndpoint, familyId, requestId, idToken, body),
    onSuccess: () => {
      queryClient.invalidateQueries(["famgrab", "requests", familyId]);
      queryClient.invalidateQueries(["famgrab", "request", familyId]);
    },
  });

  return {
    cancelItems: mutation.mutate,
    cancelItemsAsync: mutation.mutateAsync,
    isCancellingItems: mutation.isPending,
    isCancelItemsError: mutation.isError,
    cancelItemsError: mutation.error,
  };
};
