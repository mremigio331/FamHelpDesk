import { message } from "antd";

/**
 * Handles approving a membership request
 */
export const handleApproveMembership = (
  reviewMembership,
  targetUserId,
  displayName,
) => {
  reviewMembership(
    { targetUserId, approved: true },
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
 * Handles rejecting a membership request
 */
export const handleRejectMembership = (
  reviewMembership,
  targetUserId,
  displayName,
) => {
  reviewMembership(
    { targetUserId, approved: false },
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
 * Formats a timestamp to a localized date string
 */
export const formatMembershipDate = (timestamp) => {
  return new Date(timestamp * 1000).toLocaleDateString();
};
