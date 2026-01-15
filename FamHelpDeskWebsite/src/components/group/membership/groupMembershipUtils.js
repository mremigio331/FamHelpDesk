import { message } from "antd";

/**
 * Handles approving a group membership request
 */
export const handleApproveGroupMembership = (
  reviewMembership,
  familyId,
  groupId,
  targetUserId,
  displayName,
) => {
  reviewMembership(
    { familyId, groupId, targetUserId, approve: true },
    {
      onSuccess: () => {
        message.success(`${displayName} has been approved`);
      },
      onError: (error) => {
        message.error(error?.message || "Failed to approve request");
      },
    },
  );
};

/**
 * Handles rejecting a group membership request
 */
export const handleRejectGroupMembership = (
  reviewMembership,
  familyId,
  groupId,
  targetUserId,
  displayName,
) => {
  reviewMembership(
    { familyId, groupId, targetUserId, approve: false },
    {
      onSuccess: () => {
        message.info(`${displayName}'s request has been rejected`);
      },
      onError: (error) => {
        message.error(error?.message || "Failed to reject request");
      },
    },
  );
};

/**
 * Handles removing a group member
 */
export const handleRemoveGroupMember = (
  removeMember,
  familyId,
  groupId,
  targetUserId,
  displayName,
) => {
  removeMember(
    { familyId, groupId, targetUserId },
    {
      onSuccess: () => {
        message.success(`${displayName} has been removed from the group`);
      },
      onError: (error) => {
        message.error(error?.message || "Failed to remove member");
      },
    },
  );
};

/**
 * Handles toggling admin role for a group member
 */
export const handleToggleGroupMemberRole = (
  updateMemberRole,
  familyId,
  groupId,
  targetUserId,
  currentIsAdmin,
  displayName,
) => {
  const newRole = !currentIsAdmin;
  updateMemberRole(
    { familyId, groupId, targetUserId, isAdmin: newRole },
    {
      onSuccess: () => {
        message.success(
          `${displayName} is now ${newRole ? "an admin" : "a regular member"}`,
        );
      },
      onError: (error) => {
        message.error(error?.message || "Failed to update member role");
      },
    },
  );
};

/**
 * Formats a timestamp to a localized date string
 */
export const formatMembershipDate = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleDateString();
};
