import { useGetAllGroups } from "./useGetAllGroups";
import { useGetMyGroups } from "./useGetMyGroups";
import { useCreateGroup } from "./useCreateGroup";
import { useUpdateGroup } from "./useUpdateGroup";
import { useDeleteGroup } from "./useDeleteGroup";

/**
 * Comprehensive hook for group management with CRUD operations
 * Provides state management, API integration, and error handling for groups
 * This is a composite hook that combines individual group operation hooks
 */
const useGroups = (familyId = null, enabled = true) => {
  // Use individual hooks for each operation
  const {
    groups: allGroups,
    isGroupsFetching: isAllGroupsFetching,
    isGroupsError: isAllGroupsError,
    groupsError: allGroupsError,
    groupsRefetch: refetchAllGroups,
  } = useGetAllGroups(familyId, enabled);

  const {
    myGroups,
    isMyGroupsFetching,
    isMyGroupsError,
    myGroupsError,
    myGroupsRefetch: refetchMyGroups,
  } = useGetMyGroups(enabled);

  const {
    createGroup,
    createGroupAsync,
    isCreating,
    isCreateError,
    createError,
    isCreateSuccess,
    createdGroup,
    resetCreateState,
  } = useCreateGroup();

  const {
    updateGroup,
    updateGroupAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
    updatedGroup,
    resetUpdateState,
  } = useUpdateGroup();

  const {
    deleteGroup,
    deleteGroupAsync,
    isDeleting,
    isDeleteError,
    deleteError,
    isDeleteSuccess,
    resetDeleteState,
  } = useDeleteGroup();

  // Helper function to refetch all group data
  const refetchGroups = () => {
    if (familyId) {
      refetchAllGroups();
    }
    refetchMyGroups();
  };

  // Computed values
  const isLoading = isAllGroupsFetching || isMyGroupsFetching;
  const isMutating = isCreating || isUpdating || isDeleting;

  const hasError =
    isAllGroupsError ||
    isMyGroupsError ||
    isCreateError ||
    isUpdateError ||
    isDeleteError;

  const error =
    allGroupsError ||
    myGroupsError ||
    createError ||
    updateError ||
    deleteError;

  return {
    // Data
    allGroups,
    myGroups,

    // Loading states
    isLoading,
    isMutating,
    isAllGroupsFetching,
    isMyGroupsFetching,

    // Error states
    hasError,
    error,
    isAllGroupsError,
    isMyGroupsError,

    // Specific errors
    allGroupsError,
    myGroupsError,
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
    createdGroup,
    updatedGroup,

    // Actions
    createGroup,
    createGroupAsync,
    updateGroup,
    updateGroupAsync,
    deleteGroup,
    deleteGroupAsync,
    refetchGroups,
    refetchAllGroups,
    refetchMyGroups,

    // Reset functions
    resetCreateState,
    resetUpdateState,
    resetDeleteState,
  };
};

export default useGroups;
