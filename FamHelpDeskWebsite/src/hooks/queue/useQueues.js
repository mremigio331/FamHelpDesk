import useGetQueues from "./useGetQueues";
import useCreateQueue from "./useCreateQueue";
import useUpdateQueue from "./useUpdateQueue";
import useDeleteQueue from "./useDeleteQueue";

/**
 * Comprehensive hook for queue management with CRUD operations
 * Provides state management, API integration, and error handling for queues
 * This is a composite hook that combines individual queue operation hooks
 *
 * @param {string} familyId - The family ID (optional)
 * @param {string} groupId - The group ID (optional)
 * @param {boolean} enabled - Whether queries should be enabled (default: true)
 * @returns {Object} Combined queue management state and operations
 */
const useQueues = (familyId = null, groupId = null, enabled = true) => {
  // Use individual hooks for each operation
  const {
    queues,
    isQueuesFetching,
    isQueuesError,
    queuesError,
    queuesRefetch,
  } = useGetQueues(familyId, groupId, enabled);

  const {
    createQueue,
    createQueueAsync,
    isCreating,
    isCreateError,
    createError,
    isCreateSuccess,
    createdQueue,
    resetCreateState,
  } = useCreateQueue();

  const {
    updateQueue,
    updateQueueAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
    updatedQueue,
    resetUpdateState,
  } = useUpdateQueue();

  const {
    deleteQueue,
    deleteQueueAsync,
    isDeleting,
    isDeleteError,
    deleteError,
    isDeleteSuccess,
    resetDeleteState,
  } = useDeleteQueue();

  // Helper function to refetch queue data
  const refetchQueues = () => {
    if (familyId && groupId) {
      queuesRefetch();
    }
  };

  // Computed values
  const isLoading = isQueuesFetching;
  const isMutating = isCreating || isUpdating || isDeleting;

  const hasError =
    isQueuesError || isCreateError || isUpdateError || isDeleteError;

  const error = queuesError || createError || updateError || deleteError;

  return {
    // Data
    queues,

    // Loading states
    isLoading,
    isMutating,
    isQueuesFetching,

    // Error states
    hasError,
    error,
    isQueuesError,

    // Specific errors
    queuesError,
    createError,
    updateError,
    deleteError,

    // Success states
    isCreateSuccess,
    isUpdateSuccess,
    isDeleteSuccess,

    // Mutation loading states
    isCreating,
    isUpdating,
    isDeleting,

    // Created/updated data
    createdQueue,
    updatedQueue,

    // Actions
    createQueue,
    createQueueAsync,
    updateQueue,
    updateQueueAsync,
    deleteQueue,
    deleteQueueAsync,
    refetchQueues,

    // Reset functions
    resetCreateState,
    resetUpdateState,
    resetDeleteState,
  };
};

export default useQueues;
